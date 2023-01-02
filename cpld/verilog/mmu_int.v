//`define use_alternative_clkgen

module mmu_int
  (
   // CPU
   input        E,
   input        Q,
   input [15:0] ADDR,
   input        BA,
   input        BS,
   input        RnW,
   input        nRESET,
   input [7:0]  DATA_in,
   output       INTMASK,
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
   output       nRW,
   output       nCSEXT,
   output       nCSEXTIO,
   output       nCSROM0,
   output       nCSROM1,
   output       nCSRAM,
   output       nCSUART,

   // SD Card Interface (SCS driven by UART)
   output       SCLK,
   output       MOSI,
   input        MISO,

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
   parameter MMU_BASE     = 16'hFE20; // 32 bytes

   // Internal Registers
   reg            enmmu;
   reg            mode8k;
   reg            protect;
   reg [4:0]      access_key;
   reg [4:0]      task_key;
   reg            U;
   reg [1:0]      mask_count;
   wire [7:0]     DATA = DATA_in;
   wire [7:0]     MMU_DATA = MMU_DATA_in;

   reg [7:0]      sd_data;    // 8-bit shift register for data
   reg [3:0]      sd_count;   // 4-bit counter
   reg            sd_active;  // indicates the SD interface is shifting
   reg            sd_tmp;     // latches the MISO input

   // Is the hardware accessible to the current task?
   (* xkeep *) wire hw_en = !enmmu | !U | !protect;

   (* xkeep *) wire io_access      = hw_en && ADDR >= IO_ADDR_MIN && ADDR <= IO_ADDR_MAX;
   (* xkeep *) wire uart_access    = hw_en && {ADDR[15:4], 4'b0000} == UART_BASE;
   (* xkeep *) wire mmu_access     = hw_en && {ADDR[15:5], 5'b00000} == MMU_BASE;
   (* xkeep *) wire mmu_reg_access = mmu_access & !ADDR[4];
   (* xkeep *) wire mmu_ram_access = mmu_access &  ADDR[4];
   (* xkeep *) wire io_access_ext  = io_access & !mmu_access & !uart_access;

   wire access_vector = (!BA & BS & RnW);

   always @(negedge E, negedge nRESET) begin
      if (!nRESET) begin
         {protect, mode8k, enmmu} <= 3'b0;
         access_key <= 5'b0;
         task_key <= 5'b0;
         U <= 1'b0;
         mask_count <= 2'b00;
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
         if (access_vector) begin
            mask_count <= 2'b11;
         end else if (|mask_count) begin
            mask_count <= mask_count - 1;
         end
      end
   end

   assign INTMASK = access_vector | (|mask_count);

   reg [7:0] data_tmp;

   always @(*) begin
      if (ADDR[4])
        data_tmp = MMU_DATA;
      else
        case (ADDR[2:0])
          3'b000 : data_tmp = {4'b0, !U, protect, mode8k, enmmu};
          3'b001 : data_tmp = {3'b0, access_key};
          3'b010 : data_tmp = {3'b0, task_key};
          3'b011 : data_tmp = {8'h3b};
          3'b100 : data_tmp = sd_data;
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

   assign MMU_DATA_out = (mmu_ram_access & !RnW) ? DATA : {6'b000000, ADDR[15:14]};

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
   assign nRW = !RnW;
   assign nCSUART  = !(E & uart_access);

   assign nCSROM0  = !(E & (((enmmu & MMU_DATA[7:6] == 2'b00) | (!enmmu &  ADDR[15])) & !io_access));
   assign nCSROM1  = !(E & (  enmmu & MMU_DATA[7:6] == 2'b01                          & !io_access));
   assign nCSRAM   = !(E & (((enmmu & MMU_DATA[7:6] == 2'b10) | (!enmmu & !ADDR[15])) & !io_access));
   assign nCSEXT   = !(       enmmu & MMU_DATA[7:6] == 2'b11                          & !io_access);
   assign nCSEXTIO = !(io_access_ext);

   assign nBUFEN   = BA ^ !(!nCSEXT | !nCSEXTIO);
   assign BUFDIR   = BA ^ RnW;


   // SD Card Interface
   //
   // SD Card should operate in SPI Mode 0
   // - positive clock pulse (idle clock is zero)
   // - receiver(s) latch on rising SCLK edge
   // - transmitter(s) shift on falling SCLK edge
   //
   // SCLK MOSI MISO
   //  0    x    x                       (count =  0, active = 0)
   //  0    D7   latch D7 on rising edge (count =  0, active = 1)
   //  1    D7                           (count =  1, active = 1)
   //  0    D6   latch D6 on rising edge (count =  2, active = 1)
   //  1    D6                           (count =  3, active = 1)
   //  0    D5   latch D5 on rising edge (count =  4, active = 1)
   //  1    D5                           (count =  5, active = 1)
   //  0    D4   latch D4 on rising edge (count =  6, active = 1)
   //  1    D4                           (count =  7, active = 1)
   //  0    D3   latch D3 on rising edge (count =  8, active = 1)
   //  1    D3                           (count =  9, active = 1)
   //  0    D2   latch D2 on rising edge (count = 10, active = 1)
   //  1    D2                           (count = 11, active = 1)
   //  0    D1   latch D1 on rising edge (count = 12, active = 1)
   //  1    D1                           (count = 13, active = 1)
   //  0    D0   latch D0 on rising edge (count = 14, active = 1)
   //  1    D0                           (count = 15, active = 1)
   //  0    x   x                        (count = 0,  active = 0)
   //
   // This is 17 states (including the idle state)
   //
   // So we use the following state bits:
   //    sd_active (1 bit register)
   //    sd_count  (4 bit register)
   //
   // With this arrangement, sd_count[0] is SCLK and sd_data[7] is MOSI
   //
   // In addition, one further register is needed to latch MISO on the rising SCLK edge

   always @(negedge E, negedge nRESET) begin
      if (!nRESET) begin
         sd_data   <= 8'b00000000;
         sd_count  <= 4'b0000;
         sd_active <= 1'b0;
         sd_tmp    <= 1'b0;
      end else if (sd_active) begin
         sd_count <= sd_count + 1;
         if (sd_count[0]) begin
            // Shift data on the falling SCLK edge
            sd_data <= {sd_data[6:0], sd_tmp};
         end else begin
            // Latch MISO on the rising SCLK edge
            sd_tmp <= MISO;
         end
         // When count reaches 4'b1111 then active gets set back to false
         sd_active <= !(&sd_count);
      end else if (!RnW && mmu_reg_access && ADDR[2:0] == 3'b100) begin
         sd_active <= 1'b1;
         sd_data <= DATA;
      end else if (!RnW && mmu_reg_access && ADDR[2:0] == 3'b101) begin
         // A write to the control register allows the SCLK,MOSI to be manually set during initialization
         sd_count[0] <= DATA[0]; // SCLK
         sd_data[7]  <= DATA[1]; // MOSI
      end
   end

   assign SCLK = sd_count[0];
   assign MOSI = sd_data[7];

endmodule
