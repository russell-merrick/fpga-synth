// FPGA Synthesizer — UART-controlled square wave
// Nandland Go Board (iCE40 HX1K, 25 MHz)
//
// UART RX (115200 8N1) drives an Ableton-layout command decoder.
// A 32-bit phase accumulator generates square wave audio sent via I2S to CS4344.
//
// Key layout (mirrors Ableton Computer MIDI Keyboard):
//   a=C  w=C#  s=D  e=D#  d=E  f=F  t=F#  g=G  y=G#  h=A  u=A#  j=B  k=C+1oct
//   z = octave down   x = octave up   space = gate toggle
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

  // ── I2S clock generation ────────────────────────────────────────────────────
  reg [31:0] r_ctr = 0;
  always @(posedge CLK) r_ctr <= r_ctr + 1;

  assign PMOD1 = r_ctr[`MCLK_BIT];   // MCLK  12.5  MHz
  assign PMOD3 = r_ctr[`SCLK_BIT];   // SCLK  3.125 MHz
  wire   w_lrck = r_ctr[`LRCK_BIT];  // LRCK  48.828 kHz (512-cycle period)
  assign PMOD2  = w_lrck;
  assign TX     = 1'b1;      // UART TX idle — not used

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

  // ── UART RX ─────────────────────────────────────────────────────────────────
  wire       w_rx_dv;
  wire [7:0] w_rx_byte;

  UART_RX #(.CLKS_PER_BIT(`CLKS_PER_BIT)) u_rx (
    .i_Rst_L    (1'b1),
    .i_Clock    (CLK),
    .i_RX_Serial(RX),
    .o_RX_DV    (w_rx_dv),
    .o_RX_Byte  (w_rx_byte)
  );

  // ── Command decoder ─────────────────────────────────────────────────────────
  // r_note: 0=C 1=C# 2=D 3=D# 4=E 5=F 6=F# 7=G 8=G# 9=A 10=A# 11=B
  reg [3:0] r_note   = `DEFAULT_NOTE;
  reg [2:0] r_octave = `DEFAULT_OCTAVE;
  reg       r_high   = 1'b0;   // 'k' plays C one octave above r_octave
  reg       r_gate   = 1'b1;   // 1 = note playing

  always @(posedge CLK) begin
    if (w_rx_dv) begin
      case (w_rx_byte)
        8'h61: begin r_note <= 4'd0;  r_high <= 0; r_gate <= 1; end  // a → C
        8'h77: begin r_note <= 4'd1;  r_high <= 0; r_gate <= 1; end  // w → C#
        8'h73: begin r_note <= 4'd2;  r_high <= 0; r_gate <= 1; end  // s → D
        8'h65: begin r_note <= 4'd3;  r_high <= 0; r_gate <= 1; end  // e → D#
        8'h64: begin r_note <= 4'd4;  r_high <= 0; r_gate <= 1; end  // d → E
        8'h66: begin r_note <= 4'd5;  r_high <= 0; r_gate <= 1; end  // f → F
        8'h74: begin r_note <= 4'd6;  r_high <= 0; r_gate <= 1; end  // t → F#
        8'h67: begin r_note <= 4'd7;  r_high <= 0; r_gate <= 1; end  // g → G
        8'h79: begin r_note <= 4'd8;  r_high <= 0; r_gate <= 1; end  // y → G#
        8'h68: begin r_note <= 4'd9;  r_high <= 0; r_gate <= 1; end  // h → A
        8'h75: begin r_note <= 4'd10; r_high <= 0; r_gate <= 1; end  // u → A#
        8'h6A: begin r_note <= 4'd11; r_high <= 0; r_gate <= 1; end  // j → B
        8'h6B: begin r_note <= 4'd0;  r_high <= 1; r_gate <= 1; end  // k → C+1oct
        8'h7A: if (r_octave > 0) r_octave <= r_octave - 1;           // z → down
        8'h78: if (r_octave < 7) r_octave <= r_octave + 1;           // x → up
        8'h20: r_gate <= ~r_gate;                                      // space → toggle
      endcase
    end
  end

  // ── Phase accumulator oscillator ────────────────────────────────────────────
  // Base phase increments for octave 4: phase_inc = freq * 2^32 / 48828.125
  wire [31:0] w_base_inc =
    (r_note == 4'd0)  ? 32'd23_017_594 :  // C4  261.626 Hz
    (r_note == 4'd1)  ? 32'd24_386_283 :  // C#4 277.183 Hz
    (r_note == 4'd2)  ? 32'd25_836_353 :  // D4  293.665 Hz
    (r_note == 4'd3)  ? 32'd27_372_642 :  // D#4 311.127 Hz
    (r_note == 4'd4)  ? 32'd29_000_342 :  // E4  329.628 Hz
    (r_note == 4'd5)  ? 32'd30_724_730 :  // F4  349.228 Hz
    (r_note == 4'd6)  ? 32'd32_561_722 :  // F#4 369.994 Hz
    (r_note == 4'd7)  ? 32'd34_487_328 :  // G4  391.995 Hz
    (r_note == 4'd8)  ? 32'd36_538_119 :  // G#4 415.305 Hz
    (r_note == 4'd9)  ? 32'd38_710_760 :  // A4  440.000 Hz
    (r_note == 4'd10) ? 32'd41_012_643 :  // A#4 466.164 Hz
    (r_note == 4'd11) ? 32'd43_451_332 :  // B4  493.883 Hz
                        32'd38_710_760;   // default

  // 'k' bumps the effective octave by 1 (capped at 7)
  wire [2:0] w_oct = r_high && (r_octave < 3'd7) ? r_octave + 3'd1 : r_octave;

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
      r_sample <= r_gate ? (r_phase[31] ? 16'h7FFF : 16'h8000) : 16'h0000;
    end
  end

  // ── I2S SDATA serialization ─────────────────────────────────────────────────
  // Standard I2S: 1-bit delay after LRCK transition, then 16 bits MSB-first,
  // then zero padding. Same formula confirmed working with CS4344 in this project.
  assign PMOD4 = (r_bit_pos >= 5'd1 && r_bit_pos <= 5'd16)
               ? r_sample[16 - r_bit_pos] : 1'b0;

  // ── LEDs ────────────────────────────────────────────────────────────────────
  assign LED1 = r_gate;       // lit when note is playing
  assign LED2 = r_octave[0];  // octave LSB
  assign LED3 = r_octave[1];
  assign LED4 = r_octave[2];  // octave MSB

endmodule
