#!/usr/bin/env python3
"""Bounded Linux PTY smoke for the tracked Bonsai binary and synthetic fixture.

No package dependencies, private data, image snapshots or source modifications.
A green smoke establishes key delivery, repaint and non-writing only, not IME or
paired LOAM acceptance.
"""
import errno
import fcntl
import hashlib
import os
from pathlib import Path
import pty
import re
import select
import shutil
import signal
import struct
import sys
import tempfile
import termios
import time

DIMENSIONS = ((120, 36), (80, 24), (48, 14), (32, 9))
CSI = re.compile(rb"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\)|[()][0-9A-Za-z])")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def winsize(fd, width, height):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", height, width, 0, 0))


class Session:
    def __init__(self, executable, book, width, height):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            try:
                winsize(0, width, height)
                os.environ["TERM"] = "xterm-256color"
                os.environ["LANG"] = "C.UTF-8"
                os.execv(str(executable), [str(executable), "--book", str(book)])
            except BaseException as exc:
                os.write(2, ("exec failure: " + repr(exc)).encode())
                os._exit(127)
        self.buffer = bytearray()
        self.reaped = False
        fcntl.fcntl(self.fd, fcntl.F_SETFL, fcntl.fcntl(self.fd, fcntl.F_GETFL) | os.O_NONBLOCK)

    def pump(self, seconds=0.5):
        deadline = time.monotonic() + seconds
        start = len(self.buffer)
        while time.monotonic() < deadline:
            ready, _, _ = select.select([self.fd], [], [], min(0.08, max(0, deadline - time.monotonic())))
            if ready:
                try:
                    data = os.read(self.fd, 65536)
                except OSError as exc:
                    if exc.errno in (errno.EIO, errno.EAGAIN):
                        break
                    raise
                if not data:
                    break
                self.buffer.extend(data)
                if len(self.buffer) > 2_000_000:
                    raise AssertionError("PTY emitted excessive output")
        return bytes(self.buffer[start:])

    def send(self, data, seconds=0.35):
        os.write(self.fd, data)
        return self.pump(seconds)

    def resize(self, width, height):
        winsize(self.fd, width, height)
        os.kill(self.pid, signal.SIGWINCH)
        return self.pump(0.55)

    def wait_for(self, fragment, limit=6.0):
        deadline = time.monotonic() + limit
        while time.monotonic() < deadline:
            self.pump(0.15)
            visible = CSI.sub(b"", bytes(self.buffer))
            if fragment in visible:
                return
            if self.exit_code(block=False) is not None:
                break
        raise AssertionError("expected terminal text absent: " + repr(fragment))

    def exit_code(self, block=False):
        if self.reaped:
            return self.code
        flags = 0 if block else os.WNOHANG
        pid, status = os.waitpid(self.pid, flags)
        if pid == 0:
            return None
        self.reaped = True
        self.code = os.waitstatus_to_exitcode(status)
        return self.code

    def finish(self):
        if self.exit_code() is None:
            self.send(b"\x11", 0.4)  # Ctrl-Q: explicit non-saving TUI exit
        deadline = time.monotonic() + 5
        while self.exit_code() is None and time.monotonic() < deadline:
            self.pump(0.15)
        code = self.exit_code()
        if code is None:
            raise AssertionError("TUI did not exit on Ctrl-Q")
        if code != 0:
            raise AssertionError("TUI exited with code " + str(code))

    def close(self):
        if not self.reaped:
            try:
                os.kill(self.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            os.waitpid(self.pid, 0)
            self.reaped = True
        os.close(self.fd)


def smoke(binary, fixture, width, height, root):
    owned = root / f"{width}x{height}"
    owned.mkdir(mode=0o700)
    book = owned / "book.sexp"
    shutil.copyfile(fixture, book)
    before = digest(book)
    sess = Session(binary, book, width, height)
    try:
        sess.wait_for(b"bakhlo")
        # Home -> Calendar -> Balances; inspect first account, switch mode,
        # inspect detail, then resize while the same actual PTY stays alive.
        sess.send(b"\r")
        sess.send(b"b")
        sess.wait_for(b"Balances / Current")
        sess.wait_for(b"+1,000 jpy")
        sess.send(b"j")
        sess.send(b"k")
        sess.send(b"v")
        sess.send(b"v")
        sess.send(b"\t")
        sess.send(b"\x1b")  # Escape from selected detail
        next_width, next_height = (80, 24) if width < 80 else (48, 14)
        changed = sess.resize(next_width, next_height)
        if not changed:
            raise AssertionError("no TUI repaint after SIGWINCH")
        sess.resize(width, height)
        sess.finish()
    finally:
        sess.close()
    if digest(book) != before:
        raise AssertionError("read-only PTY session modified book bytes")
    # A new *process*, not a redraw of the same controller. Verify that
    # navigation and the supported exact balance survive cold reloading.
    reopened = Session(binary, book, width, height)
    try:
        reopened.wait_for(b"bakhlo")
        reopened.send(b"\r")
        reopened.send(b"b")
        reopened.wait_for(b"Balances / Current")
        reopened.wait_for(b"+1,000 jpy")
        reopened.finish()
    finally:
        reopened.close()
    if digest(book) != before:
        raise AssertionError("cold PTY reopen modified book bytes")
    if sorted(p.name for p in owned.iterdir()) != ["book.sexp"]:
        raise AssertionError("read-only PTY session created extra authority/config files")
    print(f"PASS: PTY {width}x{height} -> {next_width}x{next_height} -> {width}x{height}, keyboard, exact +1,000 jpy, cold reopen, exit, bytes unchanged", flush=True)


def smoke_record_preview_refusal(binary, fixture, root):
    """Real PTY: valid draft -> narrow preview refusal -> cancel, no write.

    Never send Publish while full-size. The only attempted Publish occurs at
    32x9, where the shared Record gate must refuse. The fixture and all
    generated trial files remain isolated in a fresh temporary directory.
    """
    owned = root / "record-preview-refusal"
    owned.mkdir(mode=0o700)
    book = owned / "book.sexp"
    shutil.copyfile(fixture, book)
    before = digest(book)
    sess = Session(binary, book, 80, 24)
    try:
        sess.wait_for(b"bakhlo")
        sess.send(b"r")
        sess.wait_for(b"Record / Edit")
        # Same positive/negative synthetic postings as Record_session_checks.
        # The writer is not invoked by typing or opening the Preview.
        sess.send(b"PTY snack")
        sess.send(b"\\t\\t")
        sess.send(b"wallet")
        sess.send(b"\\r")
        sess.send(b"-37")
        sess.send(b"\\t")
        sess.send(b"food")
        sess.send(b"\\r")
        sess.send(b"+37")
        sess.send(b"\\r")
        sess.wait_for(b"Record / Preview")
        if digest(book) != before:
            raise AssertionError("opening Record Preview wrote authority bytes")
        sess.resize(32, 9)
        # On a 32x9 window, even a chosen Publish must refuse. A successful
        # save would mutate the book and/or create publication artifacts.
        sess.send(b"\\r")
        if sess.exit_code() is not None:
            raise AssertionError("narrow Preview Enter unexpectedly exited TUI")
        if digest(book) != before:
            raise AssertionError("narrow Preview Enter published hidden evidence")
        # Once enlarged the original Preview must still exist; Escape closes
        # without publishing and retains the draft for an explicit revisit.
        sess.buffer.clear()
        sess.resize(80, 24)
        sess.wait_for(b"Record / Preview")
        sess.send(b"\\x1b")
        if digest(book) != before:
            raise AssertionError("Preview Escape wrote authority bytes")
        sess.buffer.clear()
        sess.send(b"r")
        sess.wait_for(b"Record / Edit")
        sess.wait_for(b"PTY snack")
        # Ctrl-Q from the returned Home, not from inside an active editor.
        sess.send(b"\\x1b")
        sess.finish()
    finally:
        sess.close()
    if digest(book) != before:
        raise AssertionError("Record draft cancel modified authority")
    if sorted(p.name for p in owned.iterdir()) != ["book.sexp"]:
        raise AssertionError("Record preview/cancel created unexpected files")
    print("PASS: PTY Record draft -> Preview -> 32x9 Publish refusal -> Escape/cold draft resume, exact unchanged authority", flush=True)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: ci_tui_pty.py NATIVE_BINARY SYNTHETIC_FIXTURE")
    binary = Path(sys.argv[1]).resolve(strict=True)
    fixture = Path(sys.argv[2]).resolve(strict=True)
    if fixture.name != "daily-book.sexp" or fixture.parent.name != "examples":
        raise SystemExit("refuse any noncanonical synthetic fixture")
    if b"SYNTHETIC ONLY" not in fixture.read_bytes():
        raise SystemExit("fixture must explicitly say SYNTHETIC ONLY")
    with tempfile.TemporaryDirectory(prefix="ci-pty-", dir="scratch") as tmp:
        os.chmod(tmp, 0o700)
        for width, height in DIMENSIONS:
            smoke(binary, fixture, width, height, Path(tmp))
        smoke_record_preview_refusal(binary, fixture, Path(tmp))
    print("PASS: four PTY dimensions and narrow Record Preview non-publication (synthetic, no LOAM/IME claim)", flush=True)


if __name__ == "__main__":
    main()
