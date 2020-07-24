# arcimage
This is a small program to read/write disk images from/to Archimedes disks in a PC's floppy drive.

It can be used in conjunction with Archimedes emulators such as [Archi](http://web.archive.org/web/20000822032250/www.geocities.com/chris-o/), [Red Squirrel](https://web.archive.org/web/20100122170520/http://www.red-squirrel.org/), [arcem](http://arcem.sourceforge.net/), [VirtualA5000](http://www.virtualacorn.co.uk/), [RPCEmu](http://www.marutan.net/rpcemu/index.php), [Riscose](http://riscose.sourceforge.net/) and [Arculator](http://b-em.bbcmicro.com/arculator/)

    Archimedes disk image program for PC
    Version 1.1 - Jasper Renow-Clarke 1997,99
    Syntax :
      ARCIMG diskimage [operation]
    
      Operations :
      /read    - Reads disk into image (Default)
      /write   - Writes disk from image
                 (Disk must be formatted already using real Archimedes)
      /format  - Formats disk (Doesnt Work !!!)


Some examples are:
------------------

-  Read an Archi D/E format floppy into a disk image

  `arcimg c:\test.adf`

-  Write an Archi D/E format floppy from a disk image
    *Note: The floppy must be preformatted on an Arc*

  `arcimg c:\games.adf /write`

The **"/format"** option does not work, I'm not sure why perhaps I've done something silly, or missed something.
If you have any suggestions about how I can fix this then email me, and I'll put it right.

If there are any read errors in creating a file from a disk, then the sectors are displayed in red, otherwise the currently being read sector is displayed, to give you a progress meter. One reason a sector can not be read is that it may be formatted differently for copy protection purposes.

I hope you find this useful, mail me with your comments/suggestions, your feedback is welcomed.

In 2002, Donald Scott wrote a [guide](http://knowbody.org.uk/arcimage/) to using this software.

Also in 2002, Wocki wrote a graphical front-end to arcimg for Windows 95/98/ME called [ArcDisc](http://acorn.revivalteam.de/?site=DiscImaging).

------------------

I take no responsibilty whatsoever for the performance of this software, if it breaks something, then it's not my fault.

You run this software entirely at your own risk.

(c) 1997-2000, Jasper Renow-Clarke


changelog
----------

> v1.1.2  modifications by Tom Humphrey
>>        read & writes 1.6Mb (F format) disks
>>        formats 1.6Mb discs
>>        improved error tollerance on reads
