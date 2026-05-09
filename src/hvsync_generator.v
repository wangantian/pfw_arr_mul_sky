/*
 * VGA Horizontal/Vertical Sync Generator
 * 640x480 @ 60Hz, requires 25MHz clock
 * SPDX-License-Identifier: Apache-2.0
 *
 * Timing (from VGA spec):
 *   Horizontal: 640 visible + 16 front porch + 96 sync + 48 back porch = 800 total
 *   Vertical:   480 visible + 10 front porch +  2 sync + 33 back porch = 525 total
 */

`default_nettype none

module hvsync_generator (
    input  wire       clk,
    input  wire       reset,
    output wire       hsync,
    output wire       vsync,
    output wire       display_on,
    output wire [9:0] hpos,
    output wire [9:0] vpos
);

  // Horizontal timing constants
  localparam H_DISPLAY   = 640;
  localparam H_FRONT     = 16;
  localparam H_SYNC      = 96;
  localparam H_BACK      = 48;
  localparam H_TOTAL     = H_DISPLAY + H_FRONT + H_SYNC + H_BACK; // 800

  // Vertical timing constants
  localparam V_DISPLAY   = 480;
  localparam V_FRONT     = 10;
  localparam V_SYNC      = 2;
  localparam V_BACK      = 33;
  localparam V_TOTAL     = V_DISPLAY + V_FRONT + V_SYNC + V_BACK; // 525

  reg [9:0] h_count;
  reg [9:0] v_count;

  // Horizontal counter
  always @(posedge clk) begin
    if (reset) begin
      h_count <= 0;
    end else if (h_count == H_TOTAL - 1) begin
      h_count <= 0;
    end else begin
      h_count <= h_count + 1;
    end
  end

  // Vertical counter
  always @(posedge clk) begin
    if (reset) begin
      v_count <= 0;
    end else if (h_count == H_TOTAL - 1) begin
      if (v_count == V_TOTAL - 1)
        v_count <= 0;
      else
        v_count <= v_count + 1;
    end
  end

  // Sync signals (active low)
  assign hsync      = ~(h_count >= H_DISPLAY + H_FRONT &&
                        h_count <  H_DISPLAY + H_FRONT + H_SYNC);
  assign vsync      = ~(v_count >= V_DISPLAY + V_FRONT &&
                        v_count <  V_DISPLAY + V_FRONT + V_SYNC);

  assign display_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
  assign hpos       = h_count;
  assign vpos       = v_count;

endmodule
