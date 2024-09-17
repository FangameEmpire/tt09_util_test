/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Sync and pixel coordinate generator
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // Pong image generator
  wire draw_pong;
  reg [7:0] score_L, score_R;
  Pong_Generator pong_game (clk, ~rst_n, vsync, pix_x, pix_y, ui_in[3:0], ui_in[4], draw_pong, score_L, score_R);

  // Drive color bits
  assign R = video_active ? {2{draw_pong}} : 2'b00;
  assign G = video_active ? {2{draw_pong}} : 2'b00;
  assign B = video_active ? {2{draw_pong}} : 2'b00;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in[7:5], score_L, score_R};

endmodule
