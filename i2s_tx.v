// I2S transmitter — generates all I2S clocks and serializes one 16-bit sample per frame.
// o_DV pulses for one CLK cycle on each LRCK falling edge; the upstream voice module
// uses this to advance its phase accumulator and present the next sample.
`include "constants.vh"

module i2s_tx (
    input        i_CLK,
    input  [15:0] i_sample,
    output        o_MCLK,
    output        o_LRCK,
    output        o_SCLK,
    output        o_SDATA,
    output        o_DV
);

  reg [31:0] r_ctr = 32'd0;
  always @(posedge i_CLK) r_ctr <= r_ctr + 32'd1;

  assign o_MCLK = r_ctr[`MCLK_BIT];
  assign o_SCLK = r_ctr[`SCLK_BIT];
  wire   w_lrck = r_ctr[`LRCK_BIT];
  assign o_LRCK = w_lrck;

  reg r_lrck_d = 1'b0;
  reg r_sclk_d = 1'b0;
  always @(posedge i_CLK) begin
    r_lrck_d <= w_lrck;
    r_sclk_d <= r_ctr[`SCLK_BIT];
  end
  wire w_lrck_fall = r_lrck_d & ~w_lrck;
  wire w_lrck_edge = r_lrck_d ^ w_lrck;
  wire w_sclk_fall = r_sclk_d & ~r_ctr[`SCLK_BIT];

  // Counts SCLK falling edges within each LRCK half-period; resets on every LRCK edge.
  reg [4:0] r_bit_pos = 5'd0;
  always @(posedge i_CLK) begin
    if (w_lrck_edge) begin
      r_bit_pos <= 5'd0;
    end else if (w_sclk_fall) begin
      r_bit_pos <= r_bit_pos + 5'd1;
    end
  end

  // Standard I2S: 1-bit delay after LRCK transition, then 16 bits MSB-first.
  assign o_SDATA = (r_bit_pos >= 5'd1 && r_bit_pos <= 5'd16)
                 ? i_sample[16 - r_bit_pos] : 1'b0;

  assign o_DV = w_lrck_fall;

endmodule
