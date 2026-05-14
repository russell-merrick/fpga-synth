// Self-checking testbench for i2s_tx
// Run with: apio test
//
// Tests:
//   1. MCLK period  = 2 CLK cycles  (12.5 MHz)
//   2. SCLK period  = 8 CLK cycles  (3.125 MHz)
//   3. LRCK period  = 512 CLK cycles (48.828 kHz)
//   4. o_DV fires when LRCK is low (coincides with LRCK falling edge)
//   5. o_DV is one CLK cycle wide
//   6. Left channel SDATA matches i_sample (1-bit I2S delay, MSB-first)
//   7. Right channel SDATA matches i_sample (mono — same sample both channels)
`include "constants.vh"
`timescale 1ns/1ps

module i2s_tx_tb;

  localparam CLK_PERIOD = 40;   // ns — 25 MHz sim clock
  localparam TB_NAME    = "i2s_tx Testbench";

  reg        CLK      = 1'b0;
  reg [15:0] i_sample = 16'h0000;

  wire o_MCLK, o_LRCK, o_SCLK, o_SDATA, o_DV;

  always #(CLK_PERIOD/2) CLK = ~CLK;

  i2s_tx dut (
    .i_CLK   (CLK),
    .i_sample(i_sample),
    .o_MCLK  (o_MCLK),
    .o_LRCK  (o_LRCK),
    .o_SCLK  (o_SCLK),
    .o_SDATA (o_SDATA),
    .o_DV    (o_DV)
  );

  // ── Test infrastructure ──────────────────────────────────────────────────────
  `include "test_utils.vh"

  // Capture one 16-bit I2S word from the left channel (starts at LRCK fall).
  // Standard I2S: skip 1 delay bit, then sample MSB-first on SCLK rising edges.
  task capture_left;
    output [15:0] sample;
    integer j;
    begin
      @(negedge o_LRCK);
      @(posedge o_SCLK);          // delay bit — skip
      sample = 16'd0;
      for (j = 0; j < 16; j = j + 1) begin
        @(posedge o_SCLK);
        sample = {sample[14:0], o_SDATA};
      end
    end
  endtask

  // Capture one 16-bit I2S word from the right channel (starts at LRCK rise).
  task capture_right;
    output [15:0] sample;
    integer j;
    begin
      @(posedge o_LRCK);
      @(posedge o_SCLK);          // delay bit — skip
      sample = 16'd0;
      for (j = 0; j < 16; j = j + 1) begin
        @(posedge o_SCLK);
        sample = {sample[14:0], o_SDATA};
      end
    end
  endtask

  // ── Helpers ──────────────────────────────────────────────────────────────────
  integer    t1, t2, period_clks;
  integer    dv_rise, dv_fall;
  reg [15:0] cap_left;
  reg [15:0] cap_right;

  // ── Tests ────────────────────────────────────────────────────────────────────
  initial begin
    $dumpvars(0, i2s_tx_tb);
    $display("=== %0s ===", TB_NAME);

    repeat(500) @(posedge CLK);   // let counter settle

    // ── 1. MCLK period ────────────────────────────────────────────────────────
    @(posedge o_MCLK); t1 = $time;
    @(posedge o_MCLK); t2 = $time;
    period_clks = (t2 - t1) / CLK_PERIOD;
    pass_fail(period_clks == 2, "MCLK period = 2 CLK cycles (12.5 MHz)");

    // ── 2. SCLK period ────────────────────────────────────────────────────────
    @(posedge o_SCLK); t1 = $time;
    @(posedge o_SCLK); t2 = $time;
    period_clks = (t2 - t1) / CLK_PERIOD;
    pass_fail(period_clks == 8, "SCLK period = 8 CLK cycles (3.125 MHz)");

    // ── 3. LRCK period ────────────────────────────────────────────────────────
    @(posedge o_LRCK); t1 = $time;
    @(posedge o_LRCK); t2 = $time;
    period_clks = (t2 - t1) / CLK_PERIOD;
    pass_fail(period_clks == 512, "LRCK period = 512 CLK cycles (48.828 kHz)");

    // ── 4. o_DV fires when LRCK is low (LRCK falling edge) ──────────────────
    // o_DV lags one combinational delta behind o_LRCK, so wait on posedge o_DV —
    // by then o_LRCK has already settled low.
    @(posedge o_DV);
    dv_rise = $time;
    pass_fail(o_LRCK == 1'b0, "o_DV fires when LRCK is low (LRCK fall)");

    // ── 5. o_DV is one CLK cycle wide ────────────────────────────────────────
    // Measure pulse width: negedge fires after r_lrck_d clears at the next CLK.
    // @(posedge CLK) catches delta 0 before NBAs settle; negedge o_DV is safe.
    @(negedge o_DV);
    dv_fall = $time;
    pass_fail((dv_fall - dv_rise) / CLK_PERIOD == 1, "o_DV one CLK cycle wide");

    // ── 6. Left channel SDATA matches i_sample ───────────────────────────────
    // 0xA5C3 = 1010_0101_1100_0011 — alternating pattern catches bit-order bugs
    i_sample = 16'hA5C3;
    capture_left(cap_left);
    pass_fail(cap_left == 16'hA5C3, "left channel SDATA = 0xA5C3");

    // ── 7. Right channel SDATA matches i_sample (mono) ───────────────────────
    // r_bit_pos resets on both LRCK edges, so right channel serializes i_sample
    // identically to left — correct behaviour for a mono source.
    capture_right(cap_right);
    pass_fail(cap_right == 16'hA5C3, "right channel SDATA = 0xA5C3 (mono)");

    // ── Summary ───────────────────────────────────────────────────────────────
    finish_test;
  end

  // Watchdog: bail after 5M simulated clock cycles
  initial begin
    repeat(5_000_000) @(posedge CLK);
    $display("FAIL: simulation timeout");
    $finish;
  end

endmodule
