//`define use_alternative_clkgen

module mmu_int
  (
   // CPU
   input        E,
   input [15:0] ADDR,
   input        BA,
   input        BS,
   input        RnW,
   input        nRESET,
   input [7:0]  DATA_in,
   output [7:0] DATA_out,
   output       DATA_oe,

   // MMU RAM
   output [7:0] MMU_ADDR,
   output       MMU_nRD,
   output       MMU_nWR,
   input [7:0]  MMU_DATA_in,
   output [7:0] MMU_DATA_out,
   output       MMU_DATA_oe,

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

   // External Bus Control
   output       BUFDIR,
   output       nBUFEN,

   // Clock Generator (for the E Parts)
   input        CLKX4,
   input        MRDY,
   output reg   QX,
   output reg   EX
   );

   parameter IO_ADDR_MIN  = 16'hFC00;
   parameter IO_ADDR_MAX  = 16'hFEFF;

   parameter UART_BASE    = 16'hFE00; // 16 bytes
   parameter MMU_BASE     = 16'hFE10; // 16 bytes (8 bytes of regs, 8 bytes of ram)

   // Internal Registers
   reg            enmmu;
   reg            mode8k;
   reg            protect;
   reg [4:0]      access_key;
   reg [4:0]      task_key;
   reg            U;

   wire [7:0]     DATA = DATA_in;
   wire [7:0]     MMU_DATA = MMU_DATA_in;

   // Is the hardware accessible to the current task?
   (* xkeep *) wire hw_en = !enmmu | !U | !protect;

   (* xkeep *) wire io_access      = hw_en && ADDR >= IO_ADDR_MIN && ADDR <= IO_ADDR_MAX;
   (* xkeep *) wire uart_access    = hw_en && {ADDR[15:4], 4'b0000} == UART_BASE;
   (* xkeep *) wire mmu_access     = hw_en && {ADDR[15:4], 4'b0000} == MMU_BASE;
   (* xkeep *) wire mmu_reg_access = mmu_access & !ADDR[3];
   (* xkeep *) wire mmu_ram_access = mmu_access &  ADDR[3];
   (* xkeep *) wire io_access_ext  = io_access & !mmu_access & !uart_access;

   wire access_vector = (!BA & BS & RnW);

   always @(negedge E, negedge nRESET) begin
      if (!nRESET) begin
         {protect, mode8k, enmmu} <= 3'b0;
         access_key <= 5'b0;
         task_key <= 5'b0;
         U <= 1'b0;
      end else begin
         if (!RnW && mmu_reg_access && ADDR[2:0] == 3'b000) begin
            {protect, mode8k, enmmu} <= DATA[2:0];
         end
         if (!RnW && mmu_reg_access && ADDR[2:0] == 3'b001) begin
            access_key <= DATA[4:0];
         end
         if (!RnW && mmu_reg_access && ADDR[2:0] == 3'b010) begin
            task_key <= DATA[4:0];
         end
         if (access_vector) begin
            //DB: switch task automatically when vector fetch
            U <= 1'b0;
         end else if (RnW && mmu_reg_access && ADDR[2:0] == 3'b011) begin
            //DB: switch task automatically when access RTI
            U <= 1'b1;
         end
      end
   end

   reg [7:0] data_tmp;

   always @(*) begin
      if (ADDR[3])
        data_tmp = MMU_DATA;
      else
        case (ADDR[2:0])
          3'b000 : data_tmp = {4'b0, !U, protect, mode8k, enmmu};
          3'b001 : data_tmp = {3'b0, access_key};
          3'b010 : data_tmp = {3'b0, task_key};
          3'b011 : data_tmp = {8'h3b};
        default:
          data_tmp = 8'h00;
      endcase
   end

   assign DATA_out = data_tmp;

   assign DATA_oe = E & RnW & mmu_access;

   //DB: mask out bottom part ADDR when in 16k mode
   assign MMU_ADDR[2:0] = mmu_ram_access ? ADDR[2:0] : { ADDR[15:14], ADDR[13] & mode8k };

   // Note: ORing works because the two conditions are mutually exclusive, which
   // they are if MMU access is only allowed when U=0.
   assign MMU_ADDR[7:3] = access_key & {5{mmu_ram_access}} | task_key & {5{(!access_vector & U)}};

   // TODO: There is a good changce this expression is wrong
   assign MMU_nRD  = !(E &  RnW & mmu_ram_access | enmmu & !io_access);

   //DB: I add an extra gating signal here, this might not work for a non-E part?
   assign MMU_nWR  = !(E & !RnW & mmu_ram_access);

   assign MMU_DATA_out = (mmu_ram_access & !RnW) ? DATA : {5'b00000, ADDR[15:13]};

   assign MMU_DATA_oe  = (mmu_ram_access & !RnW & E) | !enmmu;

   assign QA13 = mode8k ? MMU_DATA[5] : ADDR[13];

   always @(posedge CLKX4) begin
      // Q leads E, stop in state QX=0 EX=1
`ifdef use_alternative_clkgen
      // This uses 3 product terms
      QX <= !EX;
      EX <= (EX & !MRDY) | QX;
`else
      // This uses 8 product terms, because it triggers inefficient use of clock enable
      case ({QX, EX})
        2'b00: QX <= 1'b1;
        2'b10: EX <= 1'b1;
        2'b11: QX <= 1'b0;
        2'b01: if (MRDY) EX <= 0;
        default: begin
           QX <= 1'b0;
           EX <= 1'b0;
        end
      endcase
`endif
   end

   assign A11X = ADDR[11] ^ access_vector;
   assign nRD = !(E & RnW);
   assign nWR = !(E & !RnW);
   assign nCSUART  = !(E & uart_access);

   assign nCSROM0  = !(((enmmu & MMU_DATA[7:6] == 2'b00) | (!enmmu &  ADDR[15])) & !io_access);
   assign nCSROM1  = !(  enmmu & MMU_DATA[7:6] == 2'b01                          & !io_access);
   assign nCSRAM   = !(((enmmu & MMU_DATA[7:6] == 2'b10) | (!enmmu & !ADDR[15])) & !io_access);
   assign nCSEXT   = !(  enmmu & MMU_DATA[7:6] == 2'b11                          & !io_access);
   assign nCSEXTIO = !(io_access_ext);

   assign nBUFEN   = BA ^ !(!nCSEXT | !nCSEXTIO);
   assign BUFDIR   = BA ^ RnW;

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
//PIN: EX         : 8
//PIN: E          : 2
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
