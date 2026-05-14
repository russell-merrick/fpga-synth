// Phase accumulator oscillator — one synthesizer voice.
// Advances phase and latches a square-wave sample on each i_DV pulse (from i2s_tx).
`include "constants.vh"

module voice (
    input        CLK,
    input  [3:0] i_note,
    input  [2:0] i_octave,
    input        i_gate,
    input        i_high,
    input        i_DV,
    output [15:0] o_sample
);

  wire [31:0] w_base_inc =
    (i_note == 4'd0)  ? 32'd23_017_594 :  // C4  261.626 Hz
    (i_note == 4'd1)  ? 32'd24_386_283 :  // C#4 277.183 Hz
    (i_note == 4'd2)  ? 32'd25_836_353 :  // D4  293.665 Hz
    (i_note == 4'd3)  ? 32'd27_372_642 :  // D#4 311.127 Hz
    (i_note == 4'd4)  ? 32'd29_000_342 :  // E4  329.628 Hz
    (i_note == 4'd5)  ? 32'd30_724_730 :  // F4  349.228 Hz
    (i_note == 4'd6)  ? 32'd32_561_722 :  // F#4 369.994 Hz
    (i_note == 4'd7)  ? 32'd34_487_328 :  // G4  391.995 Hz
    (i_note == 4'd8)  ? 32'd36_538_119 :  // G#4 415.305 Hz
    (i_note == 4'd9)  ? 32'd38_710_760 :  // A4  440.000 Hz
    (i_note == 4'd10) ? 32'd41_012_643 :  // A#4 466.164 Hz
    (i_note == 4'd11) ? 32'd43_451_332 :  // B4  493.883 Hz
                        32'd38_710_760;   // default

  wire [2:0] w_oct = i_high && (i_octave < 3'd7) ? i_octave + 3'd1 : i_octave;

  wire [31:0] w_phase_inc =
    (w_oct == 3'd0) ? (w_base_inc >> 4) :
    (w_oct == 3'd1) ? (w_base_inc >> 3) :
    (w_oct == 3'd2) ? (w_base_inc >> 2) :
    (w_oct == 3'd3) ? (w_base_inc >> 1) :
    (w_oct == 3'd4) ? (w_base_inc)      :
    (w_oct == 3'd5) ? (w_base_inc << 1) :
    (w_oct == 3'd6) ? (w_base_inc << 2) :
                      (w_base_inc << 3); // oct 7

  reg [31:0] r_phase  = 0;
  reg [15:0] r_sample = 0;

  always @(posedge CLK) begin
    if (i_DV) begin
      r_phase  <= r_phase + w_phase_inc;
      r_sample <= i_gate ? (r_phase[31] ? 16'h7FFF : 16'h8000) : 16'h0000;
    end
  end

  assign o_sample = r_sample;

endmodule
