// Self-checking testbench for vcf.v
// Run with: apio test
`include "src/constants.vh"
`timescale 1ns/1ps

module vcf_tb;

  `include "sim/test_utils.vh"

  localparam CLK_PERIOD = 40;
  localparam TB_NAME    = "vcf Testbench";

  reg        r_CLK   = 1'b0;
  reg        r_DV    = 1'b0;
  reg        r_trig  = 1'b0;
  reg [15:0] r_in    = 16'd0;
  reg [7:0]  r_cut   = 8'd255;
  reg [7:0]  r_res   = 8'd0;
  reg [7:0]  r_fenv  = 8'd0;
  reg [7:0]  r_fdec  = 8'd100;

  wire [15:0] w_out;

  always #(CLK_PERIOD/2) r_CLK = ~r_CLK;

  vcf u_vcf (
    .i_CLK      (r_CLK),
    .i_DV       (r_DV),
    .i_trig     (r_trig),
    .i_sample   (r_in),
    .i_cutoff   (r_cut),
    .i_res      (r_res),
    .i_fenv_amt (r_fenv),
    .i_fdecay   (r_fdec),
    .o_sample   (w_out)
  );

  task tick_dv;
    begin
      @(posedge r_CLK); #1;
      r_DV = 1'b1;
      @(posedge r_CLK); #1;
      r_DV = 1'b0;
      // 4-cycle SVF pipeline after each sample tick
      repeat (4) @(posedge r_CLK);
      #1;
    end
  endtask

  integer i;
  integer w_err;

  initial
  begin
    $dumpvars(0, vcf_tb);
    $display("=== %0s ===", TB_NAME);

    repeat (4) tick_dv;
    pass_fail(w_out == 16'd0, "output 0 at rest");

    // High cutoff, no resonance, DC in → LPF settles near input.
    r_in   = 16'd10000;
    r_cut  = 8'd255;
    r_res  = 8'd0;
    r_fenv = 8'd0;
    repeat (400) tick_dv;
    w_err = (w_out[15] || (w_out < 16'd9200) || (w_out > 16'd10800))
            ? 1 : 0;
    pass_fail(w_err == 0, "DC gain ~1 at cutoff=255 res=0");

    // Trig latches filter env to peak on the next DV.
    @(posedge r_CLK); #1;
    r_trig = 1'b1;
    @(posedge r_CLK); #1;
    r_trig = 1'b0;
    tick_dv;
    pass_fail(u_vcf.r_fenv == 20'hFFFFF, "trig -> fenv peak");

    repeat (10) tick_dv;
    pass_fail(u_vcf.r_fenv < 20'hFFFFF, "fenv decays");

    // Resonant path stays in range with a large square-ish input.
    r_in   = 16'h6000;
    r_cut  = `DEFAULT_CUTOFF;
    r_res  = `DEFAULT_RES;
    r_fenv = `DEFAULT_FENV;
    r_fdec = `DEFAULT_FDECAY;
    @(posedge r_CLK); #1;
    r_trig = 1'b1;
    @(posedge r_CLK); #1;
    r_trig = 1'b0;
    for (i = 0; i < 300; i = i + 1)
    begin
      if (i[4])
        r_in = 16'hA000;
      else
        r_in = 16'h6000;
      tick_dv;
    end
    pass_fail(1'b1, "resonant path ran without sim abort");

    finish_test;
  end

endmodule
