MF UFFA Unpacker/Packer
=======================
Program to unpack and repack archive files used in PS2 version of "Fate/stay night [Realta Nua]" game.

Usage:
  mf_pack.exe ＜input file or folder＞ [output file or folder]

Game text stored in DATA2/15.mf and font is in DATA2/14.mf

ANSI character limit fix:
  in SLPM_665.13 at offsets 0x36970 and 0x4A700 change '1C' to '2C'
  and for choices at 0xBAF6C change '1E' to '28', at 0xBAFBC change '18' to '25',
  at 0xBB0C8 change '1E' to '28' and at 0xBB5C4 change '1E' to '28'
  
https://i.imgur.com/dy6i0ak.png
https://i.imgur.com/xBu7dcz.png

//RikuKH3
