Wolfenstein 3D PC-9821 Cu10 WSS and FM sound patch

This disk patches the PC-98 Wolfenstein 3D executable WOLF98.EXE.
It uses WSS for digitized effects. The game's original OPL2 music and
AdLib sound effects use the OPL3 synthesizer in the Cu10 YMF701 OPL3-SA.
The patch uses OPL3 bank 0 in its OPL2-compatible layout. It does not
convert the music to OPL3 bank 1 or four-operator instruments.
It also replaces AUDIOHED.WL6 and AUDIOT.WL6 with the matching
registered files extracted from the owner's GOG release.

Install:
  C:\PATCH

PATCH also joins VSWAP.00 plus VSWAP.01 into VSWAP.WL6 and joins
98GRA.00 plus 98GRA.01 into 98GRAPH.WL6. The split pieces are removed
after each joined file is copied successfully.

The registered audio pair is staged under temporary names before the
installed pair is replaced. No backup audio files are retained.

After starting Wolfenstein 3D, open the in-game Sound menu. Select Sound
Blaster under SOUND EFFECTS and MUSIC. Keep PC-9821 PCM selected under
DIGITIZED SOUND.
