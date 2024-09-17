// VGA RTB Pong generator. Assumes a 1-cycle VSYNC is used for enable.
module Pong_Generator(clk, rst, en, pix_x, pix_y, player_buttons, draw_score, draw, score_L, score_R);
  // Port declarations
  input logic clk, rst, en;
  input logic [9:0] pix_x, pix_y;
  input logic [3:0] player_buttons;
  input logic draw_score;
  output logic draw;
  output logic [7:0] score_L, score_R;

  // User controls
  wire L_up, L_down, R_up, R_down;
  assign L_up   = player_buttons[0] & ~player_buttons[1];
  assign L_down = player_buttons[1] & ~player_buttons[0];
  assign R_up   = player_buttons[2] & ~player_buttons[3];
  assign R_down = player_buttons[3] & ~player_buttons[2];

  // Counter for slowdown
  reg[31:00] counter;
  always_ff @(posedge clk) begin
    if (rst)      counter <= 32'b0;
    else if (en)  counter <= counter + 32'h00000001;
    else          counter <= counter;
  end // always_ff @(posedge clk)

  // Ball location data
  localparam BALL_SIZE = 16;
  localparam BALL_HALF_SIZE = BALL_SIZE / 2;
  localparam VGA_H = 10'd640;
  localparam VGA_V = 10'd480;
  localparam VGA_H_MAX = VGA_H - 1;
  localparam VGA_V_MAX = VGA_V - 1;
  localparam VGA_H_MID = VGA_H_MAX / 2;
  localparam VGA_V_MID = VGA_V_MAX / 2;
  localparam LIM_H = VGA_H_MAX - BALL_SIZE;
  localparam LIM_V = VGA_V_MAX - BALL_SIZE;
  localparam RST_X = VGA_H_MID - BALL_HALF_SIZE;
  localparam RST_Y = VGA_V_MID - BALL_HALF_SIZE;
  reg [9:0] ball_x, ball_y;
  reg [1:0] ball_x_dir, ball_y_dir;
  reg center_ball, start_ball;

  // Ball location calculation
  wire move_ball;
  assign move_ball = (counter[6:0] == 0);
  always_ff @(posedge clk) begin
    if (rst) begin
      ball_x <= 0;
      ball_y <= 0;
    end else if (en & center_ball) begin
      ball_x <= RST_X;
      ball_y <= RST_Y;
    end else if (en & move_ball) begin
      if (ball_x_dir[1])      ball_x <= ball_x - 1;
      else if (ball_x_dir[0]) ball_x <= ball_x + 1;
      else                    ball_x <= ball_x;
      if (ball_y_dir[1])      ball_y <= ball_y - 1;
      else if (ball_y_dir[0]) ball_y <= ball_y + 1;
      else                    ball_y <= ball_y;
    end else begin
      ball_x <= ball_x;
      ball_y <= ball_y;
    end
  end // always_ff @(posedge clk)

  // Paddle location data
  localparam PADDLE_WIDTH = 16;
  localparam PADDLE_HEIGHT = 64;
  localparam PADDLE_LIM = VGA_V_MAX - PADDLE_HEIGHT;
  reg [9:0] paddle_L_ypos, paddle_R_ypos;
  
  // Ball direction calculation
  always_ff @(posedge clk) begin
    if (rst) begin
      ball_x_dir <= 0;
      ball_y_dir <= 0;
    end else if (en) begin
      // Compute X and Y direction separately to prevent corner edge case
      if (start_ball) begin
        ball_x_dir <= {counter[0], ~counter[0]};
      end else if (center_ball) begin
        ball_x_dir <= 2'b0;
      end else if ((ball_x == PADDLE_WIDTH) 
                 & (ball_y >= paddle_L_ypos - BALL_SIZE) 
                 & (ball_y < paddle_L_ypos + PADDLE_HEIGHT)) begin 
        ball_x_dir <= 2'b01;
      end else if ((ball_x == VGA_H_MAX - (PADDLE_WIDTH + BALL_SIZE)) 
                 & (ball_y >= paddle_R_ypos - BALL_SIZE) 
                 & (ball_y < paddle_R_ypos + PADDLE_HEIGHT)) begin 
        ball_x_dir <= 2'b10;
      end else begin
        ball_x_dir <= ball_x_dir;
      end

      if (start_ball) begin
        ball_y_dir <= {counter[1], ~counter[1]};
      end else if (center_ball) begin
        ball_y_dir <= 2'b0;
      end else if (ball_y == 10'b0) begin
        ball_y_dir <= 2'b01;
      end else if (ball_y == LIM_V) begin
        ball_y_dir <= 2'b10;
      end else begin
        ball_y_dir <= ball_y_dir;
      end
    end else begin
      ball_x_dir <= ball_x_dir;
      ball_y_dir <= ball_y_dir;
    end
  end // always_ff @(posedge clk)

  // Ball centering calculation
  localparam RESET_DELAY = 15;
  localparam RESET_FULL = {RESET_DELAY{1'b1}};
  reg [RESET_DELAY - 1:0] reset_counter;
  always_ff @(posedge clk) begin
    if (rst) begin
      reset_counter <= 0;
    end else if (en) begin
      if (center_ball) reset_counter <= 1;
      else if ((reset_counter != RESET_FULL) & (reset_counter != 0)) reset_counter <= reset_counter + 1;
      else reset_counter <= 0;
    end else begin
      reset_counter <= reset_counter;
    end

    start_ball <= (reset_counter == RESET_FULL);
  end // always_ff @(posedge clk)
  assign center_ball = (ball_x == 0) | (ball_x == LIM_H);

  // Draw ball
  wire draw_ball;
  assign draw_ball = (pix_x >= ball_x) & (pix_x < ball_x + BALL_SIZE)
                   & (pix_y >= ball_y) & (pix_y < ball_y + BALL_SIZE);

  // Draw net
  wire draw_net;
  assign draw_net = (pix_x >= VGA_H_MID - 2) & (pix_x < VGA_H_MID + 2) & ~pix_y[4];

  // Paddle location calculation
  wire move_paddle;
  assign move_paddle = (counter[5:0] == 0);
  always_ff @(posedge clk) begin
    if (rst) begin
      paddle_L_ypos <= 10'b0;
      paddle_R_ypos <= 10'b0;
    end else if (en & move_paddle) begin
      // Left paddle
      if (L_up & (paddle_L_ypos != 10'b0)) begin
        paddle_L_ypos <= paddle_L_ypos - 1;
      end else if (L_down & (paddle_L_ypos != PADDLE_LIM)) begin
        paddle_L_ypos <= paddle_L_ypos + 1;
      end else begin
        paddle_L_ypos <= paddle_L_ypos;
      end

      // Right paddle
      if (R_up & (paddle_R_ypos != 10'b0)) begin
        paddle_R_ypos <= paddle_R_ypos - 1;
      end else if (R_down & (paddle_R_ypos != PADDLE_LIM)) begin
        paddle_R_ypos <= paddle_R_ypos + 1;
      end else begin
        paddle_R_ypos <= paddle_R_ypos;
      end
    end else begin
      paddle_L_ypos <= paddle_L_ypos;
      paddle_R_ypos <= paddle_R_ypos;
    end
  end // always_ff @(posedge clk)

  // Draw paddle
  wire draw_paddle;
  assign draw_paddle = ((pix_x < PADDLE_WIDTH) 
                      & (pix_y >= paddle_L_ypos) & (pix_y < paddle_L_ypos + PADDLE_HEIGHT))
                      | ((pix_x >= VGA_H_MAX - PADDLE_WIDTH) & (pix_x < VGA_H_MAX) 
                      & (pix_y >= paddle_R_ypos) & (pix_y < paddle_R_ypos + PADDLE_HEIGHT));

  // Score tracking
  reg scoring_ready;
  always_ff @(posedge clk) begin
    if (rst) begin
      score_L <= 0;
      score_R <= 0;
      scoring_ready <= 0;
    end else if (en) begin
      if ((ball_x == 10'd0) & scoring_ready)  score_R <= score_R + 1;
      else                  score_R <= score_R;
      if ((ball_x == LIM_H) & scoring_ready)  score_L <= score_L + 1;
      else                  score_L <= score_L;
      if (start_ball)       scoring_ready <= 1'b1;
      else                  scoring_ready <= scoring_ready;
    end else begin
      score_L <= score_L;
      score_R <= score_R;
      scoring_ready <= scoring_ready;
    end
  end // always_ff @(posedge clk)
  
  // Score display
  localparam SCORE_WIDTH = 10'd16;
  localparam SCORE_Y_OFFSET = 10'd16;
  wire [3:0] draw_score_char;

  // 7-segment modules for score display
  VGA_7seg #(.ORIGIN_X(VGA_H_MID - 10'd10 * SCORE_WIDTH), .ORIGIN_Y(SCORE_Y_OFFSET), .WIDTH(SCORE_WIDTH)) 
  score_L1 (pix_x, pix_y, score_L[7:4], draw_score_char[3]);
  VGA_7seg #(.ORIGIN_X(VGA_H_MID - 10'd5 * SCORE_WIDTH), .ORIGIN_Y(SCORE_Y_OFFSET), .WIDTH(SCORE_WIDTH)) 
  score_L0 (pix_x, pix_y, score_L[3:0], draw_score_char[2]);
  VGA_7seg #(.ORIGIN_X(VGA_H_MID + 10'd1 * SCORE_WIDTH), .ORIGIN_Y(SCORE_Y_OFFSET), .WIDTH(SCORE_WIDTH)) 
  score_R1 (pix_x, pix_y, score_R[7:4], draw_score_char[1]);
  VGA_7seg #(.ORIGIN_X(VGA_H_MID + 10'd6 * SCORE_WIDTH), .ORIGIN_Y(SCORE_Y_OFFSET), .WIDTH(SCORE_WIDTH)) 
  score_R0 (pix_x, pix_y, score_R[3:0], draw_score_char[0]);
  
  // Combine all objects into draw signal;
  assign draw = ~rst & |{draw_ball, draw_net, draw_paddle, (|draw_score_char & draw_score)};

endmodule // Pong_Generator

// Draw a Hex character on the VGA display
module VGA_7seg #(parameter ORIGIN_X = 10'd0, ORIGIN_Y = 10'd0, WIDTH = 10'd16) (pix_x, pix_y, val, draw);
  input logic [9:0] pix_x, pix_y;
  input logic [3:0] val;
  output logic draw;

  // Convert character data to segments and corners
  wire [6:0] segments;
  wire [5:0] corners;

  hex_to_7seg segment_generator(val, segments);

  assign corners[0] = (segments[0] | segments[1]);
  assign corners[1] = (segments[1] | segments[2] | segments[6]);
  assign corners[2] = (segments[2] | segments[3]);
  assign corners[3] = (segments[3] | segments[4]);
  assign corners[4] = (segments[4] | segments[5] | segments[6]);
  assign corners[5] = (segments[0] | segments[5]);

  // Calculate which segment or corner is being drawn
  wire [6:0] draw_segments;
  wire [5:0] draw_corners;

  assign draw_segments[0] = (pix_x >= ORIGIN_X + WIDTH) & (pix_x < ORIGIN_X + 3 * WIDTH)
                          & (pix_y >= ORIGIN_Y) & (pix_y < ORIGIN_Y + WIDTH);
  assign draw_segments[1] = (pix_x >= ORIGIN_X + 3 * WIDTH) & (pix_x < ORIGIN_X + 4 * WIDTH)
                          & (pix_y >= ORIGIN_Y + WIDTH) & (pix_y < ORIGIN_Y + 3 * WIDTH);
  assign draw_segments[2] = (pix_x >= ORIGIN_X + 3 * WIDTH) & (pix_x < ORIGIN_X + 4 * WIDTH)
                          & (pix_y >= ORIGIN_Y + 4 * WIDTH) & (pix_y < ORIGIN_Y + 6 * WIDTH);
  assign draw_segments[3] = (pix_x >= ORIGIN_X + WIDTH) & (pix_x < ORIGIN_X + 3 * WIDTH)
                          & (pix_y >= ORIGIN_Y + 6 * WIDTH) & (pix_y < ORIGIN_Y + 7 * WIDTH);
  assign draw_segments[4] = (pix_x >= ORIGIN_X) & (pix_x < ORIGIN_X + 1 * WIDTH)
                          & (pix_y >= ORIGIN_Y + 4 * WIDTH) & (pix_y < ORIGIN_Y + 6 * WIDTH);
  assign draw_segments[5] = (pix_x >= ORIGIN_X) & (pix_x < ORIGIN_X + 1 * WIDTH)
                          & (pix_y >= ORIGIN_Y + WIDTH) & (pix_y < ORIGIN_Y + 3 * WIDTH);
  assign draw_segments[6] = (pix_x >= ORIGIN_X + WIDTH) & (pix_x < ORIGIN_X + 3 * WIDTH)
                          & (pix_y >= ORIGIN_Y + 3 * WIDTH) & (pix_y < ORIGIN_Y + 4 * WIDTH);

  assign draw_corners[0] = (pix_x >= ORIGIN_X + 3 * WIDTH) & (pix_x < ORIGIN_X + 4 * WIDTH)
                          & (pix_y >= ORIGIN_Y) & (pix_y < ORIGIN_Y + WIDTH);
  assign draw_corners[1] = (pix_x >= ORIGIN_X + 3 * WIDTH) & (pix_x < ORIGIN_X + 4 * WIDTH)
                          & (pix_y >= ORIGIN_Y + 3 * WIDTH) & (pix_y < ORIGIN_Y + 4 * WIDTH);
  assign draw_corners[2] = (pix_x >= ORIGIN_X + 3 * WIDTH) & (pix_x < ORIGIN_X + 4 * WIDTH)
                          & (pix_y >= ORIGIN_Y + 6 * WIDTH) & (pix_y < ORIGIN_Y + 7 * WIDTH);
  assign draw_corners[3] = (pix_x >= ORIGIN_X) & (pix_x < ORIGIN_X + WIDTH)
                          & (pix_y >= ORIGIN_Y + 6 * WIDTH) & (pix_y < ORIGIN_Y + 7 * WIDTH);
  assign draw_corners[4] = (pix_x >= ORIGIN_X) & (pix_x < ORIGIN_X + WIDTH)
                          & (pix_y >= ORIGIN_Y + 3 * WIDTH) & (pix_y < ORIGIN_Y + 4 * WIDTH);
  assign draw_corners[5] = (pix_x >= ORIGIN_X) & (pix_x < ORIGIN_X + WIDTH)
                          & (pix_y >= ORIGIN_Y) & (pix_y < ORIGIN_Y + WIDTH);
  
  // Combine segments and corners
  assign draw = |(segments & draw_segments) | |( corners & draw_corners);
endmodule // VGA_7seg

module hex_to_7seg(val, segments);
  input logic [3:0] val;
  output logic [6:0] segments;

  assign segments[0] = ~((val == 4'h1) | (val == 4'h4) | (val == 4'hb) | (val == 4'hd));
  assign segments[1] = ~((val == 4'h5) | (val == 4'h6) | (val == 4'hb) | (val == 4'hc) | (val == 4'he) | (val == 4'hf));
  assign segments[2] = ~((val == 4'h2) | (val == 4'hc) | (val == 4'he) | (val == 4'hf));
  assign segments[3] = ~((val == 4'h1) | (val == 4'h4) | (val == 4'h7) | (val == 4'ha) | (val == 4'hf));
  assign segments[4] = ~((val == 4'h1) | (val == 4'h3) | (val == 4'h4) | (val == 4'h5) | (val == 4'h7) | (val == 4'h9));
  assign segments[5] = ~((val == 4'h1) | (val == 4'h2) | (val == 4'h3) | (val == 4'h7) | (val == 4'hd));
  assign segments[6] = ~((val == 4'h0) | (val == 4'h1) | (val == 4'h7) | (val == 4'hc));
endmodule // hex_to_7seg
