#!/usr/bin/env python3
"""Thin LSP proxy between Neovim and odoo_ls_server.

Why: while indexing, odoo_ls publishes diagnostics for EVERY file of Odoo core + OCA (~20 000
messages in ~25 s, almost all empty). Neovim keeps processing that stream and does not redraw
or read keys until it ends, so the editor looks frozen for ~30 s after startup.

What it does: forwards everything unchanged, except `textDocument/publishDiagnostics` messages
that carry no information: empty diagnostics for a file that is not open and never had
diagnostics. Messages for open files, real problems, and the "clear" for a file that previously
had problems are all forwarded.

Usage (see lua/plugins/lsp.lua):  python3 odoo_ls_proxy.py odoo_ls_server [server args...]
"""

import io
import json
import subprocess
import sys
import threading


def read_message(stream):
    """Read one LSP frame. Returns (raw_frame_bytes, body_bytes) or (None, None) at EOF.

    `stream` must be buffered: the header is read line by line.
    """
    header = b""
    length = 0
    while True:
        line = stream.readline()
        if not line:
            return None, None
        header += line
        if line == b"\r\n":
            break
        if line.lower().startswith(b"content-length:"):
            length = int(line.split(b":", 1)[1].strip())
    body = stream.read(length)
    if len(body) < length:
        return None, None
    return header + body, body


def main():
    server = subprocess.Popen(
        sys.argv[1:], stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0
    )
    # the pipe itself is unbuffered (bufsize=0, so writes to the server are not delayed);
    # reads go through a buffer instead of one system call per byte
    server_out = io.BufferedReader(server.stdout, 1 << 16)
    open_uris = set()  # files open in Neovim
    with_diags = set()  # files we forwarded non-empty diagnostics for
    lock = threading.Lock()
    out = sys.stdout.buffer

    def client_to_server():
        inp = sys.stdin.buffer
        try:
            while True:
                frame, body = read_message(inp)
                if frame is None:
                    break
                if b"textDocument/didOpen" in body or b"textDocument/didClose" in body:
                    try:
                        msg = json.loads(body)
                        uri = msg["params"]["textDocument"]["uri"]
                        with lock:
                            if msg["method"] == "textDocument/didOpen":
                                open_uris.add(uri)
                            elif msg["method"] == "textDocument/didClose":
                                open_uris.discard(uri)
                    except (ValueError, KeyError):
                        pass
                server.stdin.write(frame)
                server.stdin.flush()
        except (BrokenPipeError, OSError):
            pass
        finally:
            try:
                server.stdin.close()
            except OSError:
                pass

    threading.Thread(target=client_to_server, daemon=True).start()

    try:
        while True:
            frame, body = read_message(server_out)
            if frame is None:
                break
            if b'"textDocument/publishDiagnostics"' in body:
                try:
                    params = json.loads(body).get("params", {})
                    uri, diags = params.get("uri"), params.get("diagnostics") or []
                    with lock:
                        if uri not in open_uris:
                            if diags:
                                with_diags.add(uri)
                            elif uri in with_diags:
                                with_diags.discard(uri)  # forward once to clear old problems
                            else:
                                continue  # empty + not open + nothing to clear: drop
                except ValueError:
                    pass
            out.write(frame)
            out.flush()
    except (BrokenPipeError, OSError):
        pass
    finally:
        server.terminate()


if __name__ == "__main__":
    main()
