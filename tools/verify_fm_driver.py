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
        "Sound ID status check": bytes.fromhex("66 ba 60 a4 ec a8 02"),
        "Sound ID 82h selection": bytes.fromhex(
            "b0 82 ee e6 5f e6 5f e6 5f 66 ba 4a 0f"
        ),
        "route-preserving 0F4Ah/0F4Bh update": bytes.fromhex(
            "66 ba 4a 0f b0 01 ee 66 42 ec a8 88 74 03 24 77 ee"
        ),
        "OPL3 NEW-mode bank write": bytes.fromhex(
            "66 ba 8a 14 b0 05 ee e6 5f e6 5f e6 5f 66 ba 8b 14 b0 01 ee"
        ),
        "F7h compatibility register cleared": bytes.fromhex(
            "66 ba 88 14 b0 f7 ee e6 5f e6 5f e6 5f 66 ba 89 14 30 c0 ee"
        ),
        "42-read runtime data delay": bytes.fromhex("b9 2a 00 00 00"),
    }
    for description, pattern in required.items():
        count = driver.count(pattern)
        if count != 1:
            raise SystemExit(f"{description}: expected once, found {count}")

    forbidden = {
        "obsolete 148Eh control port": bytes.fromhex("66 ba 8e 14"),
        "obsolete 148Fh control port": bytes.fromhex("66 ba 8f 14"),
        "obsolete 2000-iteration route delay": bytes.fromhex("b9 d0 07 00 00"),
    }
    for description, pattern in forbidden.items():
        if pattern in driver:
            raise SystemExit(f"{description} is still present")

    print("FM driver sequence verified")


if __name__ == "__main__":
    main()
