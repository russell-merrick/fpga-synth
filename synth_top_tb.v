// Self-checking testbench for SynthTop (UART-controlled synth)
// Run with: apio test
//
`include "constants.vh"
// Checks:
//   1. MCLK period  = 2 CLK cycles  (12.5 MHz)
//   2. SCLK period  = 8 CLK cycles  (3.125 MHz)
//   3. LRCK period  = 512 CLK cycles (48.828 kHz)
//   4. UART 'a' → C4 selected, gate high
//   5. UART 'x' → octave increments
//   6. UART 'z' → octave decrements
//   7. UART 'h' → A4, I2S sample is 0x7FFF or 0x8000 (square wave)
//   8. UART ' ' → gate toggles off/on
//   9. UART 'k' → C + r_high flag, cleared by next note key
`timescale 1ns/1ps

module synth_top_tb;

  localparam CLK_PERIOD  = 40;              // ns — 25 MHz sim clock
  localparam CLKS_PER_BIT = `CLKS_PER_BIT; // from constants.vh

  reg CLK = 0;
  reg RX  = 1;   // UART idle high

  always #(CLK_PERIOD/2) CLK = ~CLK;

  wire TX, LED1, LED2, LED3, LED4;
  wire PMOD1, PMOD2, PMOD3, PMOD4;

  wire MCLK  = PMOD1;
  wire LRCK  = PMOD2;
  wire SCLK  = PMOD3;
  wire SDATA = PMOD4;

  SynthTop dut (
    .CLK(CLK), .RX(RX), .TX(TX),
    .LED1(LED1), .LED2(LED2), .LED3(LED3), .LED4(LED4),
    .PMOD1(PMOD1), .PMOD2(PMOD2), .PMOD3(PMOD3), .PMOD4(PMOD4)
  );

  // ── Test infrastructure ─────────────────────────────────────────────────────
  integer fail_count = 0;

  task pass_fail;
    input      ok;
    input [8*48-1:0] name;
    begin
      if (ok) $display("  PASS: %0s", name);
      else  begin
        $display("  FAIL: %0s", name);
        fail_count = fail_count + 1;
      end
    end
  endtask

  // ── UART bit-bang task ──────────────────────────────────────────────────────
  task send_byte;
    input [7:0] b;
    integer i;
    begin
      RX = 0;                                          // start bit
      repeat(CLKS_PER_BIT) @(posedge CLK);
      for (i = 0; i < 8; i = i + 1) begin
        RX = b[i];                                     // LSB first
        repeat(CLKS_PER_BIT) @(posedge CLK);
      end
      RX = 1;                                          // stop bit
      repeat(CLKS_PER_BIT) @(posedge CLK);
      repeat(CLKS_PER_BIT) @(posedge CLK);            // inter-byte gap
    end
  endtask

  // Capture 16-bit left-channel I2S word starting from LRCK falling edge.
  // Standard I2S: first SCLK rise after LRCK fall is the delay bit (skip it),
  // then MSB-first on the following 16 SCLK rising edges.
  task capture_left_sample;
    output [15:0] sample;
    integer j;
    begin
      @(negedge LRCK);
      @(posedge SCLK);           // delay bit — skip
      sample = 0;
      for (j = 0; j < 16; j = j + 1) begin
        @(posedge SCLK);
        sample = {sample[14:0], SDATA};
      end
    end
  endtask

  // ── Helpers ─────────────────────────────────────────────────────────────────
  integer      t1, t2, period_clks;
  reg [15:0]   captured_sample;

  // ── Tests ───────────────────────────────────────────────────────────────────
  initial begin
    $dumpvars(0, synth_top_tb);
    $display("=== SynthTop Testbench ===");

    repeat(500) @(posedge CLK);   // let counter settle

    // ── 1. MCLK period ────────────────────────────────────────────────────────
    @(posedge MCLK); t1 = $time;
    @(posedge MCLK); t2 = $time;
    period_clks = (t2 - t1) / CLK_PERIOD;
    pass_fail(period_clks == 2, "MCLK period = 2 CLK cycles (12.5 MHz)");

    // ── 2. SCLK period ────────────────────────────────────────────────────────
    @(posedge SCLK); t1 = $time;
    @(posedge SCLK); t2 = $time;
    period_clks = (t2 - t1) / CLK_PERIOD;
    pass_fail(period_clks == 8, "SCLK period = 8 CLK cycles (3.125 MHz)");

    // ── 3. LRCK period ────────────────────────────────────────────────────────
    @(posedge LRCK); t1 = $time;
    @(posedge LRCK); t2 = $time;
    period_clks = (t2 - t1) / CLK_PERIOD;
    pass_fail(period_clks == 512, "LRCK period = 512 CLK cycles (48.828 kHz)");

    // ── 4. 'a' → C4, gate on ─────────────────────────────────────────────────
    send_byte(8'h61);   // 'a'
    repeat(600) @(posedge CLK);
    pass_fail(dut.r_note == 4'd0 && dut.r_gate == 1'b1,
              "UART 'a' -> note=C, gate=1");

    // ── 5. 'x' → octave up ───────────────────────────────────────────────────
    send_byte(8'h78);   // 'x'
    repeat(600) @(posedge CLK);
    pass_fail(dut.r_octave == 3'd5, "UART 'x' -> octave 5");

    // ── 6. 'z' → octave down ─────────────────────────────────────────────────
    send_byte(8'h7A);   // 'z'
    repeat(600) @(posedge CLK);
    pass_fail(dut.r_octave == 3'd4, "UART 'z' -> octave 4");

    // ── 7. 'h' → A4, I2S sample is valid square wave value ───────────────────
    send_byte(8'h68);   // 'h' → A
    capture_left_sample(captured_sample);
    pass_fail(captured_sample == 16'h7FFF || captured_sample == 16'h8000,
              "UART 'h' -> A4, I2S sample = 0x7FFF or 0x8000");

    // ── 8. space → gate toggle ────────────────────────────────────────────────
    send_byte(8'h20);   // space
    repeat(600) @(posedge CLK);
    pass_fail(dut.r_gate == 1'b0, "UART space -> gate off");

    send_byte(8'h20);   // space again
    repeat(600) @(posedge CLK);
    pass_fail(dut.r_gate == 1'b1, "UART space x2 -> gate on");

    // ── 9. 'k' sets r_high; next note clears it ───────────────────────────────
    send_byte(8'h6B);   // 'k'
    repeat(600) @(posedge CLK);
    pass_fail(dut.r_note == 4'd0 && dut.r_high == 1'b1,
              "UART 'k' -> note=C, r_high=1");

    send_byte(8'h73);   // 's' → D
    repeat(600) @(posedge CLK);
    pass_fail(dut.r_note == 4'd2 && dut.r_high == 1'b0,
              "UART 's' after 'k' -> note=D, r_high=0");

    // ── Summary ───────────────────────────────────────────────────────────────
    $display("==========================");
    if (fail_count == 0)
      $display("ALL TESTS PASSED");
    else
      $display("%0d TEST(S) FAILED", fail_count);
    $display("==========================");
    $finish;
  end

  // Watchdog: bail after 30M simulated clock cycles
  initial begin
    repeat(30_000_000) @(posedge CLK);
    $display("FAIL: simulation timeout");
    $finish;
  end

endmodule
