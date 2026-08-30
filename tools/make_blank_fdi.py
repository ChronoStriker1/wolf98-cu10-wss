#!/usr/bin/env python3
"""Create a blank 1.2 MB PC-98 2HD FDI image."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


HEADER_SIZE = 4096
DISK_SIZE = 1_261_568


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    header = struct.pack(
        "<8I4064x",
        0,
        144,
        HEADER_SIZE,
        DISK_SIZE,
        1024,
        8,
        2,
        77,
    )
    args.output.write_bytes(header + bytes(DISK_SIZE))
    print(f"wrote {args.output}")


if __name__ == "__main__":
    main()
