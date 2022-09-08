`include "parameter.v"

module image_read
#(
  parameter WIDTH = 768,  // image width
            HEIGH = 512,  // image heigh
			INFILE = "kodim23.hex",  // image file name
			START_UP_DELAY = 100,  //delay during start up time
			HSYNC_DELAY = 160,  // delay between HSYNC pulses
			VALUE = 150,     // value for brightness operation
			THRESHOLD = 90,  // sign value using for brightness operation
			SIGN = 0   // sign = 0: brightness subtraction (-)
			           // sign = 1: brightness addition  (+)
  )
  (
  input HCLK ,   // clock
  input HRESETn,  // reset: active in low level
  
  output VSYNC, //Vertical  synchronous pulse: xung đồng bộ dọc
  // This signal is often a way to indicate that one entire image is transmitted.
  // Just create and is not used, will be used once a video or many images are transmitted.
  output reg HSYNC, //Horizontal synchronous pulse: xung đồng bộ ngang
  // An HSYNC indicates that one line of the image is transmitted.
  // Used to be a horizontal synchronous signals for writing bmp file.
  
  // 8 bit color R/G/B even
  output reg [7:0] DATA_R0,
  output reg [7:0] DATA_G0,
  output reg [7:0] DATA_B0,
  // 8 bit color R/G/B old
  output reg [7:0] DATA_R1,
  output reg [7:0] DATA_G1,
  output reg [7:0] DATA_B1,
  
  // process and transmit 2 pixels in paraller to make process faster 
  // you can modidy to transmit 1 pixel or more if needed
  // nghia la truyen may cai r/g/b old vaf r/g/b even ben tren
  output           ctrl_done  // done flag
  
   );

//internal signal: cac tin hieu noi bo

parameter sizeOfWidth = 8;  // data width
parameter sizeOfLengthReal = WIDTH * HEIGH * 3; // do co 3 lop R/G/B

// local parameter for FS

localparam   ST_IDLE   = 2'b00,    // idle state
             ST_VSYNC  = 2'b01,    // state for creating vsync
			 ST_HSYNC  = 2'b10,    // state for creating hsync
			 ST_DATA   = 2'b11;    // state for data processing
reg [1:0] cstate,  // current state
          nstate;  // next state
reg start;   // start signal: trigger FSM beginning to operate
reg HRESETn_d;   //delay reset signal: use to create  start signal

reg         ctrl_vsync_run;   // control signl for vsync counter
reg [8:0]   ctrl_vsync_cnt;   // counter for vsync
reg         ctrl_hsync_run;    // control signal for hsync counter
reg [8:0]   ctrl_hsync_cnt;    // counter for hsync
reg         ctrl_data_run;    // control signal for data processing
reg  [31:0] in_memory     [0 : sizeOfLengthReal / 4];   // memory to store 32 bit data image
reg  [7:0]   total_memory [0 : sizeOfLengthReal - 1];   // memory to store 8 bit data image
   
// temporara memory to save image data: size will be WIDTH * HEIGH * 3
integer temp_BMP [0 : WIDTH * HEIGH * 3 - 1];
integer org_R    [0 : WIDTH * HEIGH - 1]; // temporary storage for R component
integer org_G    [0 : WIDTH * HEIGH - 1]; // temporary storage for G component
integer org_B    [0 : WIDTH * HEIGH - 1]; // temporary storage for B component

// counting variable
integer i, j;
//temporary signals for calculation: details in the paper.
integer tempR0, tempR1, tempG0, tempG1, tempB0, tempB1;  // temporary variables in contrast and brightness operation

integer value, value1, value2, value4; // temporary variables in invert and threshold operation

reg  [9:0] row;   // row index of the image
reg  [10:0]  col; // column index of the image
reg  [18:0] data_count;  // data counting for entire pixels of the image	
		 
  
//
//  Reading dara from input file
//

initial 
  begin
    $readmemh(INFILE, total_memory, 0, sizeOfLengthReal - 1);  // read file
  end
  
// use 3 intermediate signals RGB to save image data:  
// su dung 3 tin hieu trung gian de luu tru du lieu anh

always @ (start) 
  begin 
    if(start == 1'b1) 
	  begin
	    for(i = 0; i < sizeOfLengthReal; i = i + 1)
		  begin 
		    temp_BMP[i] = total_memory[i][7:0];
		  end
		for( i = 0; i < HEIGH; i = i + 1)
		  begin
		    for( j = 0; j < WIDTH; j = j + 1)
			  begin
			    // org: just save only R/ G or B
				// temp: save all
				org_R[WIDTH * i + j] = temp_BMP[WIDTH * 3 * (HEIGH - i - 1) + 3 * j + 0];
				org_G[WIDTH * i + j] = temp_BMP[WIDTH * 3 * (HEIGH - i - 1) + 3 * j + 1];
				org_B[WIDTH * i + j] = temp_BMP[WIDTH * 3 * (HEIGH - i - 1) + 3 * j + 2];
			  end
		  end
	  end
  end 
	
// begin  to read image file once reset was high
// by creating a starting pulse 

always @ (posedge HCLK, negedge HRESETn)
  begin
    if(!HRESETn)
	  begin
	    start <= 0;
		HRESETn_d <= 0;
	  end
	else
	  begin
	    HRESETn_d <= HRESETn;
		if(HRESETn == 1'b1 && HRESETn_d == 1'b0)
		  start <= 1'b1;
		else 
		  start <= 1'b0;
	  end
  end 
// FSM to Rreading RGB (8bit) data from memory and creating hsync and vsync pulse

always @ (posedge HCLK, negedge HRESETn)
  begin
    if(~HRESETn)
	  begin
	    cstate <= ST_IDLE;
	  end
	else 
	  begin
	    cstate <= nstate;  // update to next state
	  end
  end

// State Transition: chuyen tiep trang thai theo FSM

always @ (*) 
  begin
    case(cstate)
	  ST_IDLE: 
	    begin
		  if(start) nstate = ST_VSYNC;
		  else nstate = ST_IDLE;
		end
	  ST_VSYNC:
	    begin
		  if(ctrl_vsync_cnt == START_UP_DELAY) nstate = ST_HSYNC;
		  else nstate = ST_VSYNC;
		end
	  ST_HSYNC:
	    begin
		  if(ctrl_hsync_cnt == HSYNC_DELAY) nstate = ST_DATA;
		  else nstate = ST_HSYNC;
		end
	  ST_DATA:
	    begin
		  if(ctrl_done) nstate = ST_IDLE;
		  else 
		    begin
			  if(col == WIDTH - 2) nstate = ST_HSYNC;
			  else nstate = ST_DATA;		
			end
		end
	  endcase
  end
  
// counting for the time period of vsync, hsync, data processing

always @ (*) 
  begin
    ctrl_vsync_run = 0;
	ctrl_hsync_run = 0;
	ctrl_data_run  = 0;
	case(cstate)
	  ST_VSYNC:
	    begin
		  ctrl_vsync_run = 1;  // trigger counting for vsync: kich hoat
		end
	  ST_HSYNC:
	    begin
		  ctrl_hsync_run = 1; // trigger counting for hsync
		end
	  ST_DATA:
	    begin
		  ctrl_data_run = 1; // trigger counting for data processing
		end
	  endcase
  end
// counter for vsync, hsync
always @ ( posedge HCLK, negedge HRESETn)
  begin
    if(~HRESETn)
	  begin
	    ctrl_vsync_cnt <= 0;
		ctrl_hsync_cnt <= 0;
	  end
	else
	  begin
	    if(ctrl_vsync_run)
		  ctrl_vsync_cnt <= ctrl_vsync_cnt + 1;// counting for vsync
		else
		  ctrl_vsync_cnt <= 0;
		if(ctrl_hsync_run)
		  ctrl_hsync_cnt <= ctrl_hsync_cnt + 1;
		else 
		  ctrl_hsync_cnt <= 0;
	  end
  end
// counting column and row index for reading memory

always @ (posedge HCLK, negedge HRESETn)
  begin
    if(~HRESETn)
	  begin
	    row <= 0;
		col <= 0;
	  end
	else
	  begin
	  if(ctrl_data_run)
	    begin
		  if(col == WIDTH - 2) row <= row + 1;
		  if(col == WIDTH - 2) col <= 0;
		  else col <= col + 2;   //reading 2 pixels in parallel
		   
		end
	  end
  end
 
// Data counting

always @ (posedge HCLK, negedge HRESETn)
  begin
    if(~HRESETn) data_count <= 0;
	else
	  begin
	    if(ctrl_data_run) data_count <= data_count + 1;
	  end
  end
assign VSYNC = ctrl_vsync_run;
assign ctrl_done = (data_count == WIDTH * HEIGH / 2 - 1) ? 1'b1 : 1'b0;

// image processing

always @ (*)
  begin
  HSYNC = 1'b0;
  DATA_R0 = 0;
  DATA_G0 = 0;
  DATA_B0 = 0;
  DATA_R1 = 0;
  DATA_G1 = 0;
  DATA_B1 = 0;
  
  if(ctrl_data_run)
    begin
	  HSYNC = 1'b1;
	  `ifdef BRIGHTNESS_OPERATION
	  if(SIGN == 1) // addition brightness
	    begin
		// R0
		  tempR0 = org_R[WIDTH * row + col] + VALUE;  // tam thoi
		  if(tempR0 > 255) DATA_R0 = 255;
		  else DATA_R0 = org_R[WIDTH * row + col] + VALUE;
		// R1
		  tempR1 = org_R[WIDTH * row + col + 1] + VALUE;
		  if(tempR1 > 255) DATA_R1 = 255;
		  else DATA_R1 = org_R[WIDTH * row + col + 1] + VALUE;
		// G0
		  tempG0 = org_G[WIDTH * row + col] + VALUE;
		  if(tempG0 > 255) DATA_G0 = 255;
		  else DATA_G0 = org_G[WIDTH * row + col] + VALUE;
		// g1
		  tempG1 = org_G[ WIDTH * row + col + 1] + VALUE;
		  if(tempG1 > 255) DATA_G1 = 255;
		  else DATA_G1 = org_G[WIDTH * row + col + 1] + VALUE;
		// B0
		  tempB0 = org_B[WIDTH * row + col] + VALUE;
		  if(tempB0 > 255) DATA_B0 = 255;
		  else DATA_B0 = org_B[WIDTH * row + col] + VALUE;
		// B1
		  tempB1 = org_B[WIDTH * row + col + 1 ] + VALUE;
		  if(tempB1 > 255) DATA_B1 = 255;
		  else DATA_B1 = org_B[WIDTH * row + col + 1] + VALUE; 
		end
	  else  // sign = 0: (-) 
	    begin
		  //R0
		  tempR0 = org_R[WIDTH * row + col] - VALUE;
		  if(tempR0 < 0) DATA_R0 = 0;
		  else DATA_R0 = org_R[WIDTH * row + col] - VALUE;
		  //R1
		  tempR1 = org_R[WIDTH * row + col + 1] - VALUE;
		  if(tempR1 < 0) DATA_R1 = 0;
		  else DATA_R1 = org_R[WIDTH * row + col + 1] - VALUE;
		  // G0
		  tempG0 = org_G[WIDTH * row + col] - VALUE;
		  if (tempG0 < 0) DATA_G0 = 0;
		  else DATA_G0 = org_G[WIDTH * row + col] - VALUE;
		  // G1
		  tempG1 = org_G[WIDTH * row + col + 1] - VALUE;
		  if(tempG1 < 0 ) DATA_G1 = 0;
		  else DATA_G1 = org_G[WIDTH * row + col + 1] - VALUE;
		  // B0
		  tempB0 = org_B[WIDTH * row + col] - VALUE;
		  if(tempB0 < 0) DATA_B0 = 0;
		  else DATA_B0 = org_B[WIDTH * row + col] - VALUE;
		  // B1;
		  tempB1 = org_B[WIDTH * row + col + 1] - VALUE;
		  if(tempB1 < 0) DATA_B1 = 0;
		  else DATA_B1 = org_B[WIDTH * row + col + 1] - VALUE;
		end
	  `endif
	  
	  // INVERT_ OPERATOR
	  `ifdef INVERT_OPERATION
	    value2 = ( org_R[WIDTH * row + col] + org_G[WIDTH * row + col] + org_B[WIDTH * row + col] )/3;
		DATA_R0 = 255 - value2;
		DATA_G0 = 255 - value2;
		DATA_B0 = 255 - value2;
		value4 = (org_R[WIDTH * row + col + 1] + org_G[WIDTH *row + col + 1] + org_B[WIDTH * row + col + 1])/3;
		DATA_R1 = 255 - value4;
		DATA_G1 = 255 - value4;
		DATA_B1 = 255 - value4;
	  `endif
    // THRESHOLD
    `ifdef THRESHOLD_OPERATION
	  value = (org_R[WIDTH * row + col] + org_B[WIDTH * row + col] + org_G[WIDTH * row + col])/3;
	  if(value > THRESHOLD )
	    begin
		  DATA_R0 = 255;
		  DATA_B0 = 255;
		  DATA_G0 = 255;
		end
	  else
	    begin
		  DATA_B0 = 0;
		  DATA_R0 = 0;
		  DATA_G0 = 0;
		end
	  value1 = (org_R[WIDTH * row + col + 1] + org_G[WIDTH * row + col + 1] + org_B[WIDTH * row + col + 1])/3;
	  if(value1 > THRESHOLD)
	    begin
		  DATA_R1 = 255;
		  DATA_G1 = 255;
		  DATA_B1 = 255;
		end
	  else
	    begin
		  DATA_R1 = 0;
		  DATA_B1 = 0;
		  DATA_G1 = 0;
		end
	  `endif
	end
  end
endmodule