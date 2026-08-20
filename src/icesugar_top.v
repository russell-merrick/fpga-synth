// IceSugar-Pro board wrapper for the Go Board synth.
// Same SynthTop design; RGB LED heartbeat proves the bitstream is running.
// I2S DAC (PMOD I2S2) on P4 HDMI-end outer row: E4 D4 D5 R7 (IceSugar pinmap).

module icesugar_top (
    input  CLK,
    input  RX,
    output TX,
    output led_r,
    output led_g,
    output led_b,
    output PMOD1,
    output PMOD2,
    output PMOD3,
    output PMOD4
);

  wire w_LED1;
  wire w_LED2;
  wire w_LED3;
  wire w_LED4;

  SynthTop u_synth (
    .CLK   (CLK),
    .RX    (RX),
    .TX    (TX),
    .LED1  (w_LED1),
    .LED2  (w_LED2),
    .LED3  (w_LED3),
    .LED4  (w_LED4),
    .PMOD1 (PMOD1),
    .PMOD2 (PMOD2),
    .PMOD3 (PMOD3),
    .PMOD4 (PMOD4)
  );

  // ~1.5 Hz heartbeat on green. RGB is active-high (common cathode).
  reg [23:0] r_hb = 24'd0;

  always @(posedge CLK)
  begin
    r_hb <= r_hb + 24'd1;
  end

  assign led_g = r_hb[23];
  assign led_r = w_LED1;  // gate (on at idle — A4 is sounding)
  assign led_b = 1'b0;

endmodule
