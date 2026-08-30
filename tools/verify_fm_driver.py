#!/usr/bin/env python3
"""Reject FM driver binaries that regress to the broken Cu10 handoff."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("driver", type=Path)
    args = parser.parse_args()
    driver = args.driver.read_bytes()

    required = {
        "Sound ID family check": bytes.fromhex(
            "66 ba 60 a4 ec 24 f0 3c 70 74 08 3c 80"
        ),
        "audible compatibility control ports": bytes.fromhex(
            "66 ba 8e 14 30 c0 ee 66 ba 8f 14 ec a8 08"
        ),
        "compatibility route delay": bytes.fromhex("b9 d0 07 00 00"),
        "OPL3 stereo routing": bytes.fromhex("3c c0 72 07 3c c8 77 03 80 cc 30"),
        "42-read runtime data delay": bytes.fromhex("b9 2a 00 00 00"),
    }
    for description, pattern in required.items():
        count = driver.count(pattern)
        if count != 1:
            raise SystemExit(f"{description}: expected once, found {count}")

    forbidden = {
        "regressing Sound ID 82h handoff": bytes.fromhex(
            "b0 82 ee e6 5f e6 5f e6 5f"
        ),
        "shortened 35-read delay": bytes.fromhex("b9 23 00 00 00"),
    }
    for description, pattern in forbidden.items():
        if pattern in driver:
            raise SystemExit(f"{description} is still present")

    print("FM driver sequence verified")


if __name__ == "__main__":
    main()
