// FPGA Synthesizer — top level
// Nandland Go Board (iCE40 HX1K, 25 MHz)
//
// Instantiates uart_top for all UART / command handling.
// Phase accumulator oscillator and I2S output remain here
// until the audio side is split into osc.v and i2s_tx.v.
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

  // ── UART — all command handling ─────────────────────────────────────────────
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

  // ── I2S clock generation ────────────────────────────────────────────────────
  reg [31:0] r_ctr = 0;
  always @(posedge CLK) r_ctr <= r_ctr + 1;

  assign PMOD1 = r_ctr[`MCLK_BIT];
  assign PMOD3 = r_ctr[`SCLK_BIT];
  wire   w_lrck = r_ctr[`LRCK_BIT];
  assign PMOD2  = w_lrck;

  // LRCK / SCLK edge detection
  reg r_lrck_d = 0, r_sclk_d = 0;
  always @(posedge CLK) begin
    r_lrck_d <= w_lrck;
    r_sclk_d <= r_ctr[`SCLK_BIT];
  end
  wire w_lrck_fall = r_lrck_d & ~w_lrck;
  wire w_lrck_edge = r_lrck_d ^ w_lrck;
  wire w_sclk_fall = r_sclk_d & ~r_ctr[`SCLK_BIT];

  // ── I2S bit-position counter ────────────────────────────────────────────────
  // Counts SCLK falling edges within each LRCK half-period (0–31).
  // Resets on every LRCK edge so left and right channels both start at 0.
  reg [4:0] r_bit_pos = 0;
  always @(posedge CLK) begin
    if (w_lrck_edge)
      r_bit_pos <= 0;
    else if (w_sclk_fall)
      r_bit_pos <= r_bit_pos + 1;
  end

  // ── Phase accumulator oscillator ────────────────────────────────────────────
  // Base phase increments for octave 4: phase_inc = freq * 2^32 / 48828.125
  wire [31:0] w_base_inc =
    (w_note == 4'd0)  ? 32'd23_017_594 :  // C4  261.626 Hz
    (w_note == 4'd1)  ? 32'd24_386_283 :  // C#4 277.183 Hz
    (w_note == 4'd2)  ? 32'd25_836_353 :  // D4  293.665 Hz
    (w_note == 4'd3)  ? 32'd27_372_642 :  // D#4 311.127 Hz
    (w_note == 4'd4)  ? 32'd29_000_342 :  // E4  329.628 Hz
    (w_note == 4'd5)  ? 32'd30_724_730 :  // F4  349.228 Hz
    (w_note == 4'd6)  ? 32'd32_561_722 :  // F#4 369.994 Hz
    (w_note == 4'd7)  ? 32'd34_487_328 :  // G4  391.995 Hz
    (w_note == 4'd8)  ? 32'd36_538_119 :  // G#4 415.305 Hz
    (w_note == 4'd9)  ? 32'd38_710_760 :  // A4  440.000 Hz
    (w_note == 4'd10) ? 32'd41_012_643 :  // A#4 466.164 Hz
    (w_note == 4'd11) ? 32'd43_451_332 :  // B4  493.883 Hz
                        32'd38_710_760;   // default

  // 'k' bumps the effective octave by 1 (capped at 7)
  wire [2:0] w_oct = w_high && (w_octave < 3'd7) ? w_octave + 3'd1 : w_octave;

  // Shift base increment per octave (octave 4 = no shift)
  wire [31:0] w_phase_inc =
    (w_oct == 3'd0) ? (w_base_inc >> 4) :
    (w_oct == 3'd1) ? (w_base_inc >> 3) :
    (w_oct == 3'd2) ? (w_base_inc >> 2) :
    (w_oct == 3'd3) ? (w_base_inc >> 1) :
    (w_oct == 3'd4) ? (w_base_inc)      :
    (w_oct == 3'd5) ? (w_base_inc << 1) :
    (w_oct == 3'd6) ? (w_base_inc << 2) :
                      (w_base_inc << 3); // oct 7

  // Advance phase and latch audio sample every LRCK period (left channel start).
  // Non-blocking means r_sample captures the pre-advance phase (1-sample latency, inaudible).
  reg [31:0] r_phase  = 0;
  reg [15:0] r_sample = 0;

  always @(posedge CLK) begin
    if (w_lrck_fall) begin
      r_phase  <= r_phase + w_phase_inc;
      r_sample <= w_gate ? (r_phase[31] ? 16'h7FFF : 16'h8000) : 16'h0000;
    end
  end

  // ── I2S SDATA serialization ─────────────────────────────────────────────────
  // Standard I2S: 1-bit delay after LRCK transition, then 16 bits MSB-first,
  // then zero padding. Same formula confirmed working with CS4344 in this project.
  assign PMOD4 = (r_bit_pos >= 5'd1 && r_bit_pos <= 5'd16)
               ? r_sample[16 - r_bit_pos] : 1'b0;

  // ── LEDs ────────────────────────────────────────────────────────────────────
  assign LED1 = w_gate;
  assign LED2 = w_octave[0];
  assign LED3 = w_octave[1];
  assign LED4 = w_octave[2];

endmodule
