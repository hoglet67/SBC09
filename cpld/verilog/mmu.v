//`define use_alternative_clkgen

module mmu
  (
   // CPU
   input [15:0] ADDR,
   input        BA,
   input        BS,
   input        RnW,
   input        nRESET,
   inout [7:0]  DATA,

   // MMU RAM
   output [4:0] MMU_ADDR,
   output       MMU_nRD,
   output       MMU_nWR,
   inout [7:0]  MMU_DATA,

   // Memory / Device Selects
   output       A11X,
   output       QA13,
   output       nRW,
   output       nCSEXT,
   output       nCSEXTIO,
   output       nCSROM0,
   output       nCSROM1,
   output       nCSRAM,
   output       nCSUART,
   output       INTMASK,

   // SD Card
   output       SCLK,
   output       MOSI,
   input        MISO,

   // External Bus Control
   output       BUFDIR,
   output       nBUFEN,

   // Clock Generator (for the E Parts)
   input        CLKX4,
   input        MRDY,
   input        nENCLK,
   inout        QX,
   inout        EX
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
   wire [7:0]  MMU_ADDR_int;

   (* keep *) wire ENCLK = !nENCLK;

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
      .E(EX),
      .Q(QX),
      .ADDR(ADDR),
      .BA(BA),
      .BS(BS),
      .RnW(RnW),
      .nRESET(nRESET),
      .DATA_in(DATA),
      .DATA_out(DATA_out),
      .DATA_oe(DATA_oe),
      // MMU RAM
      .MMU_ADDR(MMU_ADDR_int),
      .MMU_nRD(MMU_nRD),
      .MMU_nWR(MMU_nWR),
      .MMU_DATA_in(MMU_DATA),
      .MMU_DATA_out(MMU_DATA_out),
      .MMU_DATA_oe(MMU_DATA_oe),
      // Memory / Device Selects
      .A11X(A11X),
      .QA13(QA13),
      .nRW(nRW),
      .nCSEXT(nCSEXT),
      .nCSEXTIO(nCSEXTIO),
      .nCSROM0(nCSROM0),
      .nCSROM1(nCSROM1),
      .nCSRAM(nCSRAM),
      .nCSUART(nCSUART),
      .INTMASK(INTMASK),
      // SD Card
      .SCLK(SCLK),
      .MISO(MISO),
      .MOSI(MOSI),
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
   assign MMU_ADDR = MMU_ADDR_int[4:0];

endmodule

// Pin assignment for the experimental Yosys FLoow
//
//PIN: CHIP "mmu" ASSIGNED TO AN PLCC84
//PIN: A11X       : 50
//PIN: ADDR_0     : 17
//PIN: ADDR_1     : 18
//PIN: ADDR_2     : 20
//PIN: ADDR_3     : 21
//PIN: ADDR_4     : 22
//PIN: ADDR_5     : 24
//PIN: ADDR_6     : 25
//PIN: ADDR_7     : 27
//PIN: ADDR_8     : 28
//PIN: ADDR_9     : 29
//PIN: ADDR_10    : 30
//PIN: ADDR_11    : 31
//PIN: ADDR_12    : 33
//PIN: ADDR_13    : 34
//PIN: ADDR_14    : 35
//PIN: ADDR_15    : 36
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
//PIN: EX         : 81
//XXX: SPARE      : 2
//PIN: nENCLK     : 6
//PIN: INTMASK    : 52
//PIN: MMU_ADDR_0 : 65
//PIN: MMU_ADDR_1 : 64
//PIN: MMU_ADDR_2 : 67
//PIN: MMU_ADDR_3 : 68
//PIN: MMU_ADDR_4 : 70
//xxx: MMU_ADDR_5 : 73
//xxx: MMU_ADDR_6 : 76
//xxx: MMU_ADDR_7 : 74
//PIN: SCLK       : 73
//PIN: MOSI       : 76
//PIN: MISO       : 74
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
//PIN: QA13       : 51
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
//PIN: nCSROM0    : 8
//PIN: nCSROM1    : 79
//PIN: nCSUART    : 77
//PIN: nRW        : 49
