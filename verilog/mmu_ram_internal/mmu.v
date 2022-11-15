module mmu
  (
   // CPU
   input          Q,
   input          E,
   input          CLKX4,
   input          MRDY,
   input [15:0]   ADDR,
   input [7:0]    DATA,
   input          BA,
   input          BS,
   input          RnW,
   input          nRESET,

   output reg     QX,
   output reg     EX,
   output         A8X,

   // Memory
   output [18:13] QA,
   output         nRD,
   output         nWR,
   output         nCSEXT,
   output         nCSROM0,
   output         nCSROM1,
   output         nCSRAM,
   output         nCSUART,

   // External bus buffers
   output         BUFDIR,
   output         nBUFEN

   );


   reg            tr;
   reg            enmmu;
   reg [1:0]      rommap;
   reg [5:0]      mmu_ram [0:15];


   always @(negedge E) begin
      if (!RnW) begin
         if (ADDR == 16'hFF90) begin
            enmmu <= DATA[6];
            rommap <= DATA[1:0];
         end
         if (ADDR == 16'hFF91) begin
            tr <= DATA[0];
         end
         if (ADDR[15:4] == 12'hFFA) begin
            mmu_ram[ADDR[3:0]] <= DATA[5:0];
         end
      end
   end


   always @(posedge CLKX4) begin
      // Q lesds E
      case ({QX, EX})
        2'b00: QX <= 1'b1;
        2'b10: EX <= 1'b1;
        2'b11: QX <= 1'b0;
        2'b01: if (MRDY) EX <= 0;
      endcase
   end

   assign A8X = ADDR[8] ^ (!BA & BS & RnW);

   assign QA = enmmu ? mmu_ram[{tr, ADDR[15:13]}] : {3'b000, ADDR[15:13]};


   assign nRD = !(E & RnW);
   assign nWR = !(E & !RnW);

   assign nCSUART = !(E & ADDR[15:4] == 12'hFE0);


   // TODO
   assign nCSROM0 = 1'b1;
   assign nCSROM1 = 1'b1;
   assign nCSRAM  = 1'b1;
   assign nCSEXT  = 1'b1;
   assign BUFDIR  = 1'b1;
   assign nBUFEN  = 1'b1;

endmodule
