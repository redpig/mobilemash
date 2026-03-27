#!/usr/bin/env python3
"""
mobilemash_cli.py – Host-side CLI for MobileMash ESP32 button presser.

Requires: pyserial  (pip install pyserial)

Usage examples:
    python mobilemash_cli.py --port /dev/ttyUSB0 ping
    python mobilemash_cli.py --port /dev/ttyUSB0 fastboot
    python mobilemash_cli.py --port /dev/ttyUSB0 fastboot --shutdown-ms 30000 --combo-ms 5000
    python mobilemash_cli.py --port /dev/ttyUSB0 press-power 2000
    python mobilemash_cli.py --port /dev/ttyUSB0 release
    python mobilemash_cli.py --port /dev/ttyUSB0 status

SPDX-License-Identifier: Apache-2.0
"""

import argparse
import sys
import time

import serial


def open_serial(port: str, baud: int = 115200, timeout: float = 2.0) -> serial.Serial:
    """Open the serial port and wait for the ESP32 ready banner."""
    ser = serial.Serial(port, baud, timeout=timeout)
    # The ESP32 resets on serial open; wait for the ready line.
    deadline = time.monotonic() + 5.0
    while time.monotonic() < deadline:
        line = ser.readline().decode("utf-8", errors="replace").strip()
        if line:
            print(f"< {line}")
        if "MobileMash ready" in line:
            return ser
    # Even if we didn't see the banner, return the port – the device
    # may already have booted earlier.
    return ser


def send(ser: serial.Serial, cmd: str, wait_ok: bool = True,
         timeout: float = 120.0) -> list[str]:
    """Send a command and collect response lines until OK/ERR or timeout."""
    ser.reset_input_buffer()
    ser.write((cmd + "\n").encode("utf-8"))
    print(f"> {cmd}")

    lines: list[str] = []
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        raw = ser.readline()
        if not raw:
            continue
        line = raw.decode("utf-8", errors="replace").strip()
        if not line:
            continue
        print(f"< {line}")
        lines.append(line)
        if not wait_ok:
            break
        # Terminal responses
        if line.startswith("OK ") or line.startswith("ERR ") or line == "PONG":
            # For multi-phase commands, "OK FASTBOOT complete" is terminal.
            if "complete" in line or "released" in line or line == "PONG":
                break
            if line.startswith("ERR "):
                break
    return lines


def cmd_ping(ser: serial.Serial, _args: argparse.Namespace) -> None:
    send(ser, "PING", timeout=5)


def cmd_status(ser: serial.Serial, _args: argparse.Namespace) -> None:
    send(ser, "STATUS", timeout=5)


def cmd_release(ser: serial.Serial, _args: argparse.Namespace) -> None:
    send(ser, "RELEASE_ALL", timeout=5)


def cmd_press_power(ser: serial.Serial, args: argparse.Namespace) -> None:
    send(ser, f"PRESS_POWER {args.ms}", timeout=(args.ms / 1000) + 10)


def cmd_press_voldn(ser: serial.Serial, args: argparse.Namespace) -> None:
    send(ser, f"PRESS_VOLDN {args.ms}", timeout=(args.ms / 1000) + 10)


def cmd_fastboot(ser: serial.Serial, args: argparse.Namespace) -> None:
    shutdown_ms = args.shutdown_ms
    combo_ms = args.combo_ms
    total_s = (shutdown_ms + combo_ms) / 1000 + 15
    send(ser, f"FASTBOOT {shutdown_ms} {combo_ms}", timeout=total_s)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="MobileMash – ESP32 phone button presser CLI")
    parser.add_argument("--port", "-p", required=True,
                        help="Serial port (e.g. /dev/ttyUSB0)")
    parser.add_argument("--baud", type=int, default=115200)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("ping")
    sub.add_parser("status")
    sub.add_parser("release")

    pp = sub.add_parser("press-power")
    pp.add_argument("ms", type=int, help="Hold duration in milliseconds")

    pv = sub.add_parser("press-voldn")
    pv.add_argument("ms", type=int, help="Hold duration in milliseconds")

    fb = sub.add_parser("fastboot")
    fb.add_argument("--shutdown-ms", type=int, default=30000,
                     help="Power-hold duration for force shutdown (default 30000)")
    fb.add_argument("--combo-ms", type=int, default=5000,
                     help="Volume-down + power combo duration (default 5000)")

    args = parser.parse_args()

    ser = open_serial(args.port, args.baud)

    dispatch = {
        "ping": cmd_ping,
        "status": cmd_status,
        "release": cmd_release,
        "press-power": cmd_press_power,
        "press-voldn": cmd_press_voldn,
        "fastboot": cmd_fastboot,
    }
    dispatch[args.command](ser, args)
    ser.close()


if __name__ == "__main__":
    main()
