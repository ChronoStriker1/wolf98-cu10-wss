# Technical notes

## Why the original sound path fails

The PC-98 Wolfenstein 3D executable, `WOLF98.EXE`, has a PC-9821 PCM path, but
that driver accesses the PC-9801-86 register block at `A468h` through `A46Ch`.
The target PC-9821 Cu10 reports Sound ID `80h` and exposes a WSS-compatible
codec at `0F40h`. Changing the sound ID alone cannot translate those register
interfaces.

The Cu10's sound functions are split across a YMF288 at `0188h` for
OPN-compatible FM and separate WSS/OPL3 hardware. SIC 2.03 identified the
YMF288 directly on the target machine and reported WSS base `0F40h`, ID `05h`,
and IRQ12. See [Cu10 audio hardware](cu10-audio-hardware.md) for the complete
evidence.

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

Wolf98 keeps one digitized voice and divides longer sounds into 4 KiB segments.
An accepted new effect stops the active voice before starting its first
segment. Mixing only the current DMA segment was tested and removed because it
introduced restart pops and discarded the later segments of interrupted guard
voices. Proper overlap would need to manage complete sounds above Wolf98's
segment loader.

## Volume and panning

Wolfenstein 3D's master-volume argument runs from `0` through `15`, where `15`
is loud. Its two panning arguments are attenuation values with the opposite
direction: `0` is loud and `15` is silent. Treating both APIs the same reduced
normal centered effects by about 60 dB. The WSS driver has separate conversions
for the two calling conventions.

FM has a separate two-stage output path. The CanBe mixer controls FM left and
right at indices `30h` and `31h`. The YMF701 synth then reaches the codec
through AUX2. WSS indirect registers `4` and `5` were `88h` on the target Cu10,
so both channels were muted. The driver clears bit 7 at both stages while
preserving their attenuation settings. This is why WSS effects could work while
music remained silent.

The FM initializer owns the AUX2 unmute. The PCM initializer does not save or
restore registers `4` and `5`. Otherwise, changing `DIGITIZED SOUND` to `Off`
would shut down PCM, restore the old AUX2 mute bits, and silence music that
Wolf98 leaves running.

## OPL2 playback through the extended-FM mode

Wolfenstein 3D still contains its OPL2 register sequencer and IMF music data.
Its low-level writer sends those register/value pairs to Sound
Blaster-compatible ports `28D2h` and `29D2h`, which do not control the Cu10's
onboard FM block.

The old build used a YMF297-derived handoff for CanBe Sound 2 and
PC-9801-118-style hardware. The standalone test showed that route silent on the
target Cu10. The OPL timer responds when Sound ID is `82h` and Yamaha board
register `20h` is `00h`, so the current game driver uses those tested values.

An earlier build rejected this interface unless its status port reproduced the
discrete YM3812 timer signature. On the Cu10 that result disabled the AdLib
writer completely, which removed both music and synthesized sound effects while
WSS digitized effects continued to work. The Cu10-specific build no longer uses
that generic detection result to suppress later FM writes.

Wolfenstein 3D uses the YM3812 or OPL2 register format. OPL2 provides nine
two-operator melodic channels, or six melodic channels plus five percussion
voices in rhythm mode. OPL3 has two register banks and provides 18
two-operator melodic channels, or 15 melodic channels plus five percussion
voices in rhythm mode.
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

- [NEC's Cu10 specification](https://support.nec-lavie.jp/support/product/data/spec/cpu/96060001-1.html)
  lists WSS-class PCM, standard FM with SSG, and extended 20-voice FM.
- [Yamaha YMF701 product documentation](https://bitsavers.org/components/yamaha/YMF701_199510.pdf)
  identifies its OPL3, WSS codec, MIDI, joystick, and mixer functions. It does
  not contain the Cu10's standard OPN/SSG function.
- [PC-98 multimedia I/O and mixer notes](https://www2t.biglobe.ne.jp/~take52/tech/soft.htm)
  document the CanBe FM mixer channels.
- [SIC 2.03](https://www2t.biglobe.ne.jp/~take52/file/sic203.htm) identified the
  target Cu10's YMF288, WSS resources, codec revision, and mixer levels.
- [PC-98 OPL3 sample source](https://darudarudan.github.io/pc9821/pc9821.html)
  provides the YMF297 CanBe/118 mode switch used for the negative comparison.
- [Analog Devices AD1848 documentation](https://www.analog.com/media/en/technical-documentation/obsolete-data-sheets/1692269ad1848k.pdf)
  documents WSS AUX2 registers `4` and `5` and their mute bit.
- [Linux's YMF701B OPL3-SA driver](https://android.googlesource.com/kernel/msm/+/1da177e4c3f41524e886b7f1b8a0c1fc7321cac2/sound/oss/opl3sa.c)
  maps the codec's second auxiliary input to the internal synth.
