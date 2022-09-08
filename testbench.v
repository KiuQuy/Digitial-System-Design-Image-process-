`timescale 1ns/1ps
`include "parameter.v"
module testbench;
// internal signal
reg HCLK, HRESETn;
wire hsync;
wire vsync;
wire [7:0]  DATA_R0;						// Red 8-bit data (odd)
wire [7:0]  DATA_G0;						// Green 8-bit data (odd)
wire [7:0]  DATA_B0;						// Blue 8-bit data (odd)
wire [7:0]  DATA_R1;						// Red 8-bit data (even)
wire [7:0]  DATA_G1;						// Green 8-bit data (even)
wire [7:0]  DATA_B1;	
wire enc_done;

// Component
image_read
#( .INFILE(`INPUTFILENAME)
) u_image_read
(
 .HCLK(HCLK),
 .HRESETn(HRESETn),
 .VSYNC(vsync),
 .HSYNC(hsync),
 .DATA_R0(DATA_R0),
 .DATA_G0(DATA_G0),
 .DATA_B0(DATA_B0),
 .DATA_R1(DATA_R1),
 .DATA_G1(DATA_G1),
 .DATA_B1(DATA_B1),
 .ctrl_done(enc_done)
);
image_write
#(.INFILE(`OUTPUTFILENAME))
  u_image_write
(
.HCLK(HCLK),
.HRESETn(HRESETn),
.hsync(hsync),
.DATA_WRITE_R0(DATA_R0),
.DATA_WRITE_G0(DATA_G0),
.DATA_WRITE_B0(DATA_B0),
.DATA_WRITE_R1(DATA_R1),
.DATA_WRITE_G1(DATA_G1),
.DATA_WRITE_B1(DATA_B1),
.Write_Done()
);
// test Vector
initial 
  begin
    HCLK = 0;
	forever #10 HCLK = ~HCLK;
  end
initial
  begin
    HRESETn = 0;
	#25 HRESETn = 1;
  end
endmodule

