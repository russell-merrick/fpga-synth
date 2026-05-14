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

`always` blocks are for sequential logic only — clocked on `posedge` (or `negedge` for active-low resets). Combinational logic goes in `assign` statements outside always blocks.

```verilog
// correct — combinational as assign
assign o_SDATA = (r_bit_pos >= 5'd1 && r_bit_pos <= 5'd16)
               ? i_sample[16 - r_bit_pos] : 1'b0;

// correct — sequential always
always @(posedge i_CLK)
begin
  if (i_DV)
  begin
    r_phase <= r_phase + w_phase_inc;
  end
end

// wrong — combinational always block
always @(*) begin
    case (i_note)
        ...
    endcase
end
```

### 3. Constants in ALL_CAPS

`` `define `` macros and `localparam` names use ALL_CAPS with underscores:

```verilog
`define CLKS_PER_BIT   217
`define DEFAULT_OCTAVE  4

localparam IDLE         = 3'b000;
localparam RX_START_BIT = 3'b001;
```

### 4. Non-blocking assignments in all sequential always blocks

Since every `always` block is clocked (rule 2), always use `<=`. Never mix `=` and `<=` in the same always block — it causes simulation/synthesis mismatches.

```verilog
// correct
always @(posedge i_CLK)
begin
  r_phase  <= r_phase + w_phase_inc;
  r_sample <= i_gate ? 16'h7FFF : 16'h0000;
end

// wrong — blocking assignment in clocked block
always @(posedge i_CLK)
begin
  r_phase  = r_phase + w_phase_inc;
end
```

### 5. Explicit bit-width literals everywhere

Always specify base and width. Prevents implicit truncation and width-mismatch warnings.

```verilog
// correct
r_state <= 3'b000;
r_byte  <= 8'hFF;
r_count <= 4'd0;
o_gate  <= 1'b1;

// wrong
r_state <= 0;
r_byte  <= 255;
o_gate  <= 1;
```

### 6. Allman-style begin/end; 2-space indent

Every branch body (`if`, `else`, `else if`, `case` arm, `always`, `initial`, `for`) gets a `begin`/`end` even when it contains only one statement. `begin` goes on its own line at the same indent level as the controlling statement. `end` is always on its own line. Indent the block body 2 spaces relative to the `begin`. Never use tabs.

```verilog
// correct
if (i_RX_DV)
begin
  r_state <= IDLE;
end

always @(posedge i_CLK)
begin
  if (w_lrck_edge)
  begin
    r_bit_pos <= 5'd0;
  end
  else if (w_sclk_fall)
  begin
    r_bit_pos <= r_bit_pos + 5'd1;
  end
end

// wrong — no begin/end
if (i_RX_DV)
    r_state <= IDLE;

// wrong — begin on same line as controlling statement (K&R style)
if (i_RX_DV) begin
    r_state <= IDLE;
end
```

### 7. Blank lines around `always` and `initial` blocks

Every `always` block must be preceded by a blank line and followed by a blank line after its closing `end`. Same rule applies to `initial` blocks at module scope.

```verilog
// correct
  reg [31:0] r_phase = 32'd0;

  always @(posedge i_CLK)
  begin
    r_phase <= r_phase + w_phase_inc;
  end

  assign o_sample = r_sample;

// wrong — missing blank lines
  reg [31:0] r_phase = 32'd0;
  always @(posedge i_CLK)
  begin
    r_phase <= r_phase + w_phase_inc;
  end
  assign o_sample = r_sample;
```

### 8. _L suffix for active-low signals

Any signal that is asserted low gets an `_L` suffix:

```verilog
input  i_Rst_L,    // active-low reset
output o_CS_L      // active-low chip select
```

### 9. localparam for FSM states and local constants

Use `localparam` (not `` `define ``) for values scoped to a single module — FSM state names, local timeouts, magic counts. `localparam` cannot be overridden from outside the module, which is the correct behavior for internal constants. Use `parameter` only for values that should be overridable at instantiation (e.g. `CLKS_PER_BIT`).

```verilog
// correct — localparam for FSM states
localparam IDLE     = 3'b000;
localparam PLAYING  = 3'b001;
localparam RELEASE  = 3'b010;

// correct — parameter for overridable config
module uart_rx #(parameter CLKS_PER_BIT = 217) ( ... );

// wrong — `define for module-local state
`define IDLE 3'b000
```

---

## Signal Naming

| Prefix | Meaning              | Example                       |
|--------|----------------------|-------------------------------|
| `i_`   | module input         | `i_DV`, `i_note`              |
| `o_`   | module output        | `o_sample`                    |
| `r_`   | register (flip-flop) | `r_phase`, `r_ctr`            |
| `w_`   | wire (combinational) | `w_lrck_fall`, `w_phase_inc`  |
| `_L`   | active-low signal    | `i_Rst_L`, `o_CS_L`           |
