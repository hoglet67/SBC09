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

These registers also repeat at FE14-FE1F

In addition writing to the range FE30-FE3F will write both sets of registers at the same time.

Dave?: I think the intention is that this allows selecting a 16K bank but can't see that that would work unless we made the line for QA13 in PLD1 something like

        QA13 = (16KMODE & A13)  # (!16KMODE & QA19 & A13) # (!16KMODE & !QA19 & !A13);

Or am I missing something?


# Physical Memory map i.e. after MMU

| Physical Address  | Descriptions                                          |
| :---:             | :---                                                  |
| 00 0000 - 1F FFFF | Flash ROM, read/write, repeats                        |
| 20 0000 - 3F FFFF | External I/O or RAM                                   |
| 00 0000 - 1F FFFF | RAM, read/write, repeats                              |
| 00 0000 - 1F FFFF | RAM, read only                                        |
