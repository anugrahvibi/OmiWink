#!/usr/bin/env python3
"""Low-rate Hyprland cursor reader for the Omarchy menu face."""

from __future__ import annotations

import json
import os
import select
import socket
import sys
import time
from pathlib import Path

IDLE_INTERVAL = 0.125  # Low-rate wake detection before the idle monitor pauses us
ACTIVE_INTERVAL = 1.0 / 60.0  # Match the display while the pointer is moving
ACTIVE_TAIL = 0.35
SOCKET_TIMEOUT = 0.05


def request_socket_path() -> Path | None:
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
    instance = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not runtime_dir or not instance:
        return None
    return Path(runtime_dir) / "hypr" / instance / ".socket.sock"


def read_cursor_position() -> tuple[int, int] | None:
    path = request_socket_path()
    if path is None:
        return None
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as ipc:
            ipc.settimeout(SOCKET_TIMEOUT)
            ipc.connect(str(path))
            ipc.sendall(b"-j/cursorpos")
            response = bytearray()
            while len(response) < 4096:
                chunk = ipc.recv(512)
                if not chunk:
                    break
                response.extend(chunk)
                start = response.find(b"{")
                end = response.find(b"}", start + 1) if start >= 0 else -1
                if end >= 0:
                    payload = json.loads(response[start : end + 1])
                    return int(payload["x"]), int(payload["y"])
    except (OSError, ValueError, KeyError, json.JSONDecodeError):
        return None
    return None


def emit(position: tuple[int, int]) -> None:
    print(json.dumps({"x": position[0], "y": position[1]}, separators=(",", ":")), flush=True)


def main() -> int:
    stdin_fd = sys.stdin.fileno()
    command_buffer = ""
    paused = False
    previous: tuple[int, int] | None = None
    active_until = 0.0
    next_sample = 0.0
    force_sample = True

    while True:
        if paused:
            ready, _, _ = select.select([stdin_fd], [], [])
        else:
            now = time.monotonic()
            interval = ACTIVE_INTERVAL if now < active_until else IDLE_INTERVAL
            ready, _, _ = select.select([stdin_fd], [], [], interval)

        if ready:
            data = os.read(stdin_fd, 256)
            if not data:
                return 0
            command_buffer += data.decode("utf-8", errors="ignore")
            while "\n" in command_buffer:
                command, command_buffer = command_buffer.split("\n", 1)
                command = command.strip().lower()
                if command == "pause":
                    paused = True
                elif command == "resume":
                    paused = False
                    force_sample = True
                    previous = None
                    active_until = 0.0

        if paused:
            continue

        now = time.monotonic()
        interval = ACTIVE_INTERVAL if now < active_until else IDLE_INTERVAL
        if force_sample or now >= next_sample:
            position = read_cursor_position()
            force_sample = False
            now = time.monotonic()
            if position is not None and (position != previous or previous is None):
                emit(position)
                if previous is not None:
                    active_until = now + ACTIVE_TAIL
                previous = position
            interval = ACTIVE_INTERVAL if now < active_until else IDLE_INTERVAL
            next_sample = now + interval

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
