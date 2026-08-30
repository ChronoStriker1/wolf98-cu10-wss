#!/usr/bin/env python3
"""Verify that the Cu10 FM diagnostic contains every intended hardware test."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("program", type=Path)
    args = parser.parse_args()
    program = args.program.read_bytes()

    required_code = {
        "OPN address port": bytes.fromhex("ba 88 01"),
        "OPL address port": bytes.fromhex("ba 88 14"),
        "Sound ID port": bytes.fromhex("ba 60 a4"),
        "CanBe mixer index port": bytes.fromhex("ba 4a 0f"),
        "WSS codec index port": bytes.fromhex("ba 44 0f"),
        "OPN key-on command": bytes.fromhex("b8 28 f0"),
        "OPL key-on command": bytes.fromhex("b8 b0 31"),
        "YMF701 OPL3 NEW-mode command": bytes.fromhex("b8 05 01"),
        "YMF701 controller port": bytes.fromhex("ba 86 0f"),
        "YMF701 controller password": bytes.fromhex("b0 1d ee"),
    }
    for description, pattern in required_code.items():
        if pattern not in program:
            raise SystemExit(f"{description} is missing")

    required_text = (
        b"TEST 1: Standard OPN FM",
        b"TEST 2: Direct extended FM",
        b"TEST 3: 118/YMF297-style",
        b"TEST 4: NEC/YMF701-style",
        b"TEST 5: YMF701 controller synth enable",
        b"TEST 6: YMF701 controller enable plus NEC",
        b"Register report:",
    )
    for text in required_text:
        if text not in program:
            raise SystemExit(f"diagnostic label is missing: {text!r}")

    print("FM diagnostic binary verified")


if __name__ == "__main__":
    main()
