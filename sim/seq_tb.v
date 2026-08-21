// seq.v — play, rest, step advance
`include "src/constants.vh"
`timescale 1ns/1ps

module seq_tb;

  `include "sim/test_utils.vh"

  localparam CLK_PERIOD = 40;
  localparam TB_NAME    = "seq Testbench";

  reg        r_CLK  = 1'b0;
  reg        r_DV   = 1'b0;
  reg        r_play = 1'b0;
  reg  [7:0] r_bpm  = 8'd120;
  reg  [4:0] r_len  = 5'd16;
  reg        r_we   = 1'b0;
  reg  [3:0] r_wa   = 4'd0;
  reg  [7:0] r_wd   = 8'd0;

  wire [3:0] w_note;
  wire       w_high;
  wire       w_gate;
  wire       w_acc;
  wire       w_sld;
  wire       w_trig;
  wire [3:0] w_step;

  always #(CLK_PERIOD/2) r_CLK = ~r_CLK;

  seq u_seq (
    .i_CLK    (r_CLK),
    .i_DV     (r_DV),
    .i_play   (r_play),
    .i_bpm    (r_bpm),
    .i_len    (r_len),
    .i_we     (r_we),
    .i_waddr  (r_wa),
    .i_wdata  (r_wd),
    .o_note   (w_note),
    .o_high   (w_high),
    .o_gate   (w_gate),
    .o_accent (w_acc),
    .o_slide  (w_sld),
    .o_trig   (w_trig),
    .o_step   (w_step)
  );

  task tick_dv;
    begin
      @(posedge r_CLK); #1;
      r_DV = 1'b1;
      @(posedge r_CLK); #1;
      r_DV = 1'b0;
    end
  endtask

  integer n;

  initial
  begin
    $dumpvars(0, seq_tb);
    $display("=== %0s ===", TB_NAME);

    repeat (4) @(posedge r_CLK);
    pass_fail(w_gate == 1'b0 && w_step == 4'd0, "idle gate off step 0");

    @(posedge r_CLK); #1;
    r_play = 1'b1;
    @(posedge r_CLK);
    @(negedge r_CLK);
    pass_fail(w_note == 4'd9 && w_gate == 1'b1, "play -> step0 A gated");

    r_len = 5'd2;
    r_bpm = 8'd240;
    for (n = 0; n < 4000; n = n + 1)
    begin
      tick_dv;
    end
    pass_fail(w_step != 4'd0, "after ticks step advanced");

    @(posedge r_CLK); #1;
    r_play = 1'b0;
    @(posedge r_CLK);
    @(negedge r_CLK);
    pass_fail(w_gate == 1'b0, "stop -> gate off");

    finish_test;
  end

endmodule
