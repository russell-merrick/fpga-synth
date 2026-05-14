// FPGA Synthesizer — top level
// Nandland Go Board (iCE40 HX1K, 25 MHz)
`include "constants.vh"

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

  uart_top u_uart (
    .CLK         (CLK),
    .i_RX_Serial (RX),
    .o_TX_Serial (TX),
    .i_TX_DV     (1'b0),
    .i_TX_Byte   (8'h00),
    .o_note      (w_note),
    .o_octave    (w_octave),
    .o_gate      (w_gate),
    .o_high      (w_high)
  );

  wire [15:0] w_sample;
  wire        w_DV;

  voice u_voice (
    .CLK      (CLK),
    .i_note   (w_note),
    .i_octave (w_octave),
    .i_gate   (w_gate),
    .i_high   (w_high),
    .i_DV     (w_DV),
    .o_sample (w_sample)
  );

  i2s_tx u_i2s (
    .CLK      (CLK),
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
