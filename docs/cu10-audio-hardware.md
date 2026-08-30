# PC-9821 Cu10 audio hardware

The PC-9821 Cu10 is not a PC-9801-86 PCM machine, and a YMF701 alone cannot
provide every sound function in NEC's specification. SIC 2.03 identifies the
standard FM device in the tested Cu10 as a YMF288 at `0188h`. The machine also
has a separate WSS and extended-OPL3 function consistent with the YMF701.

## Confirmed machine functions

NEC's Cu10 specification lists:

- Stereo 8-bit and 16-bit PCM recording and playback at 11.025, 22.05, and
  44.1 kHz.
- Standard FM with six FM voices, six rhythm voices, and three SSG voices.
- Extended FM with up to 20 voices.

Yamaha documents the YMF701 as an OPL3, WSS/Sound Blaster-compatible codec,
MIDI, joystick, and mixer controller. It has no OPN or SSG register block.
Therefore the YMF288 supplies the standard OPN-compatible FM, rhythm, and SSG
functions while the YMF701-class side supplies WSS PCM and extended OPL3.

The following values were read on the target Cu10 with SIC 2.03 `/I`:

- Standard FM: YMF288 at `0188h`, OPN-compatible mode, IRQ12.
- MATE-X WSS: base `0F40h`, WSS ID `05h`, Sound ID `80h`, IRQ12.
- WSS codec identification: version `04h`, ID `00h`, revision `0Ah`.
- CanBe/118 FM mixer: left `32`, right `32`, the maximum SIC reports.
- DMA: not selected while SIC inspected the idle machine. The WSS driver
  selects DMA channel 1 with configuration `22h` during playback.

| Function | Confirmed interface | Chip attribution |
| --- | --- | --- |
| Standard 86-compatible FM, SSG, and rhythm | OPN-compatible ports at `0188h` | YMF288 |
| Extended OPL3 FM | `1488h` through `148Bh` | YMF701-class controller |
| Digital PCM | WSS-compatible codec at `0F40h` through `0F47h` | YMF701-class controller |
| Genuine PC-9801-86 PCM | Not present | None |

The old game driver contained a YMF297-derived CanBe/118 mode switch. The
standalone diagnostic proved that path silent. A targeted Cu10 test then found
that the OPL timer responds with Sound ID `82h` and Yamaha board register `20h`
set to `00h`. The current driver uses that tested setup.

## Why PCM can work while FM stays silent

The Cu10 has two mixer stages in the FM output path.

The CanBe/ValueStar mixer uses index `30h` for FM left and `31h` for FM right.
Bit 7 mutes the selected channel, and bits 0 through 4 set attenuation. Its
output reaches the WSS codec through the synth input.

The WSS/AD1848-compatible codec uses indirect registers `4` and `5` for left
and right AUX2. Yamaha's YMF701 Linux driver maps AD1848 LINE2/AUX2 to the
internal synth. The target Cu10 reported both registers as `88h`, with the mute
bit set. The driver clears that bit and preserves the existing attenuation.

## Programming references

- [NEC PC-9821Cu10 product specification](https://support.nec-lavie.jp/support/product/data/spec/cpu/96060001-1.html)
- [Yamaha YMF701 product documentation](https://bitsavers.org/components/yamaha/YMF701_199510.pdf)
- [Linux YMF701B OPL3-SA driver](https://android.googlesource.com/kernel/msm/+/1da177e4c3f41524e886b7f1b8a0c1fc7321cac2/sound/oss/opl3sa.c)
- [Yamaha YMF289B programming documentation](https://www.bitsavers.org/components/yamaha/YMF289B_199412.pdf)
- [Analog Devices AD1848 codec documentation](https://www.analog.com/media/en/technical-documentation/obsolete-data-sheets/1692269ad1848k.pdf)
- [PC-9821 multimedia I/O and CanBe mixer notes](https://www2t.biglobe.ne.jp/~take52/tech/soft.htm)
- [SIC 2.03 hardware inspection utility and documentation](https://www2t.biglobe.ne.jp/~take52/file/sic203.htm)
- [PC-98 OPL3 and WSS sample source](https://darudarudan.github.io/pc9821/pc9821.html)
- [YMF297 mode-switch measurements](https://pcm1723.hateblo.jp/entry/20140803/1407074615)
- [YMF288 plus YMF701 model list](https://w.atwiki.jp/touhousoundfont/pages/18.html)
- [Conflicting YMF297 plus YMF701 model list](https://mimizun.com/log/2ch/pc/1048212888/)

No public YMF297 programming manual was found during this review. The old
YMF297 mode switch remains useful only as a negative diagnostic comparison.
