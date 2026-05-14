// Project-wide constants for FPGA Synthesizer
// Include with: `include "constants.vh"

// ── System clock ──────────────────────────────────────────────────────────────
`define SYS_CLK_HZ      25_000_000

// ── UART ─────────────────────────────────────────────────────────────────────
`define CLKS_PER_BIT    217         // SYS_CLK_HZ / 115_200 baud

// ── I2S clock divider bits ────────────────────────────────────────────────────
// All three signals are tapped from a free-running counter driven by SYS_CLK.
// Change these together if you adjust the sample rate.
`define MCLK_BIT        0           // counter[0] → 12.5   MHz MCLK (256× oversample)
`define SCLK_BIT        2           // counter[2] →  3.125 MHz SCLK (bit clock)
`define LRCK_BIT        8           // counter[8] → 48.828 kHz LRCK (sample rate)

// ── Synth defaults ────────────────────────────────────────────────────────────
`define DEFAULT_NOTE    9           // 0=C … 9=A … 11=B
`define DEFAULT_OCTAVE  4
`define DEFAULT_WAVE    2'd0        // 0=sine 1=triangle 2=sawtooth 3=square

// ── ADSR defaults ─────────────────────────────────────────────────────────────
// Rate parameters: increment/decrement applied to the 16-bit envelope per
// LRCK sample tick (48.828 kHz).  Higher value = faster transition.
// Sustain is a level: 0–255 maps to 0–32640  (value × 128).
`define DEFAULT_ATTACK   8'd80      // ~8 ms attack   (32767/80  ≈ 410 ticks)
`define DEFAULT_DECAY    8'd20      // ~7 ms decay
`define DEFAULT_SUSTAIN  8'd200     // 78 % sustain level  (200×128 = 25600)
`define DEFAULT_RELEASE  8'd20      // ~26 ms release  (25600/20 ≈ 1280 ticks)
