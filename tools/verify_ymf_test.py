#!/usr/bin/env python3
"""Verify the targeted NEC/Yamaha OPL diagnostic binary."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("program", type=Path)
    args = parser.parse_args()
    program = args.program.read_bytes()

    required_code = {
        "Sound ID port": bytes.fromhex("ba 60 a4"),
        "OPL address port": bytes.fromhex("ba 88 14"),
        "NEC Yamaha board index": bytes.fromhex("ba 8e 54"),
        "NEC Yamaha board data": bytes.fromhex("ba 8f 54"),
        "PC-98 indirect controller selector": bytes.fromhex("ba 6c ac"),
        "PC-98 indirect controller data": bytes.fromhex("ba 6e ac"),
        "PC-98 indirect read selector": bytes.fromhex("b8 41 54 ef"),
        "board register 20": bytes.fromhex("b0 20"),
        "Sound ID 82": bytes.fromhex("b0 82 ee"),
        "codec AUX2 left register": bytes.fromhex("b0 04"),
        "codec AUX2 right register": bytes.fromhex("b0 05"),
        "OPL key-on": bytes.fromhex("b8 b0 31"),
        "DOS report create": bytes.fromhex("b4 3c cd 21"),
        "DOS report write": bytes.fromhex("b4 40 cd 21"),
    }
    for description, pattern in required_code.items():
        if pattern not in program:
            raise SystemExit(f"{description} is missing")

    required_text = (
        b"YMFRESUL.TXT",
        b"INITIAL CODEC REG2/3/4/5=",
        b"AUX2 TEST SID/B20/C3/AUX2L/R/FML/R/TIMER/HEARD=",
        b"RESTORED SID/BOARD20/CTL3/AUX2L/R=",
    )
    for value in required_text:
        if value not in program:
            raise SystemExit(f"result field is missing: {value!r}")

    print("NEC/Yamaha OPL diagnostic binary verified")


if __name__ == "__main__":
    main()
