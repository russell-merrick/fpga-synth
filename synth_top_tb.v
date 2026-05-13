// Self-checking testbench for SynthTop
// Run with: apio test
//
// Checks:
//   1. MCLK period  = 2 CLK cycles  (12.5 MHz)
//   2. SCLK period  = 8 CLK cycles  (3.125 MHz)
//   3. LRCK period  = 512 CLK cycles (48.828 kHz)
//   4. I2S framing  — bits captured on SCLK rising edges match 440 Hz square wave values
//   5. SW1 toggle   — pressing SW1 silences the output (sample goes to 0)
`timescale 1ns/1ps

module synth_top_tb;

  localparam CLK_PERIOD = 40;  // ns, 25 MHz

  reg CLK = 0;
  reg SW1 = 1;  // active low, starts released

  always #(CLK_PERIOD/2) CLK = ~CLK;

  wire LED1, LED2, LED3, LED4;
  wire PMOD1, PMOD2, PMOD3, PMOD4;

  wire MCLK  = PMOD1;
  wire LRCK  = PMOD2;
  wire SCLK  = PMOD3;
  wire SDATA = PMOD4;

  SynthTop uut (
    .CLK(CLK), .SW1(SW1),
    .LED1(LED1), .LED2(LED2), .LED3(LED3), .LED4(LED4),
    .PMOD1(PMOD1), .PMOD2(PMOD2), .PMOD3(PMOD3), .PMOD4(PMOD4)
  );

  // -------------------------------------------------------------------------
  // Test infrastructure
  // -------------------------------------------------------------------------
  integer fail_count = 0;

  task pass_fail;
    input      ok;
    input [8*40-1:0] name;
    begin
      if (ok) $display("  PASS: %0s", name);
      else  begin
             $display("  FAIL: %0s", name);
             fail_count = fail_count + 1;
           end
    end
  endtask

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  integer t1, t2, period_clks;
  integer i;
  reg [15:0] captured_sample;

  // Capture one full 16-bit I2S audio word from the left channel.
  // Called immediately after negedge LRCK.
  // Standard I2S: 1-bit delay after LRCK, then MSB first on SCLK rising edge.
  task capture_left_channel_sample;
    output [15:0] sample;
    integer j;
    begin
      @(posedge SCLK);  // rising edge during bit_pos=0 (the delay bit) — skip it
      sample = 0;
      for (j = 0; j < 16; j = j + 1)
      begin
        @(posedge SCLK);
        sample = {sample[14:0], SDATA};
      end
    end
  endtask

  // -------------------------------------------------------------------------
  // Tests
  // -------------------------------------------------------------------------
  initial
  begin
    $dumpvars(0, synth_top_tb);
    $display("=== SynthTop Testbench ===");

    // Let the counter settle for a couple of CLK cycles
    @(posedge CLK);
    @(posedge CLK);

    // --- Test 1: MCLK period ---
    @(posedge MCLK); t1 = $time;
    @(posedge MCLK); t2 = $time;
    period_clks = (t2 - t1) / CLK_PERIOD;
    pass_fail(period_clks == 2, "MCLK period = 2 CLK cycles (12.5 MHz)");

    // --- Test 2: SCLK period ---
    @(posedge SCLK); t1 = $time;
    @(posedge SCLK); t2 = $time;
    period_clks = (t2 - t1) / CLK_PERIOD;
    pass_fail(period_clks == 8, "SCLK period = 8 CLK cycles (3.125 MHz)");

    // --- Test 3: LRCK period ---
    @(posedge LRCK); t1 = $time;
    @(posedge LRCK); t2 = $time;
    period_clks = (t2 - t1) / CLK_PERIOD;
    pass_fail(period_clks == 512, "LRCK period = 512 CLK cycles (48.828 kHz)");

    // --- Test 4: I2S framing — audio word matches 440 Hz square wave ---
    @(negedge LRCK);
    capture_left_channel_sample(captured_sample);
    pass_fail(
      captured_sample == 16'h1FFF || captured_sample == 16'hE001,
      "I2S sample = valid 440 Hz square wave value (0x1FFF or 0xE001)"
    );

    // --- Test 5: SW1 silences the tone ---
    // Press SW1 (drive low) long enough for edge detection, then release
    repeat(4) @(posedge CLK);
    SW1 = 0;
    repeat(10) @(posedge CLK);
    SW1 = 1;

    // Wait two full LRCK frames for tone_enable to propagate to audio_sample
    @(negedge LRCK);
    @(negedge LRCK);
    capture_left_channel_sample(captured_sample);
    pass_fail(captured_sample == 16'h0000, "SW1 press silences output (sample = 0x0000)");

    // -----------------------------------------------------------------------
    $display("==========================");
    if (fail_count == 0)
      $display("ALL TESTS PASSED");
    else
      $display("%0d TEST(S) FAILED", fail_count);
    $display("==========================");

    $finish;
  end

endmodule
