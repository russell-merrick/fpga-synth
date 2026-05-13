// FPGA Synthesizer — Top Level
// Target: Nandland Go Board (iCE40 HX1K, 25 MHz oscillator)
// Audio output: Digilent PMOD I2S2 (CS4344 DAC) in slave mode
//
// Signal chain:
//   25 MHz CLK → clock dividers → I2S clocks (MCLK/SCLK/LRCK)
//                               → 440 Hz square wave → I2S serializer → DAC

module SynthTop (
    input  CLK,   // 25 MHz system clock
    input  SW1,   // Button: toggle tone on/off (active low)
    output LED1,
    output LED2,
    output LED3,
    output LED4,
    output PMOD1,  // MCLK  — 12.5 MHz master clock
    output PMOD2,  // LRCK  — 48.8 kHz left/right channel select
    output PMOD3,  // SCLK  — 3.125 MHz bit clock
    output PMOD4   // SDATA — serial audio data to DAC
);

  // -------------------------------------------------------------------------
  // Free-running counter — source for all clock and timing signals
  // -------------------------------------------------------------------------
  reg [23:0] counter = 0;
  always @(posedge CLK) counter <= counter + 1;

  // LEDs blink at successively halved rates as a visual heartbeat
  assign LED1 = counter[23];
  assign LED2 = counter[22];
  assign LED3 = counter[21];
  assign LED4 = counter[20];

  // -------------------------------------------------------------------------
  // I2S clock generation (all tapped from the free-running counter)
  //
  //   MCLK = 25 MHz / 2   = 12.5 MHz  (256× oversampling clock for CS4344)
  //   SCLK = 25 MHz / 8   = 3.125 MHz (64 bits/frame × 48.8 kHz)
  //   LRCK = 25 MHz / 512 = 48.828 kHz sample rate
  // -------------------------------------------------------------------------
  assign PMOD1 = counter[0];  // MCLK
  assign PMOD3 = counter[2];  // SCLK
  assign PMOD2 = counter[8];  // LRCK: low = left channel, high = right channel

  // -------------------------------------------------------------------------
  // Tone enable — toggled by SW1 (active-low button), on by default
  // -------------------------------------------------------------------------
  reg sw1_prev   = 1;
  reg tone_enable = 1;

  always @(posedge CLK)
  begin
    sw1_prev <= SW1;
    if (sw1_prev == 1 && SW1 == 0)  // falling edge = button pressed
      tone_enable <= ~tone_enable;
  end

  // -------------------------------------------------------------------------
  // 440 Hz (A4) square wave oscillator
  // Period = 25 MHz / (2 × 28409) = 440.01 Hz
  // -------------------------------------------------------------------------
  localparam TONE_DIVISOR = 28409;
  reg [15:0] tone_counter = 0;
  reg        tone_out     = 0;

  always @(posedge CLK)
  begin
    if (tone_counter >= TONE_DIVISOR - 1)
    begin
      tone_counter <= 0;
      tone_out     <= ~tone_out;
    end
    else
      tone_counter <= tone_counter + 1;
  end

  // -------------------------------------------------------------------------
  // Audio sample latch
  // Capture a new sample at the start of each left-channel frame (LRCK low,
  // bit_pos = 0) so the value stays stable across the full 32-bit I2S frame.
  // Quarter-amplitude square wave: +0x1FFF / -0x1FFF (16-bit signed)
  // -------------------------------------------------------------------------
  wire [4:0] bit_pos;
  assign bit_pos = counter[7:3];  // 0–31: position within the 32-bit I2S frame

  reg [15:0] audio_sample = 0;

  always @(posedge CLK)
  begin
    if (counter[8:0] == 0)  // start of left channel frame
      audio_sample <= (tone_enable) ? (tone_out ? 16'h1FFF : 16'hE001) : 16'h0000;
  end

  // -------------------------------------------------------------------------
  // I2S serializer — MSB first, standard I2S format
  // Standard I2S has a 1-bit delay after LRCK transitions before data starts,
  // so bit_pos 0 is a don't-care and data occupies bit_pos 1–16.
  // -------------------------------------------------------------------------
  wire w_DAC_Data;
  assign w_DAC_Data = (bit_pos >= 1 && bit_pos <= 16) ? audio_sample[16 - bit_pos] : 1'b0;
  assign PMOD4 = w_DAC_Data;

endmodule
