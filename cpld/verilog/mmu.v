//`define use_alternative_clkgen

module mmu
  (
   // CPU
   input        E,
   input        ADDR0,
   input        ADDR1,
   input        ADDR2,
   input        ADDR4,
   input        ADDR5,
   input        ADDR6,
   input        ADDR7,
   input        ADDR8,
   input        ADDR9,
   input        ADDR10,
   input        ADDR11,
   input        ADDR12,
   input        ADDR13,
   input        ADDR14,
   input        ADDR15,
   input        BA,
   input        BS,
   input        RnW,
   input        nRESET,
   inout [7:0]  DATA,

   // MMU RAM
   output [7:0] MMU_ADDR,
   output       MMU_nRD,
   output       MMU_nWR,
   inout [7:0]  MMU_DATA,

   // Memory / Device Selects
   output       A11X,
   output       QA13,
   output       nRD,
   output       nWR,
   output       nCSEXT,
   output       nCSEXTIO,
   output       nCSROM0,
   output       nCSROM1,
   output       nCSRAM,
   output       nCSUART,
   output       INTMASK,

   // External Bus Control
   output       BUFDIR,
   output       nBUFEN,

   // Clock Generator (for the E Parts)
   input        CLKX4,
   input        MRDY,
   input        nENCLK,
   output       QX,
   output       EX
   );

   parameter IO_ADDR_MIN  = 16'hFC00;
   parameter IO_ADDR_MAX  = 16'hFEFF;
   parameter UART_BASE    = 16'hFE00;
   parameter MMU_BASE     = 16'hFE20;

   wire [7:0]  DATA_out;
   wire        DATA_oe;
   wire [7:0]  MMU_DATA_out;
   wire        MMU_DATA_oe;
   wire        EX_int;
   wire        QX_int;

   (* keep *) wire ENCLK = !nENCLK;

   wire [15:0] ADDR = {ADDR15, ADDR14, ADDR13, ADDR12,
                       ADDR11, ADDR10,  ADDR9,  ADDR8,
                        ADDR7,  ADDR6,  ADDR5,  ADDR4,
                         1'b0,  ADDR2,  ADDR1,  ADDR0};

   mmu_int
     #(
       .IO_ADDR_MIN(IO_ADDR_MIN),
       .IO_ADDR_MAX(IO_ADDR_MAX),
       .UART_BASE(UART_BASE),
       .MMU_BASE(UART_BASE)
       )
   e_mmu_int
     (
      // CPU
      .E(E),
      .ADDR(ADDR),
      .BA(BA),
      .BS(BS),
      .RnW(RnW),
      .nRESET(nRESET),
      .DATA_in(DATA),
      .DATA_out(DATA_out),
      .DATA_oe(DATA_oe),
      // MMU RAM
      .MMU_ADDR(MMU_ADDR),
      .MMU_nRD(MMU_nRD),
      .MMU_nWR(MMU_nWR),
      .MMU_DATA_in(MMU_DATA),
      .MMU_DATA_out(MMU_DATA_out),
      .MMU_DATA_oe(MMU_DATA_oe),
      // Memory / Device Selects
      .A11X(A11X),
      .QA13(QA13),
      .nRD(nRD),
      .nWR(nWR),
      .nCSEXT(nCSEXT),
      .nCSEXTIO(nCSEXTIO),
      .nCSROM0(nCSROM0),
      .nCSROM1(nCSROM1),
      .nCSRAM(nCSRAM),
      .nCSUART(nCSUART),
      .INTMASK(INTMASK),
      // External Bus Control
      .BUFDIR(BUFDIR),
      .nBUFEN(nBUFEN),
      // Clock Generator (for the E Parts)
      .CLKX4(CLKX4),
      .MRDY(MRDY),
      .QX(QX_int),
      .EX(EX_int)
      );

   assign DATA = DATA_oe ? DATA_out : 8'hZZ;
   assign MMU_DATA = MMU_DATA_oe ? MMU_DATA_out : 8'hZZ;
   assign EX = ENCLK ? EX_int : 1'bZ;
   assign QX = ENCLK ? QX_int : 1'bZ;

endmodule

// Pin assignment for the experimental Yosys FLoow
//
//PIN: CHIP "mmu" ASSIGNED TO AN PLCC84
//PIN: A11X       : 50
//PIN: ADDR0      : 17
//PIN: ADDR1      : 18
//PIN: ADDR2      : 20
//PIN: ADDR4      : 22
//PIN: ADDR5      : 24
//PIN: ADDR6      : 25
//PIN: ADDR7      : 27
//PIN: ADDR8      : 28
//PIN: ADDR9      : 29
//PIN: ADDR10     : 30
//PIN: ADDR11     : 31
//PIN: ADDR12     : 33
//PIN: ADDR13     : 34
//PIN: ADDR14     : 35
//PIN: ADDR15     : 36
//PIN: BA         : 15
//PIN: BS         : 12
//PIN: BUFDIR     : 9
//PIN: CLKX4      : 83
//PIN: DATA_0     : 37
//PIN: DATA_1     : 39
//PIN: DATA_2     : 40
//PIN: DATA_3     : 41
//PIN: DATA_4     : 44
//PIN: DATA_5     : 45
//PIN: DATA_6     : 46
//PIN: DATA_7     : 48
//PIN: EX         : 8
//PIN: E          : 2
//PIN: nENCLK     : 6
//PIN: INTMASK    : 21
//PIN: MMU_ADDR_0 : 65
//PIN: MMU_ADDR_1 : 64
//PIN: MMU_ADDR_2 : 67
//PIN: MMU_ADDR_3 : 68
//PIN: MMU_ADDR_4 : 70
//PIN: MMU_ADDR_5 : 73
//PIN: MMU_ADDR_6 : 76
//PIN: MMU_ADDR_7 : 74
//PIN: MMU_DATA_0 : 60
//PIN: MMU_DATA_1 : 58
//PIN: MMU_DATA_2 : 57
//PIN: MMU_DATA_3 : 55
//PIN: MMU_DATA_4 : 54
//PIN: MMU_DATA_5 : 56
//PIN: MMU_DATA_6 : 61
//PIN: MMU_DATA_7 : 63
//PIN: MMU_nRD    : 69
//PIN: MMU_nWR    : 75
//PIN: MRDY       : 84
//PIN: QA13       : 52
//PIN: QX         : 5
//PIN: RESET      : 1
//PIN: RnW        : 16
//PIN: TCK        : 62
//PIN: TDI        : 14
//PIN: TDO        : 71
//PIN: TMS        : 23
//PIN: nBUFEN     : 11
//PIN: nCSEXT     : 4
//PIN: nCSEXTIO   : 10
//PIN: nCSRAM     : 80
//PIN: nCSROM0    : 81
//PIN: nCSROM1    : 79
//PIN: nCSUART    : 77
//PIN: nRD        : 49
//PIN: nWR        : 51
