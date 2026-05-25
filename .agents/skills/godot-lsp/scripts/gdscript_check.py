#!/usr/bin/env python3
"""
GDScript LSP diagnostics checker.

Connects to the Godot GDScript language server (port 6005) and retrieves
diagnostics for one or more files. Godot pushes diagnostics via the
textDocument/publishDiagnostics notification after textDocument/didOpen.

Usage:
    python3 gdscript_check.py [--project-root /path/to/project] res://path/to/file.gd [res://path/to/another.gd ...]

Exit codes:
    0 — No errors found
    1 — Errors/warnings found
    2 — Connection or protocol error
"""

import json
import select
import socket
import sys
import time
import uuid
from pathlib import Path

HOST = "127.0.0.1"
PORT = 6005
SOCK_TIMEOUT = 10  # seconds per socket operation


class LSPClient:
    """Minimal LSP client for the GDScript language server."""

    def __init__(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(SOCK_TIMEOUT)
        self._buffer = b""
        self._received: list[dict] = []

    def connect(self):
        try:
            self.sock.connect((HOST, PORT))
        except (ConnectionRefusedError, OSError) as e:
            print(
                f"ERROR: Cannot connect to GDScript language server at {HOST}:{PORT}",
                file=sys.stderr,
            )
            print(f"  {e}", file=sys.stderr)
            print("  Is the Godot editor running with this project open?", file=sys.stderr)
            sys.exit(2)

    def send(self, msg: dict) -> None:
        """Send a JSON-RPC message with Content-Length framing."""
        body = json.dumps(msg).encode("utf-8")
        header = f"Content-Length: {len(body)}\r\n\r\n".encode("utf-8")
        self.sock.sendall(header + body)

    def _refill_buffer(self):
        """Read available data from the socket into the buffer."""
        ready = select.select([self.sock], [], [], 1.0)
        if ready[0]:
            chunk = self.sock.recv(65536)
            if chunk:
                self._buffer += chunk
            else:
                raise ConnectionError("Connection closed by server")

    def _parse_from_buffer(self) -> dict | None:
        """Try to parse one complete JSON-RPC message from the buffer."""
        idx = self._buffer.find(b"\r\n\r\n")
        if idx == -1:
            return None

        header_text = self._buffer[:idx].decode("utf-8")
        content_length = 0
        for line in header_text.split("\r\n"):
            if line.lower().startswith("content-length:"):
                content_length = int(line.split(":")[1].strip())
                break

        if content_length == 0:
            raise ValueError("Content-Length header missing or zero")

        body_start = idx + 4
        if len(self._buffer) < body_start + content_length:
            return None

        body = self._buffer[body_start : body_start + content_length]
        self._buffer = self._buffer[body_start + content_length:]
        return json.loads(body.decode("utf-8"))

    def drain_messages(self, timeout: float = 3.0) -> list[dict]:
        """Drain all available messages, waiting up to timeout seconds.
        Returns list of received message dicts."""
        deadline = time.monotonic() + timeout
        messages = []

        while time.monotonic() < deadline:
            msg = self._parse_from_buffer()
            if msg is not None:
                messages.append(msg)
                continue
            self._refill_buffer()

        return messages

    def receive_matching(self, expected_id, poll_secs: float = 5.0) -> dict:
        """Receive messages until finding one with matching id, or poll times out."""
        deadline = time.monotonic() + poll_secs

        while time.monotonic() < deadline:
            msg = self._parse_from_buffer()
            if msg is not None:
                if msg.get("id") == expected_id:
                    return msg
                continue
            self._refill_buffer()

        raise ConnectionError(
            f"Timed out waiting for response to request id={expected_id} "
            f"after {poll_secs}s"
        )

    def shutdown(self):
        try:
            self.sock.close()
        except Exception:
            pass


def make_request(method: str, params: dict = None, rid: int = None) -> dict:
    msg: dict = {
        "jsonrpc": "2.0",
        "id": rid if rid is not None else str(uuid.uuid4()),
        "method": method,
    }
    if params is not None:
        msg["params"] = params
    else:
        msg["params"] = {}
    return msg


def make_notification(method: str, params: dict = None) -> dict:
    msg: dict = {"jsonrpc": "2.0", "method": method}
    if params is not None:
        msg["params"] = params
    else:
        msg["params"] = {}
    return msg


def path_to_uri(path_str: str, project_root: str = "") -> str:
    """Convert a project-relative path (res://) or absolute path to a file URI."""
    if path_str.startswith("res://"):
        if project_root:
            abs_path = Path(project_root) / path_str[len("res://"):]
            return f"file://{abs_path}"
        return path_str
    abs_path = Path(path_str).resolve()
    return f"file://{abs_path}"


def check_diagnostics(file_paths: list[str], project_root: str = "") -> list[dict]:
    """Connect to the GDScript LSP and get diagnostics for the given files.

    Godot's GDScript LSP does not implement textDocument/diagnostic.
    Instead, it pushes diagnostics via textDocument/publishDiagnostics
    notifications after textDocument/didOpen.
    """
    client = LSPClient()
    client.connect()

    try:
        # 1. Initialize
        client.send(make_request("initialize", {
            "processId": None,
            "rootUri": None,
            "capabilities": {},
        }, rid=1))
        init_resp = client.receive_matching(expected_id=1, poll_secs=3)
        caps = init_resp.get("result", {}).get("capabilities", {})
        print(
            f"Connected to GDScript language server. "
            f"Capabilities: {list(caps.keys())}",
            file=sys.stderr,
        )

        # 2. Initialized notification
        client.send(make_notification("initialized"))

        # 3. Open each document and collect diagnostics
        all_diagnostics = []
        for path in file_paths:
            uri = path_to_uri(path, project_root)
            source = ""
            try:
                file_path = uri.replace("file://", "")
                with open(file_path, "r", encoding="utf-8") as f:
                    source = f.read()
            except FileNotFoundError:
                print(f"WARNING: File not found on disk: {path}", file=sys.stderr)
                continue
            except Exception as e:
                print(f"WARNING: Cannot read {path}: {e}", file=sys.stderr)
                continue

            client.send(make_notification("textDocument/didOpen", {
                "textDocument": {
                    "uri": uri,
                    "languageId": "gdscript",
                    "version": 1,
                    "text": source,
                }
            }))
            print(f"Opened: {path}", file=sys.stderr)

            # Godot pushes textDocument/publishDiagnostics after didOpen
            # Drain messages looking for it
            messages = client.drain_messages(timeout=3.0)
            for msg in messages:
                method = msg.get("method", "")
                if method == "textDocument/publishDiagnostics":
                    diagnostics = msg.get("params", {}).get("diagnostics", [])
                    for d in diagnostics:
                        all_diagnostics.append({
                            "file": path,
                            "range": d.get("range", {}),
                            "severity": d.get("severity", "unknown"),
                            "message": d.get("message", ""),
                            "source": d.get("source", ""),
                        })

        return all_diagnostics

    finally:
        client.shutdown()


def severity_name(code: int) -> str:
    """Convert LSP severity code to a human-readable name."""
    return {1: "Error", 2: "Warning", 3: "Information", 4: "Hint"}.get(
        code, f"Unknown({code})"
    )


def format_diagnostics(diagnostics: list[dict]) -> str:
    """Format diagnostics into a human-readable report."""
    if not diagnostics:
        return ""

    lines = []
    errors = [d for d in diagnostics if d["severity"] in (1, 2)]
    hints = [d for d in diagnostics if d["severity"] in (3, 4)]

    if errors:
        lines.append("## Errors & Warnings")
        for d in errors:
            line = d["range"].get("start", {}).get("line", "?")
            col = d["range"].get("start", {}).get("character", "?")
            sev = severity_name(d["severity"])
            lines.append(f"- [{sev}] {d['file']}:{line}:{col} — {d['message']}")
        lines.append("")

    if hints:
        lines.append("## Hints & Information")
        for d in hints:
            line = d["range"].get("start", {}).get("line", "?")
            col = d["range"].get("start", {}).get("character", "?")
            sev = severity_name(d["severity"])
            lines.append(f"- [{sev}] {d['file']}:{line}:{col} — {d['message']}")
        lines.append("")

    return "\n".join(lines)


def parse_args(argv: list[str]) -> tuple[str | None, list[str]]:
    """Parse --project-root and file paths from argv."""
    project_root = None
    file_paths = []
    i = 0
    while i < len(argv):
        if argv[i] == "--project-root" and i + 1 < len(argv):
            project_root = argv[i + 1]
            i += 2
        else:
            file_paths.append(argv[i])
            i += 1
    return project_root, file_paths


def main():
    project_root, file_paths = parse_args(sys.argv[1:])

    if not file_paths:
        print(
            "Usage: gdscript_check.py [--project-root /path/to/project] "
            "res://path/to/file.gd [res://path/to/another.gd ...]",
            file=sys.stderr,
        )
        sys.exit(2)

    diagnostics = check_diagnostics(file_paths, project_root=project_root)

    report = format_diagnostics(diagnostics)
    if report:
        print(report)

    error_count = sum(1 for d in diagnostics if d["severity"] in (1, 2))
    if error_count > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
