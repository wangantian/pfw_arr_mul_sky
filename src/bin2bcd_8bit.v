`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/31/2026 03:46:50 PM
// Design Name: 
// Module Name: bin2bcd_8bit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`default_nettype none

module bin2bcd_8bit(
input [7:0] X,
output [3:0] Hundred,
output [3:0] Tens,
output [3:0] Ones
 );

wire [5:0] stage_top_out, stage_mid_out, stage_bot_out;


bcd2dec_74185 bcd2dec_74185_top_inst(.X(X[7:3]),.Y(stage_top_out));
bcd2dec_74185 bcd2dec_74185_mid_inst(.X({stage_top_out[2:0],X[2:1]}),.Y(stage_mid_out));
bcd2dec_74185 bcd2dec_74185_bot_inst(.X({1'b0,stage_top_out[5:3],stage_mid_out[4]}),.Y(stage_bot_out));

assign Hundred = {2'b0,stage_bot_out[4:3]};
assign Tens = {stage_bot_out[2:0],stage_mid_out[3]};
assign Ones = {stage_mid_out[3:0],X[0]}; 
endmodule
