#!/usr/bin/env python3
"""Inspect and extract the embedded Phar Lap P3 executable in WOLF98.EXE."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


FIELDS = (
    ("signature", "2s", 0x00),
    ("level", "H", 0x02),
    ("header_size", "H", 0x04),
    ("file_size", "I", 0x06),
    ("checksum16", "H", 0x0A),
    ("runtime_parameters_offset", "I", 0x0C),
    ("runtime_parameters_size", "I", 0x10),
    ("relocation_table_offset", "I", 0x14),
    ("relocation_table_size", "I", 0x18),
    ("segment_table_offset", "I", 0x1C),
    ("segment_table_size", "I", 0x20),
    ("segment_entry_size", "H", 0x24),
    ("load_image_offset", "I", 0x26),
    ("load_image_size", "I", 0x2A),
    ("symbol_table_offset", "I", 0x2E),
    ("symbol_table_size", "I", 0x32),
    ("minimum_extra", "I", 0x56),
    ("maximum_extra", "I", 0x5A),
    ("base_load_offset", "I", 0x5E),
    ("initial_esp", "I", 0x62),
    ("initial_ss", "H", 0x66),
    ("initial_eip", "I", 0x68),
    ("initial_cs", "H", 0x6C),
    ("flags", "H", 0x72),
    ("memory_requirement", "I", 0x74),
    ("stack_size", "I", 0x7C),
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("executable", type=Path)
    parser.add_argument("--output-directory", type=Path)
    args = parser.parse_args()

    executable = args.executable.read_bytes()
    p3_offset = executable.find(b"P3\x01\x00")
    if p3_offset < 0:
        raise SystemExit("Embedded flat-model P3 executable not found")

    values: dict[str, int | bytes] = {}
    for name, field_format, relative_offset in FIELDS:
        values[name] = struct.unpack_from("<" + field_format, executable, p3_offset + relative_offset)[0]

    print(f"p3_file_offset=0x{p3_offset:x}")
    for name, _, _ in FIELDS:
        value = values[name]
        if isinstance(value, bytes):
            print(f"{name}={value!r}")
        else:
            print(f"{name}=0x{value:x} ({value})")

    p3_end = p3_offset + int(values["file_size"])
    if p3_end != len(executable):
        raise SystemExit(
            f"P3 size mismatch: header ends at 0x{p3_end:x}, file ends at 0x{len(executable):x}"
        )

    if args.output_directory:
        output_directory = args.output_directory
        output_directory.mkdir(parents=True, exist_ok=True)
        p3_file = executable[p3_offset:p3_end]
        load_start = int(values["load_image_offset"])
        load_end = load_start + int(values["load_image_size"])
        (output_directory / "WOLF98.EXP").write_bytes(p3_file)
        (output_directory / "WOLF98.BIN").write_bytes(p3_file[load_start:load_end])
        print(f"wrote={output_directory / 'WOLF98.EXP'}")
        print(f"wrote={output_directory / 'WOLF98.BIN'}")


if __name__ == "__main__":
    main()
