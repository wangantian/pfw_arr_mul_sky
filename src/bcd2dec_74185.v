`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/31/2026 03:58:19 PM
// Design Name: 
// Module Name: bcd2dec_74185
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

module bcd2dec_74185( 
    input [4:0] X,
    output [5:0] Y   
);
wire [5:0] code;
assign code = {X,1'b0}; 
 
assign Y[5] = ((code>=6'd40))?1'b1: 0;
assign Y[4] = (((code>=6'd20)&&(code<=6'd39))||
			   ((code>=6'd60)&&(code<=6'd63)))?1'b1: 0;
assign Y[3] = (((code>=6'd10)&&(code<=6'd19))||
			   ((code>=6'd30)&&(code<=6'd39))||
			   ((code>=6'd50)&&(code<=6'd59)))?1'b1: 0;
assign Y[2] = ((code==6'd08)||(code==6'd18)||(code==6'd28)||
			   (code==6'd38)||(code==6'd48)||(code==6'd58))?1'b1: 0;
assign Y[1] = ((code==6'd04)||(code==6'd06)||
			   (code==6'd14)||(code==6'd16)||
			   (code==6'd24)||(code==6'd26)||
			   (code==6'd34)||(code==6'd36)||
			   (code==6'd44)||(code==6'd46)||
			   (code==6'd54)||(code==6'd56)
			   )?1'b1: 0;
assign Y[0] =  ((code==6'd02)||(code==6'd06)||
			    (code==6'd12)||(code==6'd16)||
			    (code==6'd22)||(code==6'd26)||
			    (code==6'd32)||(code==6'd36)||
			    (code==6'd42)||(code==6'd46)||
			    (code==6'd52)||(code==6'd56)||
				(code==6'd62)
			   )?1'b1: 0; 

endmodule
