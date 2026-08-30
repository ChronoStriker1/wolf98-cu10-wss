# Wolfenstein 3D sound patch for the PC-9821 Cu10

This project patches the PC-98 release of Wolfenstein 3D. It replaces the
PC-9801-86 PCM driver in `WOLF98.EXE` with a native WSS driver for the NEC
PC-9821 Cu10. It restores digitized effects such as doors, gunshots, and guard
voices through the WSS codec. It sends Wolfenstein 3D's original OPL2 music
and AdLib sound effects through the Cu10 extended-FM interface.

The WSS portion was verified on a real PC-9821 Cu10 with these detected
resources:

- WSS base address `0F40h`
- Codec ID `05h`
- IRQ12 and DMA channel 1 resource routing
- Sound ID `80h`

The FM path writes Wolfenstein 3D's OPL2 stream through the Cu10 extended-FM
ports at `1488h/1489h`. The Cu10 hardware test found that the OPL timer responds
with Sound ID `82h` and Yamaha board register `20h` set to `00h`. The game
driver now uses those values instead of the unrelated YMF297 compatibility
sequence.

See [Cu10 audio hardware](docs/cu10-audio-hardware.md) for the chip split,
mixer path, and programming references.

This repository contains no Wolfenstein 3D executable, game data, or patched
floppy image. The build checks for one exact `WOLF98.EXE` and creates the
patched file locally.

## OPL versions

Wolfenstein 3D's IMF music and AdLib sound effects use the Yamaha YM3812
register format, called OPL2. OPL2 provides nine two-operator melodic channels,
or six melodic channels plus five percussion voices when rhythm mode is used.

The tested PC-9821 Cu10 has a YMF288 at `0188h` for standard FM, SSG, and
rhythm, plus a Yamaha YMF701-class WSS and OPL3 audio controller. SIC 2.03
reported the YMF288 directly on the real machine. OPL3 has 18 two-operator
melodic channels, or 15 melodic channels plus five percussion voices in rhythm
mode. That second
arrangement is the source of the Cu10's advertised 20-voice FM specification.

This patch does not rewrite the music for OPL3's second register bank or
four-operator instruments. It uses OPL3 bank 0 in its OPL2-compatible layout.
The patch adds the OPL3 left and right output bits to channel registers `C0h`
through `C8h`; all frequencies, instruments, envelopes, rhythm control, and
timing remain the original OPL2 data.

The Cu10 also has an OPN-compatible FM mode. This patch cannot send
Wolfenstein 3D's OPL2 data to that mode because OPN and OPL use different
operators and register layouts.

## Supported game executable

The patcher accepts only this file:

```text
Name:   WOLF98.EXE
Size:   271076 bytes
SHA256: d2abaed3cc99fce16cfa20c4c06fd56319cfe9473d1bf6ac48af96ac37260122
```

Other versions of `WOLF98.EXE` are rejected before any output is written.

## Build requirements

The floppy-image builders currently require macOS because they use
`hdiutil`, `newfs_msdos`, and `mount_msdos`.

Install the remaining tools with Homebrew:

```sh
brew install nasm dos2unix sevenzip
```

Python 3 and zsh are also required.

## Build the patch disk

Place your original PC-98 executable here:

```text
original/WOLF98.EXE
```

Then run:

```sh
./build_wss_patch_disk.sh
```

The script creates:

```text
out/WOLF98.EXE
out/CU10-DRV.FDI
```

Copy `CU10-DRV.FDI` to a Gotek USB drive and select it with FastFloppy.

## Install on the PC-9821

The supplied DOS installer expects the hard disk as `B:`, the Gotek floppy as
`C:`, and Wolfenstein 3D installed in `B:\WOLF3D`.

Run:

```bat
C:
PATCH
B:
CD \WOLF3D
WOLF98
```

`PATCH.BAT` replaces only `WOLF98.EXE`. It does not change the installed audio,
graphics, maps, or `VSWAP` data and does not retain an executable backup. It
checks only that the destination exists; it does not reread large files from
the slow PC-98 floppy path.

Rebuilding safely overwrites the canonical output image only after the new
image passes its archive check. This applies to `CU10-DRV.FDI` and
`CU10-TST.FDI`; successive builds do not create revision-named disk images.

After starting Wolfenstein 3D, open its in-game Sound menu. Select Sound Blaster
under SOUND EFFECTS and MUSIC. Keep PC-9821 PCM selected for DIGITIZED SOUND.

## Run the standalone hardware test

The standalone test contains no game code and does not require `WOLF98.EXE`:

```sh
./build_wss_test_disk.sh
```

Select `out/CU10-TST.FDI` in FastFloppy and run:

```bat
C:\TEST
```

A clean tone confirms the WSS codec and PC-98 DMA path.

## How it works

The patcher verifies the original SHA-256 hash and appends the assembled sound
driver to the embedded Phar Lap P3 load image in `WOLF98.EXE`. It redirects the
eight original PCM entry points, the AdLib detector, and the AdLib register
writer. It also adjusts the P3 size fields without moving the original stack.

DMA completion is polled through Wolfenstein 3D's existing timer handlers.
Codec interrupt generation stays disabled. The FM path forwards each OPL2
register/value pair to `1488h/1489h`, preserves the game's original six
address-delay reads and 42 data-delay reads, and adds both stereo-output bits to
Wolfenstein 3D's `C0h` through `C8h` channel-control writes. It clears the mute
bit at both Cu10 FM mixer stages without changing their attenuation values. All
nine game voices retain their original frequencies, envelopes, operators, and
waveforms. See [technical notes](docs/technical-notes.md) for the hardware and
extender details.

## Scope

This is a machine-specific patch. It has been tested on one PC-9821 Cu10 and
one exact PC-98 Wolfenstein 3D executable. It is not a general Sound Blaster
emulator or a patch for DOS/V Wolfenstein 3D releases.
