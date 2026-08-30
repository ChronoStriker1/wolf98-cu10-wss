# Wolfenstein 3D sound patch for the PC-9821 Cu10

This project patches the PC-98 release of Wolfenstein 3D. It replaces the
PC-9801-86 PCM driver in `WOLF98.EXE` with a native WSS driver for the NEC
PC-9821 Cu10. It restores digitized effects such as doors, gunshots, and guard
voices. It also sends Wolfenstein 3D's original OPL2 music and AdLib sound
effects to the Cu10's integrated OPL3-compatible FM hardware.

The WSS portion was verified on a real PC-9821 Cu10 with these detected
resources:

- WSS base address `0F40h`
- Codec ID `05h`
- IRQ12 and DMA channel 1 resource routing
- Sound ID `81h`

The FM path targets the Cu10's YMF701 OPL3-SA1 compatibility interface at
`1488h` through `148Bh`. Its initialization is transcribed from NEC/Yamaha's
YMF701 Windows 95 driver for PC-9821 ValueStar systems.

This repository contains no Wolfenstein 3D executable, game data, or patched
floppy image. The build checks for one exact `WOLF98.EXE` and creates the
patched file locally.

## OPL versions

Wolfenstein 3D's IMF music and AdLib sound effects use the Yamaha YM3812
register format, called OPL2. OPL2 provides nine two-operator melodic channels,
or six melodic channels plus five percussion voices when rhythm mode is used.

The PC-9821 Cu10 uses a Yamaha YMF701 OPL3-SA1. Its integrated OPL3
synthesizer provides 18 two-operator melodic channels, or 15 melodic channels
plus five percussion voices in rhythm mode. That second arrangement is the
source of the Cu10's advertised 20-voice FM specification.

This patch does not rewrite the music for OPL3's second register bank or
four-operator instruments. It uses OPL3 bank 0 in its OPL2-compatible layout.
The patch adds the OPL3 left and right output bits to channel registers `C0h`
through `C8h`; all frequencies, instruments, envelopes, rhythm control, and
timing remain the original OPL2 data.

The Cu10 also has an OPN-compatible FM mode. This patch does not use that mode
for Wolfenstein 3D music because OPN and OPL use different operators and
register layouts.

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

Place your original PC-98 files here:

```text
original/WOLF98.EXE
original/AUDIOHED.WL6
original/AUDIOT.WL6
```

Then run:

```sh
./build_wss_patch_disk.sh
```

The audio pair must come from the supported PC-98 release. It is restored by
the installer so a previously tested DOS/GOG archive cannot remain mixed with
the PC-98 executable. These files remain ignored by Git and are not distributed
by this repository.

The script creates:

```text
out/WOLF98.EXE
out/CU10-R2.FDI
```

Copy `CU10-R2.FDI` to a Gotek USB drive and select it with FastFloppy.

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

`PATCH.BAT` also joins the split `VSWAP` and `98GRAPH` files produced by the
four-disk installer used during development. Existing complete files are left
alone. The installer deletes and directly replaces the executable and matching
PC-98 audio pair without retaining backups or requiring duplicate staging
space on `B:`.

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

DMA completion is polled through Wolfenstein 3D's existing timer handlers. Codec
interrupt generation stays disabled. The FM patch performs the YMF701-specific
PC-98 handoff, enables OPL3 NEW mode through the second bank, and forwards each
OPL2 register/value pair to `1488h/1489h`. It preserves the game's original
six address-delay reads and 42 data-delay reads so writes are not dropped. The
patch also adds both stereo-output bits to Wolfenstein 3D's `C0h` through `C8h`
channel-control writes. All nine game voices retain their original frequencies,
envelopes, operators, and waveforms.
See [technical notes](docs/technical-notes.md) for the hardware and extender
details.

## Scope

This is a machine-specific patch. It has been tested on one PC-9821 Cu10 and
one exact PC-98 Wolfenstein 3D executable. It is not a general Sound Blaster
emulator or a patch for DOS/V Wolfenstein 3D releases.
