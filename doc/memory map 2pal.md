# Logical Memory map - MMU disabled

| Logical Address   | Physical Address  | Description                       |
| :---:             | :---:             | :---                              |
| 0000 - 7FFF       | 20 0000           | Bottom 32K of RAM                 |
| 8000 - FBFF       | 00 0000           | Bottom 32K of EEPROM              |
| FC00 - FDFF       | ?? ?C00           | External I/O                      |
| FE00 - FE3F       | ?? ?E00           | Internal I/O (Sheila internal)    |
| FE40 - FEFF       | ?? ?E40           | External I/O                      |
| FF00 - FFFF       | 00 FF00           | Bottom 32K of EEPROM              |

TODO: Ask Dave, It looks to me as though the address lines 14..21 remain "MMU'd" during I/O accesses?

DMB:

"address lines" is a slightly ambiguous term here, and you will
get into difficulties if you try to cast things as a flat 22-bit
physical address space.

A0..A15 are always driven by the CPU.

QA14..21 are pulled down to zero when the MMU is disabled. Otherwise
they are always driven by the MMU. QA13 is a special case depending on
the 8K/16K mode.

It's best to think of QA14..19 as being a memory block select, and as
being invalid during I/O accesses (CPU address FC00-FEFF). In reality
they are driven by MMU mapping of the top block, but the memory device
selects are forced to be disabled.

What's the intent with nCSEXT and nCSEXTIO - I'm a bit confused about the selection logic in PAL2

        CSEXT   =  (ENMMU & (!QA21 &  QA20 # IO) & !INTIO)                   & E;

What is the "IO" term doing in there? Should it not be

        CSEXT   =  (ENMMU & (!QA21 &  QA20) & !IO)                           & E;

I'm probably missing something obvious...

DMB:

nCSEXT is a unqualified external access chip select. It's asserted on
all external bus cycles. If there were data bus buffers, this signal
would work as a buffer enable.

nCSEXTIO is asserted only for external bus cycles that result from an
address in the range FC00-FDFF and FE40-FEFF.

Your version of nCSEXT is more like a nCSEXTMEM signal, that's only
valid for memory cycles. This would have been nice to add to the bus
if we had the resources.

BTW, my version does require the MMU to be enabled for external I/O
accesses, which seems wrong. So maybe it should be:

        CSEXT = ((ENMMU & !QA21 & QA20) # (IO & !INTIO)) & E;

BTW, I did wonder if we should move the internal I/O space to the top
of page FE. Then we would have two contiguous regions:
- external I/O: FC00-FEBF
- internal I/O: FEC0-FEFF

# Logical Memory map - 16K MMU mode

MMU byte to physical address mapping is:

PA[21..0] = MMU[7..0] & LA[13:0]


| Logical Address   | Physical Address  | Description                       |
| :---:             | :---:             | :---                              |
| 0000 - 3FFF       | MMU0[0]           |                                   |
| 4000 - 7FFF       | MMU0[1]           |                                   |
| 8000 - BFFF       | MMU0[2]           |                                   |
| C000 - FBFF       | MMU0[3]           |                                   |
| FC00 - FDFF       | ?? ?C00           | External I/O                      |
| FE00 - FE3F       | ?? ?E00           | Internal I/O (Sheila internal)    |
| FE40 - FEFF       | ?? ?E40           | External I/O                      |
| FF00 - FFFF       | MMU0[3]           |                                   |

# Logical Memory map - 8K MMU mode

MMU byte to physical address mapping is:

PA[21..0] = MMU[7..6] & "0" & MMU[4..0] & MMU[5] & LA[12:0]

| Logical Address   | Physical Address  | Description                       |
| :---:             | :---:             | :---                              |
| 0000 - 1FFF       | MMU0[0]           |                                   |
| 2000 - 3FFF       | MMU1[0]           |                                   |
| 4000 - 5FFF       | MMU0[1]           |                                   |
| 6000 - 7FFF       | MMU1[1]           |                                   |
| 8000 - 9FFF       | MMU0[2]           |                                   |
| A000 - BFFF       | MMU1[2]           |                                   |
| C000 - DFFF       | MMU0[3]           |                                   |
| E000 - FBFF       | MMU1[3]           |                                   |
| FC00 - FDFF       | ?? ?C00           | External I/O                      |
| FE00 - FE3F       | ?? ?E00           | Internal I/O (Sheila internal)    |
| FE40 - FEFF       | ?? ?E40           | External I/O                      |
| FF00 - FFFF       | MMU1[3]           |                                   |


## Sheila internal FE00-FE3F

### FE00-FE0F - 68C681 UART



### FE10-FE3F - MMU

Dave?: MMU register are write only?

DMB: Yes they are write only. Making them readable would have required
an 8-bit buffer (between QA14..21 and CPU D0..7) and an extra PAL
output. I think in the CPLD version they are read-write, as this data
path can be provided "for free" within the CPLD.

#### 16K mode

| MMU Register   | Logical bank |
| :---:          | :---         |
| FE10           | 0000 - 3FFF  |
| FE11           | 4000 - 7FFF  |
| FE12           | 8000 - BFFF  |
| FE13           | C000 - FFFF  |

Registers also repeat at FE14-FE1F, FE30-FE3F

Registers at FE20-FE2F are ignored but can be written

#### 8K mode

| MMU Register   | Logical bank |
| :---:          | :---         |
| FE10           | 0000 - 1FFF  |
| FE11           | 4000 - 5FFF  |
| FE12           | 8000 - 9FFF  |
| FE13           | C000 - DFFF  |

These registers also repeat at FE14-FE1F

| MMU Register   | Logical bank |
| :---:          | :---         |
| FE20           | 2000 - 3FFF  |
| FE21           | 6000 - 7FFF  |
| FE22           | A000 - BFFF  |
| FE23           | E000 - FFFF  |

These registers also repeat at FE24-FE2F

In addition writing to the range FE30-FE3F will write both sets of registers at the same time.

Dave?: I think the intention is that this allows selecting a 16K bank but can't see that that would work unless we made the line for QA13 in PLD1 something like

        QA13 = (16KMODE & A13)  # (!16KMODE & QA19 & A13) # (!16KMODE & !QA19 & !A13);

Or am I missing something? (Probably!)

DMB: Ed originally had the idea of allowing both MMUs to be written in
parallel in 8K mode to remap a 16K region. This would allow a BBC MOS
to remap a ROM with a single write, even in 8K mode. However, we later
realised that for it to work different MMU data would need to be
written into the two MMUs, and that was difficult to achieve without
adding extra chips.

You suggestion above is an alternative approach that avoids the needs to
perturb the MMU input data by instead perturbing the MMU output data
(QA13 = QA19 xor A13).

This is quite clever, but I think imposes constraints in 8K mode on
how the blocks are allocated (i.e. they must be allocated in
pairs). Which I think either amounts to a 16K mode, or else halving
the amount of physical memory.

So I think the bottom line here is that this feature (writing to both
MMUs at the same time) is useful at present.


# Physical Memory map i.e. after MMU

| Physical Address  | Descriptions                                          |
| :---:             | :---                                                  |
| 00 0000 - 1F FFFF | Flash ROM, read/write, repeats                        |
| 20 0000 - 3F FFFF | External I/O or RAM                                   |
| 00 0000 - 1F FFFF | RAM, read/write, repeats                              |
| 00 0000 - 1F FFFF | RAM, read only                                        |
