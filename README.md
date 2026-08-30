# Wolf98 WSS sound patch for the PC-9821 Cu10

This project replaces Wolf98's PC-9801-86 PCM driver with a native WSS driver
for the NEC PC-9821 Cu10. It restores digitized effects such as doors, gunshots,
and guard voices while leaving the game's existing menu sounds intact.

The patch was verified on a real PC-9821 Cu10 with these detected resources:

- WSS base address `0F40h`
- Codec ID `05h`
- IRQ12 and DMA channel 1 resource routing
- Sound ID `81h`

This repository contains no Wolfenstein 3D executable, game data, or patched
floppy image. The build checks for one exact Wolf98 executable and creates the
patched file locally.

## Supported game executable

The patcher accepts only this file:

```text
Name:   WOLF98.EXE
Size:   271076 bytes
SHA256: d2abaed3cc99fce16cfa20c4c06fd56319cfe9473d1bf6ac48af96ac37260122
```

Other Wolf98 versions are rejected before any output is written.

## Build requirements

The floppy-image builders currently require macOS because they use
`hdiutil`, `newfs_msdos`, and `mount_msdos`.

Install the remaining tools with Homebrew:

```sh
brew install nasm dos2unix sevenzip
```

Python 3 and zsh are also required.

## Build the patch disk

Place your original executable here:

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
out/CU10-WSS.FDI
```

The generated executable should be `534639` bytes. Copy `CU10-WSS.FDI` to a
Gotek USB drive and select it with FastFloppy.

## Install on the PC-9821

The supplied DOS installer expects the hard disk as `B:`, the Gotek floppy as
`C:`, and Wolf98 installed in `B:\WOLF3D`.

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
alone. The installer replaces the old executable without retaining a backup.

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

The patcher verifies the original SHA-256 hash, appends the assembled WSS
driver to the embedded Phar Lap P3 load image, redirects the eight original PCM
entry points, and adjusts the P3 size fields without moving the original stack.

DMA completion is polled through Wolf98's existing timer handlers. Codec
interrupt generation stays disabled. See [technical notes](docs/technical-notes.md)
for the hardware and extender details.

## Scope

This is a machine-specific patch. It has been tested on one PC-9821 Cu10 and
one exact Wolf98 executable. It is not a general Sound Blaster emulator or a
patch for DOS/V Wolfenstein 3D releases.
