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
`ifndef DEFAULT_WAVE
`define DEFAULT_WAVE    2'd0        // 0=sine 1=triangle 2=sawtooth 3=square
`endif
`ifndef NUM_VOICES
`define NUM_VOICES      2           // 1 on Go Board (HX1K), 2 on IceSugar-Pro
`endif

// ── ADSR defaults ─────────────────────────────────────────────────────────────
// Rate parameters: increment/decrement applied to the 16-bit envelope per
// LRCK sample tick (48.828 kHz).  Higher value = faster transition.
// Sustain is a level: 0–255 maps to 0–32640  (value × 128).
`define DEFAULT_ATTACK   8'd80      // ~8 ms attack   (32767/80  ≈ 410 ticks)
`define DEFAULT_DECAY    8'd20      // ~7 ms decay
`define DEFAULT_SUSTAIN  8'd200     // 78 % sustain level  (200×128 = 25600)
`define DEFAULT_RELEASE  8'd20      // ~26 ms release  (25600/20 ≈ 1280 ticks)
`define ADSR_STEP        8'd8       // UART - / = step

// ── Filter (303-style VCF) ────────────────────────────────────────────────────
// Filter env is 20-bit; subtracted by i_fdecay per sample (~48.8 kHz).
// Default K=64 → ~0.34 s sweep. Higher K = faster close.
`define DEFAULT_CUTOFF   8'd40      // closed; env opens it on each note
`define DEFAULT_RES      8'd210
`define DEFAULT_FENV     8'd255     // full sweep amount
`define DEFAULT_FDECAY   8'd64      // ~340 ms  (1048575 / 64 / 48828)
`define DEFAULT_DRIVE    8'd96
`define ACCENT_DRIVE     8'd80      // extra drive on accent
`define ACCENT_RES       8'd40      // extra resonance on accent
`define SLIDE_SHIFT      5'd12      // slew tau ~84 ms
`define DEFAULT_FM_INDEX 8'd0       // 0 = no FM
`define DEFAULT_FM_RATIO 8'd2       // modulator = 2× carrier
`define DEFAULT_FOLD     8'd0       // 0 = no fold
`define DEFAULT_BPM      8'd120
`define DEFAULT_SEQ_LEN  5'd16
