PC-9821 Cu10 FM and WSS hardware tests

From this Gotek image, run:

  C:\TEST

YMF_TST.COM runs one OPL tone using the control values proven by the last test.
It unmutes the codec AUX2 input used by the Yamaha synth. Answer Y only if you
hear the tone. It writes the register, timer, and answer results to
YMFRESUL.TXT, then restores every changed value.

INFO_TST.COM writes CU10INFO.TXT into this floppy image. It records the active
sound resources, the PC-98 multimedia PnP address table, the NEC/Yamaha board
registers at 548Eh/548Fh, and the direct and PC-98-indirect OPL3-SA controller
paths. It restores the PnP selector before exiting and does not change resource
addresses or Yamaha register data.

After YMFRESUL.TXT is saved, return the USB drive to the Mac. The result can
be read directly from CU10-TST.FDI, so a photograph is not required.

FM_TST.COM remains available if another audible FM test is needed. It attempts
six labeled tones through the standard OPN interface and five extended-FM
configurations. Press Y only for tones you hear.

WSS_TST.COM remains available as a separate test of WSS DMA playback. Run it
by entering WSS_TST at the DOS prompt.
