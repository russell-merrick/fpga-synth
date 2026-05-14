# FPGA Synthesizer — Claude Coding Guidelines

## Verilog Conventions

### 1. Port naming — i_ / o_ prefixes

All sub-module ports must be prefixed:
- `i_` for inputs
- `o_` for outputs

```verilog
// correct
module voice (
    input        i_CLK,
    input  [3:0] i_note,
    output [15:0] o_sample
);

// wrong
module voice (
    input        CLK,
    input  [3:0] note,
    output [15:0] sample
);
```

**Exception:** `synth_top.v` top-level port names are board pin names and must match the PCF constraints file exactly (e.g. `CLK`, `RX`, `TX`, `PMOD1`). Do not prefix these.

**Third-party files** (`UART_RX.v`, `UART_TX.v`) are not modified.

### 2. No combinational always blocks

`always` blocks are for sequential logic only — clocked on `posedge` (or `negedge` for active-low resets). Combinational logic goes in `assign` statements or wire/reg declarations outside always blocks.

```verilog
// correct — combinational as assign
assign o_SDATA = (r_bit_pos >= 5'd1 && r_bit_pos <= 5'd16)
               ? i_sample[16 - r_bit_pos] : 1'b0;

// correct — sequential always
always @(posedge i_CLK) begin
    if (i_DV)
        r_phase <= r_phase + w_phase_inc;
end

// wrong — combinational always block
always @(*) begin
    case (i_note)
        ...
    endcase
end
```

### 3. Constants in ALL_CAPS

Defined constants (`` `define ``) use ALL_CAPS with underscores:

```verilog
`define CLKS_PER_BIT  217
`define MCLK_BIT      0
`define DEFAULT_OCTAVE 4
```

## Signal Naming

| Prefix | Meaning       | Example          |
|--------|---------------|------------------|
| `i_`   | module input  | `i_DV`, `i_note` |
| `o_`   | module output | `o_sample`       |
| `r_`   | register (flip-flop) | `r_phase`, `r_ctr` |
| `w_`   | wire (combinational) | `w_lrck_fall`, `w_phase_inc` |
