`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:09:23 07/23/2019 
// Design Name: 
// Module Name:    data_storage 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module data_storage(
	input [31:0] DataIn,
	output [7:0] DataOut,
	input WriteStrobe,
	input ReadEnable,
	input WriteClock,
	input WriteClockDelayed,
	input ReadClock,
	input Reset,
	output DataValid,
	output FifoNotFull,
	output [1:0] State
	);
	
	//Setting Local Parameters: is singular fifo ready to store, storing, or sending?//
	localparam 	READY_TO_STORE = 2'b00,
					STORING_DATA = 2'b01,
					SENDING_DATA = 2'b10;
	
	//initializing singular fifo current and next states. State is Current State.//
	reg [1:0] CurrentState = SENDING_DATA;
	reg [1:0] NextState = SENDING_DATA;
	assign State = CurrentState;
	
	//initializing singular fifo conditions: rd_en/wr_en/full//
	wire FifoReadEn;
	reg [1:0] WriteEnableEdge = 2'b00;
	assign WriteEnable = (CurrentState == STORING_DATA);
	assign FifoNotFull = ~(CurrentState[1]);
	
	//initializing JOINT fifo conditions: are they all valid/empty/full?//
	wire SideFull, TopFull, BottomFull; 
	wire SideEmpty, TopEmpty, BottomEmpty;
	wire SideValid, TopValid, BottomValid;
	wire FifosValid = (SideValid && TopValid && BottomValid);
	wire FifosEmpty = (SideEmpty && TopEmpty && BottomEmpty);
	wire FifosFull = (SideFull || TopFull || BottomFull); 
	
	//initializing conditions for JOINT fifo data to go to 32to8 converter//
	////////////////This is dependent on 32to8 fifo outputs below /////////////////
	wire ConverterWriteEn, ConverterFull, ConverterEmpty, ConverterValid, ConverterAlmostFull;
	assign FifoReadEn = (~ConverterAlmostFull && ~FifosEmpty);
	
	//output of JOINT fifos to go into 32to8 converter//
	wire [31:0] FifoDataOut;
	
	always @(posedge ReadClock) begin
		if (Reset) begin
			CurrentState <= READY_TO_STORE;
			WriteEnableEdge <= 2'b00;
		end else begin
			CurrentState <= NextState;
			WriteEnableEdge <= {WriteEnableEdge[0], WriteStrobe};
		end
	end
	
	always@(*) begin
		NextState = CurrentState;
		case (CurrentState)
			READY_TO_STORE: begin if(WriteEnableEdge == 2'b01) NextState = STORING_DATA;end
			STORING_DATA: begin if(FifosFull) NextState = SENDING_DATA;end
			SENDING_DATA: begin if (ConverterEmpty) NextState = READY_TO_STORE;end
			default: begin CurrentState = CurrentState; end
		endcase
	end
	
	FIFO_11bit FIFO_Side_Inputs (
		.rst(Reset), // input rst
		.wr_clk(WriteClock), // input wr_clk
		.rd_clk(ReadClock), // input rd_clk
		.din({DataIn[31:26], DataIn[15:11]}), // input [10 : 0] din
		.wr_en(WriteEnable), // input wr_en
		.rd_en(FifoReadEn), // input rd_en
		.dout({FifoDataOut[31:26], FifoDataOut[15:11]}), // output [10 : 0] dout
		.full(SideFull), // output full
		.empty(SideEmpty), // output empty
		.valid(SideValid) // output valid
		);
	
	FIFO_11bit FIFO_Bottom_Inputs (
		.rst(Reset), // input rst
		.wr_clk(WriteClockDelayed), // input wr_clk
		.rd_clk(ReadClock), // input rd_clk
		.din(DataIn[10:0]), // input [10 : 0] din
		.wr_en(WriteEnable), // input wr_en
		.rd_en(FifoReadEn), // input rd_en
		.dout(FifoDataOut[10:0]), // output [10 : 0] dout
		.full(BottomFull), // output full
		.empty(BottomEmpty), // output empty
		.valid(BottomValid) // output valid
		);
		
	FIFO_10bit FIFO_Top_Inputs (
		.rst(Reset), // input rst
		.wr_clk(WriteClockDelayed), // input wr_clk
		.rd_clk(ReadClock), // input rd_clk
		.din(DataIn[25:16]), // input [9 : 0] din
		.wr_en(WriteEnable), // input wr_en
		.rd_en(FifoReadEn), // input rd_en
		.dout(FifoDataOut[25:16]), // output [9 : 0] dout
		.full(TopFull), // output full
		.empty(TopEmpty), // output empty
		.valid(TopValid) // output valid
		);	
		
	
	reg [31:0] FirstWord = 32'b11111111100000000111111100000000;
	wire [31:0] dwcInput;
	wire dwcWrEn;

	//These assignments should mean that the first 4 bytes are the signature "FirstWord" to denote the start of data transfer
	assign dwcInput = (WriteEnableEdge == 2'b01) ? FirstWord : FifoDataOut[31:0];
	assign dwcWrEn =  (WriteEnableEdge == 2'b01) ? 1'b1 : FifosValid;
	
	
	FIFO_32to8 DataWidthConverter (
		.rst(Reset), // input rst
		.wr_clk(ReadClock), // input wr_clk
		.rd_clk(ReadClock), // input rd_clk
		.din(dwcInput), // input [31 : 0] din
		.wr_en(dwcWrEn), // input wr_en
		.rd_en(ReadEnable), // input rd_en
		.dout(DataOut), // output [7 : 0] dout
		.full(ConverterFull), // output full
		.almost_full(ConverterAlmostFull),
		.empty(ConverterEmpty), // output empty
		.valid(DataValid) // output valid
		);
	
endmodule
