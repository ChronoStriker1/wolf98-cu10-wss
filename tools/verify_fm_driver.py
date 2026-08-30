#!/usr/bin/env python3
"""Reject FM driver binaries that regress to the broken Cu10 handoff."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("driver", type=Path)
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    driver = args.driver.read_bytes()
    source = args.source.read_text(encoding="ascii")

    required = {
        "Cu10 Sound ID 82 selection": bytes.fromhex(
            "66 ba 60 a4 b0 82 ee"
        ),
        "Yamaha board register 20 selection": bytes.fromhex(
            "66 ba 8e 54 b0 20 ee"
        ),
        "Yamaha board register 20 enable": bytes.fromhex(
            "66 ba 8f 54 30 c0 ee"
        ),
        "CanBe FM left mixer unmute": bytes.fromhex(
            "66 ba 4a 0f b0 30 ee 66 ba 5f 00 ee 66 ba 4b 0f ec 24 7f ee"
        ),
        "CanBe FM right mixer unmute": bytes.fromhex(
            "66 ba 4a 0f b0 31 ee 66 ba 5f 00 ee 66 ba 4b 0f ec 24 7f ee"
        ),
        "OPL3 stereo routing": bytes.fromhex("3c c0 72 07 3c c8 77 03 80 cc 30"),
        "42-read runtime data delay": bytes.fromhex("b9 2a 00 00 00"),
    }
    for description, pattern in required.items():
        count = driver.count(pattern)
        if count != 1:
            raise SystemExit(f"{description}: expected once, found {count}")

    required_regex = {
        "WSS AUX2 left unmute": rb"\xb0\x04\xe8....\x24\x7f\x88\xc4\xb0\x04\xe8",
        "WSS AUX2 right unmute": rb"\xb0\x05\xe8....\x24\x7f\x88\xc4\xb0\x05\xe8",
    }
    for description, pattern in required_regex.items():
        count = len(re.findall(pattern, driver, flags=re.DOTALL))
        if count != 1:
            raise SystemExit(f"{description}: expected once, found {count}")

    forbidden = {
        "obsolete Sound ID 83h handoff": bytes.fromhex(
            "b0 83 ee"
        ),
        "obsolete YMF297 compatibility control": bytes.fromhex("66 ba 8e 14"),
        "shortened 35-read delay": bytes.fromhex("b9 23 00 00 00"),
        "undocumented mixer index 01h mute": bytes.fromhex(
            "66 ba 4a 0f b0 01 ee 66 ba 5f 00 ee 66 ba 4b 0f b0 80 ee"
        ),
        "YM3812 timer-signature rejection gate": bytes.fromhex("80 ff c0 75"),
    }
    for description, pattern in forbidden.items():
        if pattern in driver:
            raise SystemExit(f"{description} is still present")

    forbidden_regex = {
        "obsolete WSS AUX1 left unmute": rb"\xb0\x02\xe8....\x24\x7f\x88\xc4\xb0\x02\xe8",
        "obsolete WSS AUX1 right unmute": rb"\xb0\x03\xe8....\x24\x7f\x88\xc4\xb0\x03\xe8",
    }
    for description, pattern in forbidden_regex.items():
        if re.search(pattern, driver, flags=re.DOTALL):
            raise SystemExit(f"{description} is still present")

    configure_codec = source.split("configure_codec:", 1)[1].split("restore_codec:", 1)[0]
    restore_codec = source.split("restore_codec:", 1)[1].split("opl_detect_init:", 1)[0]
    opl_detect_init = source.split("opl_detect_init:", 1)[1].split("opl_adlib_write:", 1)[0]
    aux2_unmute = "mov al, 4\n    call codec_read\n    and al, 0x7f"
    if aux2_unmute in configure_codec or aux2_unmute in restore_codec:
        raise SystemExit("PCM setup or cleanup still owns the FM AUX2 route")
    if aux2_unmute not in opl_detect_init:
        raise SystemExit("FM initialization does not own the AUX2 unmute")
    if "saved_reg4" in source or "saved_reg5" in source:
        raise SystemExit("PCM cleanup can still restore the FM AUX2 mute state")

    print("FM driver sequence verified")


if __name__ == "__main__":
    main()
