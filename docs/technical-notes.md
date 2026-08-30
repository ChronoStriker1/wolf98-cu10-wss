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

The NEC/Yamaha Windows driver contains a YMF701 OPL3 handoff, but that routine
depends on controller and mixer state established elsewhere in the driver.
Transplanting the handoff by itself selected Sound ID `82h` and silenced both
WSS and FM on the test Cu10. That regression has been removed.

The current build restores the last DOS compatibility handoff that produced
working WSS effects and partial FM. It still uses `1488h/1489h`, performs the
standard OPL timer test, and is explicitly a fallback rather than a claim of a
complete native YMF701 initialization. Further register work must pass a
standalone hardware test before it is placed in the game executable.

Wolfenstein 3D uses the YM3812 or OPL2 register format. OPL2 provides nine
two-operator melodic channels, or six melodic channels plus five percussion
voices in rhythm mode. The YMF701 OPL3-SA1 integrates an OPL3
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
Every music and AdLib-effect call site in this executable reaches the single
writer hooked at load address `2E4A3h`: the audit found 37 direct calls and no
second OPL output routine. The replacement preserves the original writer's six
address-delay reads and 42 data-delay reads instead of the earlier shortened
35-read delay.

## Game data isolation

The GOG-audio substitution was an unsuccessful diagnostic and has been removed.
The patch disk replaces only `WOLF98.EXE`; it does not carry or modify either
audio archive or other game data. This isolates hardware-driver testing from
data-file changes. The installer removes only `.NEW` remnants from the earlier
failed staging attempt and does not keep an executable backup.

NEC DOS internal commands do not provide a dependable success `ERRORLEVEL` for
this installer. The installer therefore checks only that the destination file
exists. It deliberately avoids rereading large files through the slow PC-98
floppy path. The build still replaces the canonical `CU10-DRV.FDI` atomically
after validating the image on the Mac.

## P3 modifications

The patcher accepts only the known SHA-256 hash. It changes:

- Four P3 size and memory fields
- Eight five-byte entry stubs for the original PCM driver
- Two five-byte entry stubs for OPL detection and register output
- Three timer callback addresses
- The appended driver area beginning at load-image address `7C000h`

The original total memory boundary remains `8B001h`, so the appended driver does
not move the program's initial stack.

## Hardware references

- [Yamaha YMF701 OPL3-SA1 product documentation](https://bitsavers.org/components/yamaha/YMF701_199510.pdf)
  identifies the integrated YMF262-compatible OPL3 synthesizer, codec, and
  mixer architecture.
- [Linux's YMF701B OPL3-SA1 driver](https://github.com/torvalds/linux/blob/v2.6.16/sound/oss/opl3sa.c)
  independently documents the password-protected controller and OPL3 synth
  enable bit.
- The [NEC/Yamaha PC-9821 ValueStar Windows 95 driver archive](https://lainnet.arcesia.net/repo/WIN95_V200.zip)
  contains a PC-98-specific `A460h`, `0F4Ah/0F4Bh`, and `1488h` through
  `148Bh` handoff. It is retained as a reference but is not transplanted without
  the controller and mixer setup that surrounds it.
