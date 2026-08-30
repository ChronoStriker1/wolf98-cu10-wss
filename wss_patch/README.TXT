Wolfenstein 3D PC-9821 Cu10 WSS and FM sound patch

This disk patches the PC-98 Wolfenstein 3D executable WOLF98.EXE.
It uses the Cu10 WSS codec for digitized effects. The game's original
OPL2 music and AdLib sound effects use the extended-FM interface. The
driver unmutes both CanBe FM mixer channels and WSS AUX2.
The patch uses OPL3 bank 0 in its OPL2-compatible layout. It does not
convert the music to OPL3 bank 1 or four-operator instruments.
It replaces only WOLF98.EXE. Audio and game data files are not changed.

Install:
  C:\PATCH

PATCH removes any AUDIOHED.NEW or AUDIOT.NEW files left by an earlier failed
staging attempt. No backup files are retained. To avoid another long floppy
read, PATCH checks only that the installed executable exists.

After starting Wolfenstein 3D, open the in-game Sound menu. Select Sound
Blaster under SOUND EFFECTS and MUSIC. Keep PC-9821 PCM selected under
DIGITIZED SOUND.
