"""Exercise the launcher and task bridge against an isolated tmux server."""

import hashlib
import importlib.machinery
import importlib.util
import json
import os
import pty
import signal
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
            ["1:nvim", "2:bash"],
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
            "1:nvim",
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
            self.request("select", {"action": "select", "window": 1}), "ok"
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
            "1:nvim",
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

    def test_ctrl_digit_sequences_select_windows_without_prefix(self):
        for index in range(3, 10):
            module.tmux("new-window", "-d", "-t", f"{self.session}:{index}", "sleep 60")
        master, slave = pty.openpty()
        process = subprocess.Popen(
            ["tmux", "attach-session", "-t", self.session],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            env=dict(os.environ, TERM="xterm-256color"),
        )
        try:
            deadline = time.monotonic() + 5
            while not module.tmux("list-clients", "-t", self.session).stdout.strip():
                if time.monotonic() > deadline:
                    self.fail("The tmux client did not attach")
                time.sleep(0.05)
            for index in (2, 1, 3, 4, 5, 6, 7, 8, 9, 1):
                os.write(master, f"\x1b[{48 + index};5u".encode())
                deadline = time.monotonic() + 3
                while module.tmux(
                    "display-message", "-p", "-t", self.session, "#{window_index}"
                ).stdout.strip() != str(index):
                    if time.monotonic() > deadline:
                        self.fail(f"Ctrl+{index} did not select its window")
                    time.sleep(0.05)
        finally:
            process.terminate()
            process.wait(timeout=5)
            os.close(master)
            os.close(slave)

    def test_bash_page_scroll_and_arrow_history(self):
        module.tmux(
            "respawn-window",
            "-k",
            "-t",
            f"{self.session}:2",
            "bash --noprofile --norc -i",
        )
        module.tmux("select-window", "-t", f"{self.session}:2")
        marker = self.root / "arrow-history"
        command = (
            "HISTFILE=/dev/null; "
            "for n in {1..300}; do printf 'scroll line %s\\n' \"$n\"; done; "
            f"history -s \"printf arrow-up > '{marker}'\""
        )
        module.tmux("send-keys", "-t", f"{self.session}:2", command, "Enter")
        master, slave = pty.openpty()
        process = subprocess.Popen(
            ["tmux", "attach-session", "-t", self.session],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            env=dict(os.environ, TERM="xterm-256color"),
        )

        def pane_value(field):
            return module.tmux(
                "display-message", "-p", "-t", f"{self.session}:2", "#{" + field + "}"
            ).stdout.strip()

        def wait_until(predicate):
            deadline = time.monotonic() + 5
            while not predicate():
                if time.monotonic() > deadline:
                    self.fail(
                        "Timed out waiting for scrollback state: mode="
                        + pane_value("pane_in_mode")
                        + ", scroll="
                        + pane_value("scroll_position")
                        + ", window="
                        + pane_value("window_name")
                        + ", key="
                        + module.tmux("list-keys", "-T", "copy-mode", "NPage").stdout
                    )
                time.sleep(0.05)

        try:
            wait_until(
                lambda: bool(
                    module.tmux("list-clients", "-t", self.session).stdout.strip()
                )
            )
            wait_until(lambda: int(pane_value("history_size")) > 100)
            os.write(master, b"\x1b[5~")
            wait_until(lambda: pane_value("pane_in_mode") == "1")
            wait_until(lambda: int(pane_value("scroll_position")) > 0)
            for _ in range(30):
                if pane_value("pane_in_mode") == "0":
                    break
                os.write(master, b"\x1b[6~")
                time.sleep(0.05)
            wait_until(lambda: pane_value("pane_in_mode") == "0")
            os.write(master, b"\x1b[5~")
            wait_until(lambda: pane_value("pane_in_mode") == "1")
            os.write(master, b"\x1b[A")
            wait_until(lambda: pane_value("pane_in_mode") == "0")
            os.write(master, b"\r")
            self.assertEqual(self.wait_for(marker), "arrow-up")
            os.write(master, b"\x1b[5~")
            wait_until(lambda: pane_value("pane_in_mode") == "1")
            os.write(master, b"\x1b[B")
            wait_until(lambda: pane_value("pane_in_mode") == "0")
        finally:
            process.terminate()
            process.wait(timeout=5)
            os.close(master)
            os.close(slave)

    def test_editor_exit_closes_workspace_session(self):
        module.tmux("select-window", "-t", f"{self.session}:2")
        pane_pid = int(
            module.tmux(
                "display-message", "-p", "-t", f"{self.session}:1", "#{pane_pid}"
            ).stdout.strip()
        )
        os.kill(pane_pid, signal.SIGTERM)
        deadline = time.monotonic() + 5
        while (
            module.tmux("has-session", "-t", "=" + self.session, check=False).returncode
            == 0
        ):
            if time.monotonic() > deadline:
                self.fail("The editor exited but its session was left running")
            time.sleep(0.05)

    def test_last_client_disconnect_destroys_session(self):
        clients = []
        try:
            for _ in range(2):
                master, slave = pty.openpty()
                process = subprocess.Popen(
                    ["tmux", "attach-session", "-t", self.session],
                    stdin=slave,
                    stdout=slave,
                    stderr=slave,
                    env=dict(os.environ, TERM="xterm-256color"),
                )
                clients.append((process, master, slave))
            deadline = time.monotonic() + 5
            while (
                len(module.tmux("list-clients", "-t", self.session).stdout.splitlines())
                != 2
            ):
                if time.monotonic() > deadline:
                    self.fail("The two clients did not attach")
                time.sleep(0.05)
            clients[0][0].terminate()
            clients[0][0].wait(timeout=5)
            time.sleep(0.1)
            self.assertEqual(
                module.tmux(
                    "has-session", "-t", "=" + self.session, check=False
                ).returncode,
                0,
            )
            clients[1][0].terminate()
            clients[1][0].wait(timeout=5)
            deadline = time.monotonic() + 5
            while (
                module.tmux(
                    "has-session", "-t", "=" + self.session, check=False
                ).returncode
                == 0
            ):
                if time.monotonic() > deadline:
                    self.fail(
                        "The last client disconnected but its session survived: "
                        + module.tmux(
                            "show-option", "-t", self.session, "destroy-unattached"
                        ).stdout
                        + module.tmux(
                            "show-hooks", "-t", self.session, "client-attached"
                        ).stdout
                    )
                time.sleep(0.05)
        finally:
            for process, master, slave in clients:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
                os.close(master)
                os.close(slave)

    def test_remote_launcher_cleanup_stops_helpers_and_unattached_server(self):
        socket = self.root / "editor.sock"
        server = subprocess.Popen(
            ["/usr/bin/nvim", "--headless", "-u", "NONE", "--listen", str(socket)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            deadline = time.monotonic() + 5
            while not socket.exists():
                if time.monotonic() > deadline:
                    self.fail("The test Neovim server did not start")
                time.sleep(0.05)
            launcher = (HELPER.parent / "nvim-dev").read_text()
            function = launcher[
                launcher.index("cleanup_runtime() {") : launcher.index(
                    "\ntrap cleanup_runtime EXIT"
                )
            ]
            code = (
                "set -euo pipefail; nvim_bin=/usr/bin/nvim; server_ready=true; "
                f"addr={socket}; "
                "sleep 60 & ui_pid=$!; sleep 60 & download_bridge_pid=$!; "
                "sleep 60 & port_bridge_pid=$!; " + function + "\ncleanup_runtime\n"
                'for pid in "$ui_pid" "$download_bridge_pid" "$port_bridge_pid"; do '
                'if kill -0 "$pid" 2>/dev/null; then exit 1; fi; done'
            )
            subprocess.run(["bash", "-c", code], check=True, timeout=10)
            server.wait(timeout=5)
        finally:
            if server.poll() is None:
                server.terminate()
                server.wait(timeout=5)

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
