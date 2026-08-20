// FPGA Synthesizer — top level
// Nandland Go Board (iCE40 HX1K, 25 MHz)
`include "src/constants.vh"

module SynthTop (
    input  CLK,
    input  RX,
    output TX,
    output LED1, LED2, LED3, LED4,
    output PMOD1,   // MCLK  12.5 MHz
    output PMOD2,   // LRCK  48.828 kHz
    output PMOD3,   // SCLK  3.125 MHz
    output PMOD4    // SDATA
);

  wire [3:0] w_note;
  wire [2:0] w_octave;
  wire       w_gate;
  wire       w_high;
  wire [1:0] w_wave;
  wire [3:0] w_v0_note;
  wire       w_v0_high;
  wire       w_v0_gate;
  wire [3:0] w_v1_note;
  wire       w_v1_high;
  wire       w_v1_gate;

  uart_top u_uart (
    .i_CLK       (CLK),
    .i_RX_Serial (RX),
    .o_TX_Serial (TX),
    .i_TX_DV     (1'b0),
    .i_TX_Byte   (8'h00),
    .o_note      (w_note),
    .o_octave    (w_octave),
    .o_gate      (w_gate),
    .o_high      (w_high),
    .o_wave      (w_wave),
    .o_v0_note   (w_v0_note),
    .o_v0_high   (w_v0_high),
    .o_v0_gate   (w_v0_gate),
    .o_v1_note   (w_v1_note),
    .o_v1_high   (w_v1_high),
    .o_v1_gate   (w_v1_gate)
  );

  wire [15:0] w_sample0;
  wire [15:0] w_sample1;
  wire        w_DV;

  voice u_voice0 (
    .i_CLK    (CLK),
    .i_note   (w_v0_note),
    .i_octave (w_octave),
    .i_gate   (w_v0_gate),
    .i_high   (w_v0_high),
    .i_wave   (w_wave),
    .i_DV     (w_DV),
    .o_sample (w_sample0)
  );

  generate
    if (`NUM_VOICES == 2)
    begin : g_poly
      voice u_voice1 (
        .i_CLK    (CLK),
        .i_note   (w_v1_note),
        .i_octave (w_octave),
        .i_gate   (w_v1_gate),
        .i_high   (w_v1_high),
        .i_wave   (w_wave),
        .i_DV     (w_DV),
        .o_sample (w_sample1)
      );
    end
    else
    begin : g_mono
      assign w_sample1 = 16'd0;
    end
  endgenerate

  wire signed [16:0] w_mix =
    $signed({w_sample0[15], w_sample0}) + $signed({w_sample1[15], w_sample1});
  wire [15:0] w_sample =
    (w_mix >  17'sd32767)  ? 16'h7FFF :
    (w_mix < -17'sd32768)  ? 16'h8000 :
    w_mix[15:0];

  i2s_tx u_i2s (
    .i_CLK    (CLK),
    .i_sample (w_sample),
    .o_MCLK   (PMOD1),
    .o_LRCK   (PMOD2),
    .o_SCLK   (PMOD3),
    .o_SDATA  (PMOD4),
    .o_DV     (w_DV)
  );

  assign LED1 = w_gate;
  assign LED2 = w_octave[0];
  assign LED3 = w_octave[1];
  assign LED4 = w_octave[2];

endmodule
