# ESP Ra. De. (international ver) Free Play patch
2018 Michael Moffitt
mikejmoffitt@gmail.com

This patch adds a Free Play option to the game's configuration screen,
replacing the 3 coins / 1 play option that is rarely used in a home or
presentation environment.

A forced-reset feature is also added, where holding both start buttons
for three seconds resets the game, allowing a player to start fresh.

Presently only the international version of the game has been patched.
Support for either Japanese release can be done, it would just require
a little more work.

Place dumps of the original international version's U41 and U42 ROMs
in the same directory, and assemble with Macro Assembler. Burn the
resulting u41.bin and u42.bin files in the out/ directory to a pair of
27C040 EPROM / 29F040 FLASH chips and install on the PCB.
