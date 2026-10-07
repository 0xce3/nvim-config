"""Verify relay disconnect and termination also reap fallback subprocesses."""

import os
import socket
import subprocess
import tempfile
import threading
import time
import unittest
from pathlib import Path

RELAY = Path(__file__).resolve().parents[1] / "bin/nvim-port-relay"


class PortRelayTest(unittest.TestCase):
    def test_termination_reaps_container_fallback(self):
        with tempfile.TemporaryDirectory(prefix="relay-test-") as temporary:
            root = Path(temporary)
            child_pid = root / "child.pid"
            docker = root / "docker"
            docker.write_text(
                "#!/usr/bin/env python3\n"
                "import os, sys\n"
                f"open({str(child_pid)!r}, 'w').write(str(os.getpid()))\n"
                "index = sys.argv.index('-c')\n"
                "os.execv(sys.executable, [sys.executable, '-c', sys.argv[index + 1], sys.argv[index + 2]])\n"
            )
            docker.chmod(0o700)
            target = socket.socket()
            target.bind(("127.0.0.1", 0))
            target.listen()
            target.settimeout(10)
            target_port = target.getsockname()[1]

            def echo():
                try:
                    connection, _ = target.accept()
                    with connection:
                        connection.settimeout(10)
                        while data := connection.recv(1024):
                            connection.sendall(data)
                finally:
                    target.close()

            thread = threading.Thread(target=echo, daemon=True)
            thread.start()
            with socket.socket() as reservation:
                reservation.bind(("127.0.0.1", 0))
                listen_port = reservation.getsockname()[1]
            process = subprocess.Popen(
                [
                    "python3",
                    str(RELAY),
                    "--listen-port",
                    str(listen_port),
                    "--target-host",
                    "127.0.0.2",
                    "--target-port",
                    str(target_port),
                    "--container",
                    "test-container",
                ],
                env=dict(os.environ, PATH=str(root) + ":" + os.environ["PATH"]),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
            )
            connection = None
            try:
                deadline = time.monotonic() + 5
                while connection is None:
                    try:
                        connection = socket.create_connection(
                            ("127.0.0.1", listen_port), timeout=1
                        )
                    except ConnectionRefusedError:
                        if time.monotonic() > deadline:
                            self.fail("The relay did not start")
                        time.sleep(0.05)
                connection.sendall(b"hello")
                self.assertEqual(connection.recv(5), b"hello")
                pid = int(child_pid.read_text())
                process.terminate()
                _, error = process.communicate(timeout=10)
                self.assertEqual(process.returncode, 0, error.decode())
                with self.assertRaises(ProcessLookupError):
                    os.kill(pid, 0)
                thread.join(timeout=5)
                self.assertFalse(thread.is_alive())
            finally:
                if connection is not None:
                    connection.close()
                if process.poll() is None:
                    process.kill()
                    process.communicate(timeout=5)
                target.close()


if __name__ == "__main__":
    unittest.main()
