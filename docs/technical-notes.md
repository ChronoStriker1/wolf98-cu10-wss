# Technical notes

## Why the original sound path fails

This Wolf98 executable has a PC-9821 PCM path, but that driver accesses the
PC-9801-86 register block at `A468h` through `A46Ch`. The PC-9821 Cu10 reports
Sound ID `81h` and exposes a WSS-compatible codec at `0F40h`. Changing the sound
ID alone cannot translate those register interfaces.

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
Wolf98 can select. Each wrapper preserves flags, general registers, and segment
registers before calling the WSS poll routine.

## Volume and panning

Wolf98's master-volume argument runs from `0` through `15`, where `15` is loud.
Its two panning arguments are attenuation values with the opposite direction:
`0` is loud and `15` is silent. Treating both APIs the same reduced normal
centered effects by about 60 dB. The WSS driver has separate conversions for
the two calling conventions.

## Native OPL FM output

Wolf98 still contains its OPL2 register sequencer and IMF music data. Its
low-level writer sends those register/value pairs to Sound Blaster-compatible
ports `28D2h` and `29D2h`, which do not control the Cu10's onboard FM block.

The replacement AdLib detector follows the CanBe Sound 2 and PC-9801-118
extended-FM initialization sequence. It changes Sound ID `81h` to `83h`, sets
the routing controls at `0F4Ah/0F4Bh` and `148Ah/148Bh`, and performs the
standard OPL timer test through `1488h/1489h`. This sequence comes from the
[Laboratory for PC-9821 reference implementation](https://darudarudan.github.io/pc9821/pc9821.html).

The replacement writer passes every OPL2 register and value to `1488h/1489h`
without translation. Wolf therefore keeps all nine melodic channels and its
original frequency, envelope, multiplier, feedback, connection, level, and
waveform values. Address and data writes use the delays required by the Yamaha
OPL interface.

## P3 modifications

The patcher accepts only the known SHA-256 hash. It changes:

- Four P3 size and memory fields
- Eight five-byte entry stubs for the original PCM driver
- Two five-byte entry stubs for OPL detection and register output
- Three timer callback addresses
- The appended driver area beginning at load-image address `7C000h`

The original total memory boundary remains `8B001h`, so the appended driver does
not move the program's initial stack.
