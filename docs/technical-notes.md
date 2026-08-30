# Technical notes

## Why the original sound path fails

The PC-98 Wolfenstein 3D executable, `WOLF98.EXE`, has a PC-9821 PCM path, but
that driver accesses the PC-9801-86 register block at `A468h` through `A46Ch`.
The PC-9821 Cu10 reports Sound ID `81h` and exposes a WSS-compatible codec at
`0F40h`. Changing the sound ID alone cannot translate those register
interfaces.

## WSS setup

The replacement driver uses:

```text
WSS configuration: 22h
Codec index/data:   0F44h / 0F45h
Codec status:       0F46h
Format:             unsigned 8-bit mono at 8000 Hz
DMA:                PC-98 channel 1
```

Configuration `22h` matches the routing used by the standalone tone test on the
target Cu10. Codec register 10 has interrupt generation disabled, so the driver
does not install an IRQ12 handler.

## DMA and protected mode

The driver allocates 32 KiB of conventional DOS memory through Phar Lap service
`INT 21h`, function `25C0h`. It selects a 16 KiB window that does not cross a
64 KiB DMA boundary.

Phar Lap selector `34h` maps physical memory. The game's normal data selector
ends near its load image and may not cover the DOS allocation. Copying samples
through that selector caused a general-protection fault. The replacement uses
selector `34h` for the DMA destination, matching another conventional-memory
copy inside the original executable.

DMA terminal count is polled from wrappers around all three timer handlers that
Wolfenstein 3D can select. Each wrapper preserves flags, general registers, and
segment registers before calling the WSS poll routine.

## Volume and panning

Wolfenstein 3D's master-volume argument runs from `0` through `15`, where `15`
is loud. Its two panning arguments are attenuation values with the opposite
direction: `0` is loud and `15` is silent. Treating both APIs the same reduced
normal centered effects by about 60 dB. The WSS driver has separate conversions
for the two calling conventions.

## OPL2 playback on the YMF701 OPL3 synthesizer

Wolfenstein 3D still contains its OPL2 register sequencer and IMF music data.
Its low-level writer sends those register/value pairs to Sound
Blaster-compatible ports `28D2h` and `29D2h`, which do not control the Cu10's
onboard FM block.

The replacement AdLib detector follows the CanBe Sound 2 and PC-9801-118
extended-FM initialization sequence. It requests Sound ID `83h`, sets the
routing controls at `0F4Ah/0F4Bh` and `148Ah/148Bh`, and performs the standard
OPL timer test through `1488h/1489h`. The target Cu10 later reports `80h` to
SIC, so the diagnostic value is not used as proof that the mode stayed active.
The audible output and OPL timer response are the useful checks. This sequence
comes from the [Laboratory for PC-9821 reference implementation](https://darudarudan.github.io/pc9821/pc9821.html).

Wolfenstein 3D uses the YM3812 or OPL2 register format. OPL2 provides nine
two-operator melodic channels, or six melodic channels plus five percussion
voices in rhythm mode. The YMF701, also called OPL3-SA, integrates an OPL3
synthesizer with two register banks. OPL3 provides 18 two-operator melodic
channels, or 15 melodic channels plus five percussion voices in rhythm mode.
The latter is the Cu10's advertised 20-voice FM configuration. This patch uses
only bank 0 and the original OPL2 channel layout.

The Cu10 handoff enables OPL3 mode. Wolfenstein 3D's OPL2 data writes only the
feedback and connection bits in channel registers `C0h` through `C8h`; its
upper nibble is zero. On OPL3 hardware that also clears the left and right
output enables, which can mute complete melodic channels. The writer adds bits
4 and 5 to writes for those nine registers so every game channel reaches both
stereo outputs.
It passes all other values unchanged, preserving the original frequency,
envelope, multiplier, feedback, connection, level, and waveform values.
Address and data writes use the delays required by the Yamaha OPL interface.

## Registered audio replacement

The build disk includes `AUDIOHED.WL6` and `AUDIOT.WL6` extracted from the
owner's GOG v1.4 installer. The GOG and PC-98 headers are byte-for-byte
identical and describe the same 288 chunks. Both audio archives are 320,209
bytes; only music chunks 273 through 276 differ. The installer stages the GOG
pair under temporary names, removes the installed pair, and renames the staged
files. It does not keep backups.

## P3 modifications

The patcher accepts only the known SHA-256 hash. It changes:

- Four P3 size and memory fields
- Eight five-byte entry stubs for the original PCM driver
- Two five-byte entry stubs for OPL detection and register output
- Three timer callback addresses
- The appended driver area beginning at load-image address `7C000h`

The original total memory boundary remains `8B001h`, so the appended driver does
not move the program's initial stack.
