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
