#!/usr/bin/env python3
"""Add the Cu10 WSS driver to the known Wolf98 executable."""

from __future__ import annotations

import argparse
import hashlib
import struct
from pathlib import Path


EXPECTED_SHA256 = "d2abaed3cc99fce16cfa20c4c06fd56319cfe9473d1bf6ac48af96ac37260122"
P3_OFFSET = 0x6180
P3_HEADER_SIZE = 0x180
P3_LOAD_OFFSET = 0x200
LOAD_OFFSET = P3_OFFSET + 0x200
DRIVER_ADDRESS = 0x7C000
ORIGINAL_TOTAL_MEMORY = 0x8B001

# Original load-image address -> symbol offset reported by NASM's listing.
ENTRY_POINTS = {
    0x2EEE8: "driver_detect",
    0x2EF00: "driver_init",
    0x2F05B: "driver_shutdown",
    0x2F0B9: "driver_play",
    0x2F107: "driver_stop",
    0x2F115: "driver_set_rate",
    0x2F159: "driver_set_volume",
    0x2F16C: "driver_set_pan",
    0x2E4A3: "opl_adlib_write",
    0x2E4CD: "opl_detect_init",
}

EXPECTED_ENTRY_BYTES = {
    0x2EEE8: bytes.fromhex("9c fa 66 ba 60"),
    0x2EF00: bytes.fromhex("53 80 3d 5b b9"),
    0x2F05B: bytes.fromhex("56 57 53 9c fa"),
    0x2F0B9: bytes.fromhex("c8 00 00 00 80"),
    0x2F107: bytes.fromhex("9c fa e8 ce 01"),
    0x2F115: bytes.fromhex("c8 00 00 00 56"),
    0x2F159: bytes.fromhex("c8 00 00 00 8a"),
    0x2F16C: bytes.fromhex("c8 00 00 00 8b"),
    0x2E4A3: bytes.fromhex("c8 00 00 00 9c"),
    0x2E4CD: bytes.fromhex("53 6a 60 6a 04"),
}

# Wolf selects one of these existing timer handlers according to its current
# speaker/music mode. Redirect every choice through a WSS DMA poll wrapper.
TIMER_CALLBACKS = {
    0x2B955: ("timer_wrapper_7000", 0x2D86D),
    0x2B96C: ("timer_wrapper_700", 0x2D8DD),
    0x2B980: ("timer_wrapper_140", 0x2DAAC),
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def parse_listing(path: Path) -> dict[str, int]:
    symbols: dict[str, int] = {}
    pending: str | None = None
    for line in path.read_text(encoding="ascii", errors="replace").splitlines():
        stripped = line.strip()
        if not stripped.endswith(":"):
            if pending is None:
                continue
            fields = stripped.split()
            if len(fields) >= 2 and len(fields[1]) == 8:
                try:
                    symbols[pending] = DRIVER_ADDRESS + int(fields[1], 16)
                    pending = None
                except ValueError:
                    pass
            continue
        pending = stripped[:-1].split()[-1]
        # NASM prints the label on one line and its first byte on the next.
        fields = stripped.split()
        if len(fields) >= 2 and len(fields[1]) == 8:
            try:
                symbols[pending] = DRIVER_ADDRESS + int(fields[1], 16)
                pending = None
            except ValueError:
                pass
    return symbols


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("driver", type=Path)
    parser.add_argument("listing", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    original = args.source.read_bytes()
    actual_hash = sha256(original)
    if actual_hash != EXPECTED_SHA256:
        raise SystemExit(f"refusing unknown WOLF98.EXE: {actual_hash}")

    if original[P3_OFFSET : P3_OFFSET + 2] != b"P3":
        raise SystemExit("P3 header not found at the expected offset")
    load_size = struct.unpack_from("<I", original, P3_OFFSET + 0x2A)[0]
    if load_size != 0x3BF64:
        raise SystemExit(f"unexpected original load-image size: {load_size:#x}")

    driver = args.driver.read_bytes()
    symbols = parse_listing(args.listing)
    required_symbols = list(ENTRY_POINTS.values()) + [
        name for name, _ in TIMER_CALLBACKS.values()
    ]
    missing = [name for name in required_symbols if name not in symbols]
    if missing:
        raise SystemExit(f"symbols missing from NASM listing: {', '.join(missing)}")

    patched = bytearray(original)
    driver_file_offset = LOAD_OFFSET + DRIVER_ADDRESS
    if len(patched) < driver_file_offset:
        patched.extend(b"\0" * (driver_file_offset - len(patched)))
    patched.extend(driver)

    for old_address, symbol in ENTRY_POINTS.items():
        file_offset = LOAD_OFFSET + old_address
        expected = EXPECTED_ENTRY_BYTES[old_address]
        actual = bytes(patched[file_offset : file_offset + 5])
        if actual != expected:
            raise SystemExit(
                f"entry {old_address:#x} changed: expected {expected.hex()}, got {actual.hex()}"
            )
        target = symbols[symbol]
        displacement = target - (old_address + 5)
        patched[file_offset : file_offset + 5] = b"\xe9" + struct.pack("<i", displacement)

    for immediate_address, (symbol, old_target) in TIMER_CALLBACKS.items():
        file_offset = LOAD_OFFSET + immediate_address
        expected = struct.pack("<I", old_target)
        actual = bytes(patched[file_offset : file_offset + 4])
        if actual != expected:
            raise SystemExit(
                f"timer callback {immediate_address:#x} changed: "
                f"expected {expected.hex()}, got {actual.hex()}"
            )
        patched[file_offset : file_offset + 4] = struct.pack("<I", symbols[symbol])

    new_load_size = DRIVER_ADDRESS + len(driver)
    if new_load_size >= ORIGINAL_TOTAL_MEMORY:
        raise SystemExit("driver collides with the original stack")
    new_p3_file_size = P3_LOAD_OFFSET + new_load_size
    new_minimum_extra = ORIGINAL_TOTAL_MEMORY - new_load_size
    struct.pack_into("<I", patched, P3_OFFSET + 0x06, new_p3_file_size)
    struct.pack_into("<I", patched, P3_OFFSET + 0x2A, new_load_size)
    struct.pack_into("<I", patched, P3_OFFSET + 0x56, new_minimum_extra)
    struct.pack_into("<I", patched, P3_OFFSET + 0x74, new_load_size)

    expected_file_size = P3_OFFSET + new_p3_file_size
    if len(patched) != expected_file_size:
        raise SystemExit(
            f"internal size mismatch: file {len(patched):#x}, P3 {expected_file_size:#x}"
        )

    args.output.write_bytes(patched)
    print(f"original sha256 {actual_hash}")
    print(f"driver address  {DRIVER_ADDRESS:#x}")
    print(f"driver bytes    {len(driver)}")
    print(f"patched bytes   {len(patched)}")
    print(f"patched sha256  {sha256(patched)}")


if __name__ == "__main__":
    main()
