// Self-checking testbench for adsr.v
// Run with: apio sim sim/adsr_tb.v
//
// Checks:
//   1. Envelope stays at 0 while gate is low (IDLE)
//   2. Envelope rises to 32767 (ATTACK)
//   3. Envelope decays to sustain level (DECAY)
//   4. Envelope holds at sustain while gate is high (SUSTAIN)
//   5. Envelope falls to 0 after gate falls (RELEASE)
//   6. Envelope stays at 0 (IDLE again)
`timescale 1ns/1ps

module adsr_tb;

  `include "sim/test_utils.vh"

  localparam CLK_PERIOD = 40;    // 25 MHz

  // Small rate values so simulation finishes quickly
  localparam ATK       = 8'd100;
  localparam DEC       = 8'd50;
  localparam SUS       = 8'd128;   // sustain level = 128 * 128 = 16384
  localparam REL       = 8'd80;

  localparam SUS_LEVEL = 16'd16384;

  reg r_CLK  = 1'b0;
  reg r_DV   = 1'b0;
  reg r_gate = 1'b0;

  wire [15:0] w_env;

  always #(CLK_PERIOD/2) r_CLK = ~r_CLK;

  adsr u_adsr (
    .i_CLK     (r_CLK),
    .i_DV      (r_DV),
    .i_gate    (r_gate),
    .i_attack  (ATK),
    .i_decay   (DEC),
    .i_sustain (SUS),
    .i_release (REL),
    .o_env     (w_env)
  );

  // Pulse DV high for one clock cycle.
  // The #1 delay places signal changes after the active-event region so the
  // ADSR's always block reliably samples the new DV value at the next posedge.
  task tick_dv;
    begin
      @(posedge r_CLK); #1;
      r_DV = 1'b1;
      @(posedge r_CLK); #1;
      r_DV = 1'b0;
    end
  endtask

  integer i;
  reg [15:0] r_last_env;

  initial
  begin
    $dumpvars(0, adsr_tb);
    $display("=== ADSR Testbench ===");

    // ── 1. Env stays 0 in IDLE ────────────────────────────────────────────────
    repeat(5) tick_dv;
    pass_fail(w_env == 16'd0, "Env = 0 before gate (IDLE)");

    // ── 2. Env rises to 32767 (ATTACK) ───────────────────────────────────────
    @(posedge r_CLK); #1;
    r_gate = 1'b1;
    // Tick until env peaks — stop as soon as env == 32767
    for (i = 0; i < 500 && w_env < 16'd32767; i = i + 1)
    begin
      tick_dv;
    end
    pass_fail(w_env == 16'd32767, "Env = 32767 at ATTACK peak");

    // ── 3. Env decays to sustain level (DECAY) ────────────────────────────────
    for (i = 0; i < 500 && w_env > SUS_LEVEL; i = i + 1)
    begin
      tick_dv;
    end
    pass_fail(w_env == SUS_LEVEL, "Env = sustain level after DECAY");

    // ── 4. Env holds at sustain (SUSTAIN) ─────────────────────────────────────
    r_last_env = w_env;
    repeat(50) tick_dv;
    pass_fail(w_env == SUS_LEVEL && w_env == r_last_env, "Env holds at sustain");

    // ── 5. Env falls to 0 (RELEASE) ──────────────────────────────────────────
    @(posedge r_CLK); #1;
    r_gate = 1'b0;
    for (i = 0; i < 500 && w_env > 16'd0; i = i + 1)
    begin
      tick_dv;
    end
    pass_fail(w_env == 16'd0, "Env = 0 after RELEASE");

    // ── 6. Stays at 0 in IDLE ────────────────────────────────────────────────
    repeat(20) tick_dv;
    pass_fail(w_env == 16'd0, "Env stays 0 in IDLE after release");

    finish_test;
  end

  // Watchdog
  initial
  begin
    #10_000_000;
    $display("FAIL: simulation timeout");
    $finish;
  end

endmodule
