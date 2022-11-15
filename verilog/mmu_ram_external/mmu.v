module mmu
  (
   // CPU
   input        E,
   input [15:0] ADDR,
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
   output       A8X,
   output       QA13,
   output       nRD,
   output       nWR,
   output       nCSEXT,
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

   parameter IO_PAGE = 16'hFE00;
   wire io_access  = {ADDR[15:8], 8'h00} == IO_PAGE;
   wire io_access_int = io_access & (ADDR[7:0] < 8'h30);
   wire mmu_access = {ADDR[15:3], 3'b000} == IO_PAGE + 16'h0020;
   wire mmu_access_rd = mmu_access & RnW;
   wire mmu_access_wr = mmu_access & !RnW;

   // Internal Registers
   reg            enmmu;
   reg            mode8k;
   reg [4:0]      access_key;
   reg [4:0]      task_key;

   always @(negedge E, negedge nRESET) begin
      if (!nRESET) begin
         mode8k     <= 1'b1;
         {mode8k, enmmu} <= 2'b0;
         access_key <= 5'b0;
         task_key <= 5'b0;
      end else begin
         if (!RnW && ADDR == IO_PAGE + 16'h0010) begin
            {mode8k, enmmu} <= DATA[1:0];
         end
         if (!RnW && ADDR == IO_PAGE + 16'h0011) begin
            access_key <= DATA[4:0];
         end
         if (!RnW && ADDR == IO_PAGE + 16'h0012) begin
            task_key <= DATA[4:0];
         end
      end
   end

   assign DATA = E && RnW && ADDR == IO_PAGE + 16'h0010 ? {6'b0, mode8k, enmmu} :
                 E && RnW && ADDR == IO_PAGE + 16'h0011 ? {3'b0, access_key} :
                 E && RnW && ADDR == IO_PAGE + 16'h0012 ? {3'b0, task_key} :
                 E && mmu_access_rd                     ? MMU_DATA :
                 8'hZZ;

   assign MMU_ADDR = mmu_access ? {access_key, ADDR[2:0]} : {task_key, ADDR[15:13]};
// assign MMU_nCS  = 1'b0;
   assign MMU_nRD  = !(enmmu & !mmu_access_wr);
   assign MMU_nWR  = !(E     &  mmu_access_wr);
   assign MMU_DATA = (mmu_access_wr & E) ? DATA : enmmu ? 8'hZZ : {5'b00000, ADDR[15:13]};

   assign QA13 = mode8k ? MMU_DATA[5] : ADDR[13];

   always @(posedge CLKX4) begin
      // Q leads E
      case ({QX, EX})
        2'b00: QX <= 1'b1;
        2'b10: EX <= 1'b1;
        2'b11: QX <= 1'b0;
        2'b01: if (MRDY) EX <= 0;
      endcase
   end

   assign A8X = ADDR[8] ^ (!BA & BS & RnW);
   assign nRD = !(E & RnW);
   assign nWR = !(E & !RnW);
   assign nCSUART = !(E & {ADDR[15:4], 4'b0000} == IO_PAGE);

   assign nCSROM0 = !(((enmmu & MMU_DATA[7:6] == 2'b00) | (!enmmu &  ADDR[15])) & !io_access);
   assign nCSROM1 = !(  enmmu & MMU_DATA[7:6] == 2'b01                          & !io_access);
   assign nCSRAM  = !(((enmmu & MMU_DATA[7:6] == 2'b10) | (!enmmu & !ADDR[15])) & !io_access);
   assign nCSEXT  = !(BA ^ (enmmu & ((MMU_DATA[7:6] == 2'b11) | io_access) & !io_access_int));
   assign nBUFEN  = !(BA ^ (enmmu & ((MMU_DATA[7:6] == 2'b11) | io_access) & !io_access_int));
   assign BUFDIR  =   BA ^ RnW;

endmodule