#!/usr/bin/env python3
"""Verify the Cu10 report writer before it is placed in the test image."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("program", type=Path)
    args = parser.parse_args()
    program = args.program.read_bytes()

    required_code = {
        "DOS create/truncate": bytes.fromhex("b4 3c cd 21"),
        "DOS file write": bytes.fromhex("b4 40 cd 21"),
        "DOS file close": bytes.fromhex("b4 3e cd 21"),
        "PnP selector": bytes.fromhex("ba 24 0c"),
        "PnP address low": bytes.fromhex("ba 2b 0c"),
        "PnP address high": bytes.fromhex("ba 2d 0c"),
        "NEC Yamaha board index": bytes.fromhex("ba 8e 54"),
        "NEC Yamaha board data": bytes.fromhex("ba 8f 54"),
        "PC-98 indirect controller selector": bytes.fromhex("ba 6c ac"),
        "PC-98 indirect controller data": bytes.fromhex("ba 6e ac"),
        "PC-98 indirect read selector": bytes.fromhex("b8 41 54 ef"),
        "OPL3-SA password": bytes.fromhex("b0 1d ee"),
    }
    for description, pattern in required_code.items():
        if pattern not in program:
            raise SystemExit(f"{description} is missing")

    required_text = (
        b"CU10INFO.TXT",
        b"CODEC AUX1 L/R REG2/3=",
        b"CODEC AUX2 L/R REG4/5=",
        b"PNP 0C24 INITIAL=",
        b"YMF BOARD 548E/548F REGISTER DUMP",
        b"OPL3SA F86 REGS",
        b"OPL3SA 480 REGS",
        b"INDIRECT AC6C OPL3SA REGS",
    )
    for value in required_text:
        if value not in program:
            raise SystemExit(f"report field is missing: {value!r}")

    print("Cu10 report writer binary verified")


if __name__ == "__main__":
    main()
