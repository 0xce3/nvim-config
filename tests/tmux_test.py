"""Exercise the launcher and task bridge against an isolated tmux server."""

import hashlib
import importlib.machinery
import importlib.util
import json
import os
import pty
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

HELPER = Path(__file__).resolve().parents[1] / "bin/nvim-tmux"
sys.dont_write_bytecode = True
loader = importlib.machinery.SourceFileLoader("nvim_tmux", str(HELPER))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


class Attached(Exception):
    pass


class TmuxTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="nvim-tmux-")
        self.root = Path(self.temporary.name)
        self.environment = patch.dict(
            os.environ,
            {
                "HOME": str(self.root),
                "XDG_STATE_HOME": str(self.root / "state"),
                "TMUX_TMPDIR": str(self.root),
                "TMUX": "",
            },
        )
        self.environment.start()
        wrapper = self.root / ".config/nvim/bin/nvim"
        wrapper.parent.mkdir(parents=True)
        wrapper.write_text("#!/bin/sh\nexec sleep 60\n")
        wrapper.chmod(0o700)
        with (
            patch.object(module.os, "execvp", side_effect=Attached),
            self.assertRaises(Attached),
        ):
            module.launch(str(self.root))
        self.session = module.tmux(
            "list-sessions", "-F", "#{session_name}"
        ).stdout.strip()
        self.directory = self.root / "state/nvim/tmux" / self.session
        self.wait_for(self.directory / "heartbeat")

    def tearDown(self):
        module.tmux("kill-server", check=False)
        self.environment.stop()
        self.temporary.cleanup()

    def wait_for(self, path):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if path.exists():
                return path.read_text()
            time.sleep(0.05)
        self.fail(f"Timed out waiting for {path}")

    def request(self, name, data):
        temporary = self.directory / (name + ".tmp")
        temporary.write_text(json.dumps(data))
        temporary.rename(self.directory / (name + ".request"))
        return self.wait_for(self.directory / (name + ".response"))

    def test_layout_and_reattach(self):
        self.assertEqual(
            module.tmux(
                "list-windows",
                "-t",
                self.session,
                "-F",
                "#{window_index}:#{window_name}",
            ).stdout.splitlines(),
            ["0:nvim", "1:bash"],
        )
        self.assertEqual(
            module.tmux(
                "show-option", "-v", "-t", self.session, "status-position"
            ).stdout.strip(),
            "top",
        )
        with (
            patch.object(module.os, "execvp", side_effect=Attached),
            self.assertRaises(Attached),
        ):
            module.launch(str(self.root))
        self.assertEqual(
            len(
                module.tmux(
                    "list-sessions", "-F", "#{session_name}"
                ).stdout.splitlines()
            ),
            1,
        )

    def test_tasks_success_failure_and_stop(self):
        output = self.root / "task output.txt"
        self.assertEqual(
            self.request(
                "success",
                {
                    "action": "task",
                    "command": f"printf 'hello' > '{output}'",
                    "cwd": str(self.root),
                },
            ),
            "ok",
        )
        self.assertEqual(self.wait_for(self.directory / "success.result").strip(), "0")
        self.assertEqual(output.read_text(), "hello")
        self.assertEqual(
            module.tmux(
                "display-message",
                "-p",
                "-t",
                self.session,
                "#{window_index}:#{window_name}",
            ).stdout.strip(),
            "3:tasks",
        )
        self.assertEqual(
            self.request(
                "failure",
                {"action": "task", "command": "exit 7", "cwd": str(self.root)},
            ),
            "ok",
        )
        self.assertEqual(self.wait_for(self.directory / "failure.result").strip(), "7")
        self.assertEqual(
            self.request(
                "slow", {"action": "task", "command": "sleep 60", "cwd": str(self.root)}
            ),
            "ok",
        )
        self.assertIn(
            "already running",
            self.request("busy", {"action": "task", "command": "true"}),
        )
        time.sleep(0.5)
        self.assertEqual(self.request("stop", {"action": "stop"}), "ok")
        self.assertNotEqual(self.wait_for(self.directory / "slow.result").strip(), "0")
        self.assertEqual(
            self.request("select", {"action": "select", "window": 0}), "ok"
        )

    def test_neovim_client_uses_external_task_window(self):
        config = HELPER.parents[1]
        lua = (
            f"package.path = {json.dumps(str(config / 'lua/?.lua'))} .. ';' .. package.path; "
            "local term = require('config.terminal'); "
            "term.run('exit 7', 'test'); "
            "assert(vim.wait(10000, function() return not term.is_task_running() end)); "
            "assert(term.task_status() == 'failed'); "
            "for _, b in ipairs(vim.api.nvim_list_bufs()) do "
            "assert(vim.bo[b].buftype ~= 'terminal') end"
        )
        lua = (
            "local ok, err = pcall(function() "
            + lua
            + " end); if not ok then print(err); vim.cmd('cquit') end"
        )
        environment = dict(os.environ, NVIM_TMUX_BRIDGE_DIR=str(self.directory))
        subprocess.run(
            [
                "/usr/bin/nvim",
                "--headless",
                "-u",
                "NONE",
                "-c",
                "lua " + lua,
                "-c",
                "qa!",
            ],
            check=True,
            env=environment,
            timeout=15,
        )
        self.assertEqual(
            module.tmux(
                "display-message",
                "-p",
                "-t",
                self.session,
                "#{window_index}:#{window_name}",
            ).stdout.strip(),
            "3:tasks",
        )

    def test_cancelling_runtime_selection_does_not_start_editor(self):
        project = self.root / "project"
        (project / ".devcontainer").mkdir(parents=True)
        (project / ".devcontainer/devcontainer.json").write_text("{}")
        executables = self.root / "executables"
        executables.mkdir()
        fzf = executables / "fzf"
        fzf.write_text("#!/bin/sh\nexit 130\n")
        fzf.chmod(0o700)
        environment = dict(
            os.environ,
            PATH=str(executables) + ":" + os.environ["PATH"],
            NVIM_REAL_BIN="/usr/bin/nvim",
        )
        for name in (
            "NVIM_DEV_DEFAULT",
            "NVIM_TMUX_LAUNCHED",
            "NVIM",
            "NVIM_WRAPPER_BYPASS",
        ):
            environment.pop(name, None)
        master, slave = pty.openpty()
        try:
            result = subprocess.run(
                ["bash", str(HELPER.parent / "nvim"), str(project)],
                check=False,
                stdin=slave,
                stdout=slave,
                stderr=slave,
                env=environment,
                timeout=10,
            )
            self.assertEqual(result.returncode, 130)
            self.assertEqual(
                len(
                    module.tmux(
                        "list-sessions", "-F", "#{session_name}"
                    ).stdout.splitlines()
                ),
                1,
            )
        finally:
            os.close(master)
            os.close(slave)

    @unittest.skipUnless(os.environ.get("NVIM_TEST_CONTAINER"), "No container selected")
    def test_container_bridge(self):
        host_root = Path(os.environ["NVIM_TEST_HOST_ROOT"])
        remote_root = Path(os.environ["NVIM_TEST_REMOTE_ROOT"])
        with tempfile.TemporaryDirectory(
            prefix="tmux-test-", dir=host_root / ".git"
        ) as temporary:
            directory = Path(temporary)
            remote_directory = remote_root / ".git" / directory.name
            (directory / "helper.py").write_text(HELPER.read_text())
            session = (
                "nvim-"
                + hashlib.sha256(str(remote_directory).encode()).hexdigest()[:12]
            )
            docker = [
                "docker",
                "exec",
                "-u",
                os.environ.get("NVIM_TEST_CONTAINER_USER", "root"),
                os.environ["NVIM_TEST_CONTAINER"],
            ]
            code = (
                "import importlib.util, os; "
                f"s = importlib.util.spec_from_file_location('helper', {str(remote_directory / 'helper.py')!r}); "
                "m = importlib.util.module_from_spec(s); s.loader.exec_module(m); "
                "os.execvp = lambda *args: None; "
                f"m.launch({str(remote_directory)!r})"
            )
            subprocess.run(
                docker
                + [
                    "env",
                    "NVIM_TMUX_EDITOR_COMMAND=sleep 60",
                    f"NVIM_TMUX_BRIDGE_DIR={remote_directory}",
                    "python3",
                    "-c",
                    code,
                ],
                check=True,
            )
            try:
                self.wait_for(directory / "heartbeat")
                temporary_request = directory / "remote.tmp"
                temporary_request.write_text(
                    json.dumps(
                        {
                            "action": "task",
                            "command": "printf '%s' \"$PWD\" > "
                            + str(remote_directory / "cwd"),
                            "cwd": str(remote_root),
                        }
                    )
                )
                temporary_request.rename(directory / "remote.request")
                self.assertEqual(self.wait_for(directory / "remote.response"), "ok")
                self.assertEqual(
                    self.wait_for(directory / "remote.result").strip(), "0"
                )
                self.assertEqual((directory / "cwd").read_text(), str(remote_root))
            finally:
                subprocess.run(
                    docker + ["tmux", "kill-session", "-t", "=" + session], check=True
                )


if __name__ == "__main__":
    unittest.main()
