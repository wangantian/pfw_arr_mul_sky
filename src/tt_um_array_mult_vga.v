/*
 * 4x4 Array Multiplier with VGA Decimal Display
 * SPDX-License-Identifier: Apache-2.0
 *
 * Inputs:
 *   ui_in[3:0] = multiplicand A (4 bits) — bare solder pads
 *   ui_in[7:4] = multiplier    B (4 bits) — bare solder pads
 *   clk        = 25 MHz (required for 640x480@60Hz VGA)
 *
 * Outputs:
 *   uo_out     = Tiny VGA PMOD  {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}
 *
 * The VGA monitor shows "A x B = P" in large colored decimal digits.
 * A set of blocks is displayed below to show the value of the multiplication results and the partial submission results. 
 */

`default_nettype none

module tt_um_array_mult_vga (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // -----------------------------------------------------------------------
  // Input registers — directly connected to solder pads on the board
  // -----------------------------------------------------------------------
  reg [3:0] A_reg, B_reg;

  always @(posedge clk) begin
    if (!rst_n) begin
      A_reg <= 4'b0;
      B_reg <= 4'b0;
    end else begin
      A_reg <= ui_in[3:0];
      B_reg <= ui_in[7:4];
    end
  end

  // -----------------------------------------------------------------------
  // 4x4 Array Multiplier (structural full-adder tree)
  // P[7:0] = A_reg * B_reg
  // -----------------------------------------------------------------------
  wire [7:0] P;

  wire C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11;
  wire s1, s2, s3, s4, s5, s6;

  assign P[0] = A_reg[0] & B_reg[0];

  fa fa1  (.x(A_reg[0] & B_reg[1]), .y(A_reg[1] & B_reg[0]), .cin(1'b0),  .s(P[1]),  .cout(C1));
  fa fa2  (.x(A_reg[2] & B_reg[0]), .y(A_reg[1] & B_reg[1]), .cin(C1),    .s(s1),    .cout(C2));
  fa fa3  (.x(A_reg[3] & B_reg[0]), .y(A_reg[2] & B_reg[1]), .cin(C2),    .s(s2),    .cout(C3));
  fa fa4  (.x(A_reg[3] & B_reg[1]), .y(1'b0),                .cin(C3),    .s(s3),    .cout(C4));
  fa fa5  (.x(A_reg[0] & B_reg[2]), .y(s1),                  .cin(1'b0),  .s(P[2]),  .cout(C5));
  fa fa6  (.x(A_reg[1] & B_reg[2]), .y(s2),                  .cin(C5),    .s(s4),    .cout(C6));
  fa fa7  (.x(A_reg[2] & B_reg[2]), .y(s3),                  .cin(C6),    .s(s5),    .cout(C7));
  fa fa8  (.x(A_reg[3] & B_reg[2]), .y(C4),                  .cin(C7),    .s(s6),    .cout(C8));
  fa fa9  (.x(A_reg[0] & B_reg[3]), .y(s4),                  .cin(1'b0),  .s(P[3]),  .cout(C9));
  fa fa10 (.x(A_reg[1] & B_reg[3]), .y(s5),                  .cin(C9),    .s(P[4]),  .cout(C10));
  fa fa11 (.x(A_reg[2] & B_reg[3]), .y(s6),                  .cin(C10),   .s(P[5]),  .cout(C11));
  fa fa12 (.x(A_reg[3] & B_reg[3]), .y(C8),                  .cin(C11),   .s(P[6]),  .cout(P[7]));

  // -----------------------------------------------------------------------
  // BCD conversion
  // -----------------------------------------------------------------------

  // A (0–15): trivial split
  wire [3:0] A_tens = (A_reg >= 4'd10) ? 4'd1 : 4'd0;
  wire [3:0] A_ones = (A_reg >= 4'd10) ? A_reg - 4'd10 : A_reg;

  // B (0–15): trivial split
  wire [3:0] B_tens = (B_reg >= 4'd10) ? 4'd1 : 4'd0;
  wire [3:0] B_ones = (B_reg >= 4'd10) ? B_reg - 4'd10 : B_reg;

  // P (0–225): double-dabble algorithm
  wire [3:0]  P_hundreds;// = P_bcd[11:8];
  wire [3:0]  P_tens;//     = P_bcd[7:4];
  wire [3:0]  P_ones;//     = P_bcd[3:0];


 bin2bcd_8bit bin2bcd_8bit_inst(.X(P),.Hundred(P_hundreds),.Tens(P_tens),.Ones(P_ones));

  // -----------------------------------------------------------------------
  // VGA sync generator
  // -----------------------------------------------------------------------
  wire       hsync, vsync, display_on;
  wire [9:0] hpos, vpos;

  hvsync_generator hvsync_gen (
    .clk       (clk),
    .reset     (~rst_n),
    .hsync     (hsync),
    .vsync     (vsync),
    .display_on(display_on),
    .hpos      (hpos),
    .vpos      (vpos)
  );

  // -----------------------------------------------------------------------
  // Text rendering — "NN x NN = NNN" centred on screen
  //
  // 13 character slots, 4× scale  (each char = 32×32 px from 8×8 font)
  //   total width  = 13 × 32 = 416 px
  //   total height = 32 px
  //
  // Positioned inside a decorative bordered card.
  // -----------------------------------------------------------------------

  // Card (panel behind the text, with padding)
  localparam CARD_X0     = 10'd96;
  localparam CARD_X1     = 10'd544;   // 96 + 448
  localparam CARD_Y0     = 10'd58;
  localparam CARD_Y1     = 10'd122;   // 58 + 64
  localparam BORDER      = 10'd3;

  localparam mult_gap    = 10'd5;
  localparam bit_size    = 10'd20;
  localparam bit_gap     = 10'd5;

  // Text area inside card
  localparam TEXT_X0     = 10'd112;   // (640 − 416) / 2
  localparam TEXT_X1     = 10'd528;   // 112 + 416
  localparam TEXT_Y0     = 10'd74;
  localparam TEXT_Y1     = 10'd106;   // 74 + 32

  // Character indices for non-digit glyphs
  localparam CH_MUL      = 4'd10;    // '×'
  localparam CH_EQ       = 4'd11;    // '='
  localparam CH_SP       = 4'd12;    // space

  //array multiplier bit display spec 
  localparam bit_img_outer = 10'd56;
  localparam bit_img_inner = 10'd48;

  // Region flags
  wire in_card = (hpos >= CARD_X0) && (hpos < CARD_X1)
               && (vpos >= CARD_Y0) && (vpos < CARD_Y1);

  wire in_border = in_card && (
       (hpos < CARD_X0 + BORDER) || (hpos >= CARD_X1 - BORDER) ||
       (vpos < CARD_Y0 + BORDER) || (vpos >= CARD_Y1 - BORDER));

  wire in_text = (hpos >= TEXT_X0) && (hpos < TEXT_X1)
               && (vpos >= TEXT_Y0) && (vpos < TEXT_Y1);

  // Decorative colored bands below the equation card
  wire in_mul_array_x_bound = (hpos >= CARD_X0) && (hpos < CARD_X1);
  localparam MULT_START = CARD_Y1 + mult_gap;
  wire [7:0] pixel_color;
  
  wire logo_pixels = ((hpos >= CARD_X0 ) && (hpos < CARD_X0 + 256)) &&( (vpos >= MULT_START + 8*(bit_size+bit_gap) + bit_size) && (vpos < 128 + MULT_START + 8*(bit_size+bit_gap) + bit_size));
  wire [9:0] hpos_adj = hpos - CARD_X0;
  wire [9:0] vpos_adj = vpos -  (MULT_START + 8*(bit_size+bit_gap) + bit_size);
  
  mastodon_rom_compress   mastodon_rom_inst (.x(hpos_adj[7:0]), .y(vpos_adj[6:0]) ,.pixel(pixel_color)); 

  wire in_mul_array0 = in_mul_array_x_bound && (vpos >= MULT_START + 0*(bit_size+bit_gap)) && (vpos < MULT_START + 0*(bit_size+bit_gap) + bit_size);
  wire in_mul_array1 = in_mul_array_x_bound && (vpos >= MULT_START + 1*(bit_size+bit_gap)) && (vpos < MULT_START + 1*(bit_size+bit_gap) + bit_size);
  wire in_mul_array2 = in_mul_array_x_bound && (vpos >= MULT_START + 2*(bit_size+bit_gap)) && (vpos < MULT_START + 2*(bit_size+bit_gap) + bit_size);
  wire in_mul_array3 = in_mul_array_x_bound && (vpos >= MULT_START + 3*(bit_size+bit_gap)) && (vpos < MULT_START + 3*(bit_size+bit_gap) + bit_size);
  wire in_mul_array4 = in_mul_array_x_bound && (vpos >= MULT_START + 4*(bit_size+bit_gap)) && (vpos < MULT_START + 4*(bit_size+bit_gap) + bit_size);
  wire in_mul_array5 = in_mul_array_x_bound && (vpos >= MULT_START + 5*(bit_size+bit_gap)) && (vpos < MULT_START + 5*(bit_size+bit_gap) + bit_size);
  wire in_mul_array6 = in_mul_array_x_bound && (vpos >= MULT_START + 6*(bit_size+bit_gap)) && (vpos < MULT_START + 6*(bit_size+bit_gap) + bit_size);
 
                 // A3  A2  A1  A0
               // × B3  B2  B1  B0 
                 // P30 P20 P10 P00
           // + P31 P21 P11 P01 
         // S05 S04 S03 S02 S01 S00
       // + P32 P22 P12 P02 
     // S16 S15 S14 S13 S12 S11 S10
// +    P33 P23 P13 P03 
// S7 S6  S5  S4  S3  S2  S1  S0

 wire P00 =  A_reg[0] & B_reg[0];
 wire P10 =  A_reg[1] & B_reg[0];
 wire P20 =  A_reg[2] & B_reg[0]; 
 wire P30 =  A_reg[3] & B_reg[0];
 
 wire P01 =  A_reg[0] & B_reg[1];
 wire P11 =  A_reg[1] & B_reg[1];
 wire P21 =  A_reg[2] & B_reg[1];
 wire P31 =  A_reg[3] & B_reg[1];
 
 wire P02 =  A_reg[0] & B_reg[2];
 wire P12 =  A_reg[1] & B_reg[2];
 wire P22 =  A_reg[2] & B_reg[2];
 wire P32 =  A_reg[3] & B_reg[2];
 
 wire P03 =  A_reg[0] & B_reg[3];
 wire P13 =  A_reg[1] & B_reg[3];
 wire P23 =  A_reg[2] & B_reg[3];
 wire P33 =  A_reg[3] & B_reg[3];
 
 wire S00 = P[0];
 wire S01 = P[1];
 wire S02 = s1;
 wire S03 = s2;
 wire S04 = s3;
 wire S05 = C4;
 
 wire S10 = P[0];
 wire S11 = P[1];
 wire S12 = P[2];
 wire S13 = s4;
 wire S14 = s5;
 wire S15 = s6;
 wire S16 = C8;
 
 wire S27 = P[7];
 wire S26 = P[6];
 wire S25 = P[5];
 wire S24 = P[4];
 wire S23 = P[3];
 wire S22 = P[2];
 wire S21 = P[1];
 wire S20 = P[0];
 
 wire in_mul_array_line = (in_mul_array0 || in_mul_array1 || in_mul_array2 || in_mul_array3 || in_mul_array4 || in_mul_array5 || in_mul_array6) &&
							  ((hpos >= CARD_X1-0 * bit_img_outer-2) && (hpos < CARD_X1-0 * bit_img_outer)
							|| (hpos >= CARD_X1-1 * bit_img_outer-2) && (hpos < CARD_X1-1 * bit_img_outer)
							|| (hpos >= CARD_X1-2 * bit_img_outer-2) && (hpos < CARD_X1-2 * bit_img_outer)
							|| (hpos >= CARD_X1-3 * bit_img_outer-2) && (hpos < CARD_X1-3 * bit_img_outer)
							|| (hpos >= CARD_X1-4 * bit_img_outer-2) && (hpos < CARD_X1-4 * bit_img_outer)
							|| (hpos >= CARD_X1-5 * bit_img_outer-2) && (hpos < CARD_X1-5 * bit_img_outer)
							|| (hpos >= CARD_X1-6 * bit_img_outer-2) && (hpos < CARD_X1-6 * bit_img_outer)
							|| (hpos >= CARD_X1-7 * bit_img_outer-2) && (hpos < CARD_X1-7 * bit_img_outer)
							);
 
 
 wire in_mul_array0_partial = in_mul_array0& (((hpos >= CARD_X1-0 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-0 * bit_img_outer)& P00)
										    ||((hpos >= CARD_X1-1 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-1 * bit_img_outer)& P10)
											||((hpos >= CARD_X1-2 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-2 * bit_img_outer)& P20)
											||((hpos >= CARD_X1-3 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-3 * bit_img_outer)& P30)
											); 
 wire in_mul_array1_partial = in_mul_array1& (((hpos >= CARD_X1-1 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-1 * bit_img_outer)& P01)
										    ||((hpos >= CARD_X1-2 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-2 * bit_img_outer)& P11)
											||((hpos >= CARD_X1-3 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-3 * bit_img_outer)& P21)
											||((hpos >= CARD_X1-4 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-4 * bit_img_outer)& P31)
											); 
 wire in_mul_array2_partial = in_mul_array2& (((hpos >= CARD_X1-0 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-0 * bit_img_outer)& S00)
										    ||((hpos >= CARD_X1-1 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-1 * bit_img_outer)& S01)
											||((hpos >= CARD_X1-2 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-2 * bit_img_outer)& S02)
											||((hpos >= CARD_X1-3 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-3 * bit_img_outer)& S03)
											||((hpos >= CARD_X1-4 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-4 * bit_img_outer)& S04)
											||((hpos >= CARD_X1-5 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-5 * bit_img_outer)& S05)
											); 
 wire in_mul_array3_partial = in_mul_array3& (((hpos >= CARD_X1-2 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-2 * bit_img_outer)& P02)
										    ||((hpos >= CARD_X1-3 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-3 * bit_img_outer)& P12)
											||((hpos >= CARD_X1-4 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-4 * bit_img_outer)& P22)
											||((hpos >= CARD_X1-5 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-5 * bit_img_outer)& P32)
											); 
 wire in_mul_array4_partial = in_mul_array4& (((hpos >= CARD_X1-0 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-0 * bit_img_outer)& S10)
										    ||((hpos >= CARD_X1-1 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-1 * bit_img_outer)& S11)
											||((hpos >= CARD_X1-2 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-2 * bit_img_outer)& S12)
											||((hpos >= CARD_X1-3 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-3 * bit_img_outer)& S13)
											||((hpos >= CARD_X1-4 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-4 * bit_img_outer)& S14)
											||((hpos >= CARD_X1-5 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-5 * bit_img_outer)& S15)
											||((hpos >= CARD_X1-6 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-6 * bit_img_outer)& S16)
											);
 wire in_mul_array5_partial = in_mul_array5& (((hpos >= CARD_X1-3 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-3 * bit_img_outer)& P03)
										    ||((hpos >= CARD_X1-4 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-4 * bit_img_outer)& P13)
											||((hpos >= CARD_X1-5 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-5 * bit_img_outer)& P23)
											||((hpos >= CARD_X1-6 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-6 * bit_img_outer)& P33)
											); 
 wire in_mul_array6_partial = in_mul_array6& (((hpos >= CARD_X1-0 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-0 * bit_img_outer)& S20)
										    ||((hpos >= CARD_X1-1 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-1 * bit_img_outer)& S21)
											||((hpos >= CARD_X1-2 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-2 * bit_img_outer)& S22)
											||((hpos >= CARD_X1-3 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-3 * bit_img_outer)& S23)
											||((hpos >= CARD_X1-4 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-4 * bit_img_outer)& S24)
											||((hpos >= CARD_X1-5 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-5 * bit_img_outer)& S25)
											||((hpos >= CARD_X1-6 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-6 * bit_img_outer)& S26)
											||((hpos >= CARD_X1-7 * bit_img_outer- bit_img_inner) && (hpos < CARD_X1-7 * bit_img_outer)& S27)
											);	 
											
  // Position within the text grid
  wire [9:0] tx = hpos - TEXT_X0;
  wire [9:0] ty = vpos - TEXT_Y0;

  wire [3:0] char_slot = tx[8:5];        // ÷32 → slot 0..12
  wire [2:0] font_col  = tx[4:2];        // column in 8×8 glyph (4× scale)
  wire [2:0] font_row  = ty[4:2];        // row    in 8×8 glyph (4× scale)

  // -----------------------------------------------------------------------
  // Map each slot to a character index (with leading-zero suppression)
  // Slot layout:  A_t A_o SP × SP B_t B_o SP = SP P_h P_t P_o
  //               0   1   2  3  4  5   6   7  8  9  10  11  12
  // -----------------------------------------------------------------------
  reg [3:0] char_idx;

  always @(*) begin
    case (char_slot)
      4'd0:    char_idx = (A_tens != 4'd0) ? A_tens : CH_SP;
      4'd1:    char_idx = A_ones;
      4'd2:    char_idx = CH_SP;
      4'd3:    char_idx = CH_MUL;
      4'd4:    char_idx = CH_SP;
      4'd5:    char_idx = (B_tens != 4'd0) ? B_tens : CH_SP;
      4'd6:    char_idx = B_ones;
      4'd7:    char_idx = CH_SP;
      4'd8:    char_idx = CH_EQ;
      4'd9:    char_idx = CH_SP;
      4'd10:   char_idx = (P_hundreds != 4'd0) ? P_hundreds : CH_SP;
      4'd11:   char_idx = (P_hundreds != 4'd0 || P_tens != 4'd0) ? P_tens : CH_SP;
      4'd12:   char_idx = P_ones;
      default: char_idx = CH_SP;
    endcase
  end

  // Colour category per slot: 0 = A (red), 1 = B (blue), 2 = P (green), 3 = op (white)
  reg [1:0] char_color;

  always @(*) begin
    case (char_slot)
      4'd0, 4'd1:            char_color = 2'd0;
      4'd3:                   char_color = 2'd3;
      4'd5, 4'd6:            char_color = 2'd1;
      4'd8:                   char_color = 2'd3;
      4'd10, 4'd11, 4'd12:   char_color = 2'd2;
      default:                char_color = 2'd3;
    endcase
  end

  // -----------------------------------------------------------------------
  // 8×8 bitmap font ROM (digits 0-9, ×, =, space)
  // -----------------------------------------------------------------------
  reg [7:0] font_data;  
  wire       pixel_on  = in_text & font_data[3'd7 - font_col];
 
	always @(*) begin
      case ({char_idx, font_row})
        {4'd0, 3'd0}: font_data = 8'h3C;
        {4'd0, 3'd1}: font_data = 8'h66;
        {4'd0, 3'd2}: font_data = 8'h6E;
        {4'd0, 3'd3}: font_data = 8'h76;
        {4'd0, 3'd4}: font_data = 8'h66;
        {4'd0, 3'd5}: font_data = 8'h66;
        {4'd0, 3'd6}: font_data = 8'h3C;
        {4'd0, 3'd7}: font_data = 8'h00;

        {4'd1, 3'd0}: font_data = 8'h18;
        {4'd1, 3'd1}: font_data = 8'h38;
        {4'd1, 3'd2}: font_data = 8'h18;
        {4'd1, 3'd3}: font_data = 8'h18;
        {4'd1, 3'd4}: font_data = 8'h18;
        {4'd1, 3'd5}: font_data = 8'h18;
        {4'd1, 3'd6}: font_data = 8'h7E;
        {4'd1, 3'd7}: font_data = 8'h00;

        {4'd2, 3'd0}: font_data = 8'h3C;
        {4'd2, 3'd1}: font_data = 8'h66;
        {4'd2, 3'd2}: font_data = 8'h06;
        {4'd2, 3'd3}: font_data = 8'h1C;
        {4'd2, 3'd4}: font_data = 8'h30;
        {4'd2, 3'd5}: font_data = 8'h66;
        {4'd2, 3'd6}: font_data = 8'h7E;
        {4'd2, 3'd7}: font_data = 8'h00;

        {4'd3, 3'd0}: font_data = 8'h3C;
        {4'd3, 3'd1}: font_data = 8'h66;
        {4'd3, 3'd2}: font_data = 8'h06;
        {4'd3, 3'd3}: font_data = 8'h1C;
        {4'd3, 3'd4}: font_data = 8'h06;
        {4'd3, 3'd5}: font_data = 8'h66;
        {4'd3, 3'd6}: font_data = 8'h3C;
        {4'd3, 3'd7}: font_data = 8'h00;

        {4'd4, 3'd0}: font_data = 8'h0C;
        {4'd4, 3'd1}: font_data = 8'h1C;
        {4'd4, 3'd2}: font_data = 8'h2C;
        {4'd4, 3'd3}: font_data = 8'h4C;
        {4'd4, 3'd4}: font_data = 8'h7E;
        {4'd4, 3'd5}: font_data = 8'h0C;
        {4'd4, 3'd6}: font_data = 8'h0C;
        {4'd4, 3'd7}: font_data = 8'h00;

        {4'd5, 3'd0}: font_data = 8'h7E;
        {4'd5, 3'd1}: font_data = 8'h60;
        {4'd5, 3'd2}: font_data = 8'h7C;
        {4'd5, 3'd3}: font_data = 8'h06;
        {4'd5, 3'd4}: font_data = 8'h06;
        {4'd5, 3'd5}: font_data = 8'h66;
        {4'd5, 3'd6}: font_data = 8'h3C;
        {4'd5, 3'd7}: font_data = 8'h00;

        {4'd6, 3'd0}: font_data = 8'h3C;
        {4'd6, 3'd1}: font_data = 8'h66;
        {4'd6, 3'd2}: font_data = 8'h60;
        {4'd6, 3'd3}: font_data = 8'h7C;
        {4'd6, 3'd4}: font_data = 8'h66;
        {4'd6, 3'd5}: font_data = 8'h66;
        {4'd6, 3'd6}: font_data = 8'h3C;
        {4'd6, 3'd7}: font_data = 8'h00;

        {4'd7, 3'd0}: font_data = 8'h7E;
        {4'd7, 3'd1}: font_data = 8'h66;
        {4'd7, 3'd2}: font_data = 8'h06;
        {4'd7, 3'd3}: font_data = 8'h0C;
        {4'd7, 3'd4}: font_data = 8'h18;
        {4'd7, 3'd5}: font_data = 8'h18;
        {4'd7, 3'd6}: font_data = 8'h18;
        {4'd7, 3'd7}: font_data = 8'h00;

        {4'd8, 3'd0}: font_data = 8'h3C;
        {4'd8, 3'd1}: font_data = 8'h66;
        {4'd8, 3'd2}: font_data = 8'h66;
        {4'd8, 3'd3}: font_data = 8'h3C;
        {4'd8, 3'd4}: font_data = 8'h66;
        {4'd8, 3'd5}: font_data = 8'h66;
        {4'd8, 3'd6}: font_data = 8'h3C;
        {4'd8, 3'd7}: font_data = 8'h00;

        {4'd9, 3'd0}: font_data = 8'h3C;
        {4'd9, 3'd1}: font_data = 8'h66;
        {4'd9, 3'd2}: font_data = 8'h66;
        {4'd9, 3'd3}: font_data = 8'h3E;
        {4'd9, 3'd4}: font_data = 8'h06;
        {4'd9, 3'd5}: font_data = 8'h66;
        {4'd9, 3'd6}: font_data = 8'h3C;
        {4'd9, 3'd7}: font_data = 8'h00;

        {4'd10, 3'd0}: font_data = 8'h00;  // '×'
        {4'd10, 3'd1}: font_data = 8'h66;
        {4'd10, 3'd2}: font_data = 8'h3C;
        {4'd10, 3'd3}: font_data = 8'h18;
        {4'd10, 3'd4}: font_data = 8'h3C;
        {4'd10, 3'd5}: font_data = 8'h66;
        {4'd10, 3'd6}: font_data = 8'h00;
        {4'd10, 3'd7}: font_data = 8'h00;

        {4'd11, 3'd0}: font_data = 8'h00;  // '='
        {4'd11, 3'd1}: font_data = 8'h00;
        {4'd11, 3'd2}: font_data = 8'h7E;
        {4'd11, 3'd3}: font_data = 8'h00;
        {4'd11, 3'd4}: font_data = 8'h7E;
        {4'd11, 3'd5}: font_data = 8'h00;
        {4'd11, 3'd6}: font_data = 8'h00;
        {4'd11, 3'd7}: font_data = 8'h00;

        default: font_data = 8'h00;         // space + any unused index
      endcase
    end 

  // -----------------------------------------------------------------------
  // Pixel colour
  // -----------------------------------------------------------------------
  reg [1:0] R, G, B;

  always @(posedge clk) begin
    if (!display_on) begin R <= 2'b00; G <= 2'b00; B <= 2'b00; end
    else if (pixel_on) begin
      case (char_color)
        2'd0:    begin R <= 2'b11; G <= 2'b00; B <= 2'b00; end
        2'd1:    begin R <= 2'b00; G <= 2'b00; B <= 2'b11; end
        2'd2:    begin R <= 2'b00; G <= 2'b11; B <= 2'b00; end
        default: begin R <= 2'b11; G <= 2'b11; B <= 2'b11; end
      endcase
    end
    else if (in_border)     begin R <= 2'b01; G <= 2'b01; B <= 2'b10; end
    else if (in_card)       begin R <= 2'b00; G <= 2'b00; B <= 2'b01; end
	
    else if (in_mul_array0_partial) begin R <= 2'b00; G <= 2'b11; B <= 2'b01; end
    else if (in_mul_array1_partial) begin R <= 2'b00; G <= 2'b00; B <= 2'b10; end
    else if (in_mul_array2_partial) begin R <= 2'b10; G <= 2'b00; B <= 2'b11; end
    else if (in_mul_array3_partial) begin R <= 2'b10; G <= 2'b10; B <= 2'b11; end
    else if (in_mul_array4_partial) begin R <= 2'b10; G <= 2'b11; B <= 2'b10; end
    else if (in_mul_array5_partial) begin R <= 2'b10; G <= 2'b11; B <= 2'b11; end
    else if (in_mul_array6_partial) begin R <= 2'b11; G <= 2'b11; B <= 2'b11; end 
	else if (in_mul_array_line) begin R <= 2'b11; G <= 2'b11; B <= 2'b11; end 
	else if (logo_pixels) begin R <= pixel_color[7:6]; G <= pixel_color[5:4]; B <= pixel_color[3:2]; end 
    else                    begin R <= 2'b00; G <= 2'b00; B <= 2'b00; end
  end

  // -----------------------------------------------------------------------
  // Tiny VGA PMOD output
  // -----------------------------------------------------------------------
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}; 

  wire _unused = &{ena, uio_in[7:0], 1'b0, tx[9], ty[9:5], tx[1:0], ty[1:0]};

endmodule