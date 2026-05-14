# FPGA Synthesizer

An open-source FPGA synthesizer built on the **Nandland Go Board** (iCE40 HX1K), developed iteratively and shared on social media. Fully open-source toolchain using APIO (Yosys / NextPNR / Icarus Verilog).

## Hardware

| Component | Details |
|-----------|---------|
| FPGA board | Nandland Go Board (iCE40 HX1K, 25 MHz oscillator, 4 LEDs, 4 switches, 4 buttons) |
| Audio DAC | Digilent PMOD I2S2 (CS4344) — plugged into PMOD pins 1–4 (left column) |
| PMOD jumper | Set to **SLV** (slave mode — FPGA drives all clocks) |
| Audio output | **Green** 3.5mm jack (LINE OUT) — not the blue one |

## Current State

- I2S audio pipeline confirmed working on hardware (CS4344 DAC via PMOD I2S2)
- **UART-controlled synth** — play notes from a PC keyboard over USB serial at 115200 baud
- Wavetable oscillator with 4 selectable waveforms: sine, triangle, sawtooth, square
- Chromatic scale across octaves 0–7, Ableton Computer MIDI Keyboard layout (see [Playing the Synth](#playing-the-synth) below)
- **ADSR envelope** — ~8 ms attack, ~7 ms decay, 78% sustain, ~26 ms release (rates hardcoded in `constants.vh`)
- LED1 = gate signal (lit while note is held; sound fades ~26 ms after gate-off), LED2–4 = current octave in binary

## Playing the Synth

Connect a serial terminal to the Go Board at **115200 8N1** and type keys to play notes.

### Quick start

```bash
# Find the port first
python -m serial.tools.list_ports

# Open interactive terminal (exit with Ctrl+])
python -m serial.tools.miniterm COM3 115200

# Run the automated scale test
python scripts/hw_test.py

# Send a single note
python scripts/hw_test.py --send h
```

### Key layout — Ableton Computer MIDI Keyboard

The layout mirrors Ableton Live's Computer MIDI Keyboard. White keys on the home row, black keys on the row above:

```
  w   e       t   y   u
a   s   d   f   g   h   j   k
C  C#   D  D#   E   F  F#   G  G#   A  A#   B   C+
```

| Key | Note | Key | Note |
|-----|------|-----|------|
| `a` | C  | `w` | C#  |
| `s` | D  | `e` | D#  |
| `d` | E  |     |     |
| `f` | F  | `t` | F#  |
| `g` | G  | `y` | G#  |
| `h` | A  | `u` | A#  |
| `j` | B  |     |     |
| `k` | C (one octave up) | | |

| Key | Action |
|-----|--------|
| `z` | Octave down |
| `x` | Octave up |
| `space` | Gate toggle (mute / unmute) |
| `1` | Waveform: sine |
| `2` | Waveform: triangle |
| `3` | Waveform: sawtooth |
| `4` | Waveform: square |

### LEDs during playback

| LED | Meaning |
|-----|---------|
| LED1 | Gate signal — lit while note is held; sound fades ~26 ms after gate-off (ADSR release) |
| LED2 | Octave bit 0 (LSB) |
| LED3 | Octave bit 1 |
| LED4 | Octave bit 2 (MSB) |

Default octave is 4 → LEDs show `OFF ON OFF OFF` (binary 0100).

---

## Roadmap

1. ~~**UART control**~~ ✓ — Ableton-layout keyboard over USB serial, confirmed on hardware
2. ~~**Modular refactor**~~ ✓ — `synth_top.v` is pure instantiation of `uart_top`, `voice`, `i2s_tx`
3. ~~**Wavetable oscillator**~~ ✓ — ROM-based wavetable with 4 selectable waveforms (sine, triangle, sawtooth, square), selected via keys 1–4
4. ~~**ADSR envelope**~~ ✓ — per-note attack/decay/sustain/release; rates hardcoded in `constants.vh`, to be made controllable
5. **Polyphony** — multiple simultaneous voices
6. **MIDI input** — via PMOD UART or dedicated MIDI PMOD (future)
7. **Effects** — reverb, filter, etc. (stretch)

---

## First-Time Setup (New Windows Machine)

### 1. Install APIO

```bash
pip install apio
```

### 2. Install APIO packages

Run a build — APIO auto-downloads `oss-cad-suite`, `examples`, and `definitions` on first run:

```bash
apio build
```

### 3. Install pyserial (for `hw_test.py` and `miniterm`)

pyserial ships with APIO's Python environment. If you need it standalone:

```bash
pip install pyserial
```

### 4. Install the Go Board USB driver

Plug in the Go Board, then run:

```bash
apio drivers install ftdi
```

In the Zadig window that opens:
1. Select the Go Board from the dropdown — pick **Interface 0** if it appears twice
2. Set the target driver to **WinUSB**
3. Click **Replace Driver** and wait for completion
4. Close Zadig, then unplug and replug the board

### 5. Flash and verify

```bash
apio upload
apio devices scan-usb   # if upload fails, use this to confirm the board is visible
```

---

## Common Commands

```bash
# Build / flash
apio build                          # synthesize bitstream
apio upload                         # build and flash to board
apio devices scan-usb               # list connected USB devices

# Simulation / test
apio test                           # run all self-checking testbenches
apio sim sim/synth_top_tb.v         # open synth_top waveform in GTKWave
apio sim sim/uart_cmd_tb.v          # open uart_cmd waveform in GTKWave

# Serial / hardware
python -m serial.tools.list_ports   # find the Go Board's COM port
python -m serial.tools.miniterm COM3 115200   # interactive terminal
python scripts/hw_test.py                   # automated scale + octave + gate test
python scripts/hw_test.py --port COM4       # override port
python scripts/hw_test.py --send h          # send a single key
```

---

## I2S Clock Configuration

All clocks are derived from the 25 MHz system clock via a free-running counter:

| Signal | Counter bit | Frequency | Role |
|--------|------------|-----------|------|
| MCLK | `counter[0]` | 12.5 MHz | 256× oversampling clock for CS4344 |
| SCLK | `counter[2]` | 3.125 MHz | Bit clock (64 bits/frame × 48.8 kHz) |
| LRCK | `counter[8]` | 48.828 kHz | Sample rate / left-right channel select |

---

## Project Layout

```
src/        HDL source
  synth_top.v       Top-level — pure instantiation of uart_top, voice, i2s_tx
  uart_top.v        UART wiring — instantiates UART_RX, UART_TX, uart_cmd
  uart_cmd.v        Command decoder — maps ASCII keys to note/octave/gate/wave signals
  voice.v           Phase accumulator oscillator + ADSR — 16-bit PCM sample per LRCK period
  adsr.v            ADSR envelope generator — 5-state FSM, 16-bit envelope, driven by LRCK tick
  i2s_tx.v          I2S transmitter — generates MCLK/LRCK/SCLK, serializes sample
  constants.vh      Project-wide defines — clock bits, baud rate, synth defaults, ADSR rates
  UART_RX.v         8N1 UART receiver, parameterized CLKS_PER_BIT (source: nandland/UART)
  UART_TX.v         8N1 UART transmitter, parameterized CLKS_PER_BIT (source: nandland/UART)

sim/        Simulation
  synth_top_tb.v    Self-checking testbench for full synth stack
  uart_cmd_tb.v     Self-checking testbench for uart_cmd (no UART timing needed)
  i2s_tx_tb.v       Self-checking testbench for I2S transmitter
  adsr_tb.v         Self-checking testbench for ADSR envelope FSM
  test_utils.vh     Shared pass_fail / finish_test tasks
  uart_cmd_tb.gtkw  GTKWave signal layout for uart_cmd

data/
  wavetable.hex     1024-entry ROM image (4 waveforms × 256 × 16-bit PCM)

scripts/
  gen_wavetable.py  Generates data/wavetable.hex
  hw_test.py        Hardware test — sends note sequences via pyserial

go-board.pcf        Pin constraints for Nandland Go Board
apio.ini            APIO project config
CLAUDE.md           Verilog coding conventions for this project
```

---

## Troubleshooting

### No audio output from PMOD I2S2

**Symptom**: Design running, no sound from headphones.

**Cause**: Incorrect PMOD pin assignments. The PMOD I2S2 DAC pinout is Pin 1 = MCLK, Pin 2 = LRCK, Pin 3 = SCLK, Pin 4 = SDATA.

**Fix**: Verify Verilog maps signals to the correct PMOD pins:
```verilog
output PMOD1,  // MCLK
output PMOD2,  // LRCK
output PMOD3,  // SCLK
output PMOD4   // SDATA
```
Reference: https://digilent.com/reference/pmod/pmodi2s2/reference-manual

---

### No audio despite correct clocks in simulation (bit slip)

**Symptom**: Clocks and data look right in simulation, no audio on hardware.

**Cause**: Left-justified format instead of standard I2S. The CS4344 expects a 1-bit delay after LRCK transitions before data starts.

**Fix**:
```verilog
// Left-justified (broken):
assign w_DAC_Data = (bit_pos < 16) ? audio_sample[15 - bit_pos] : 1'b0;

// Standard I2S (working):
assign w_DAC_Data = (bit_pos >= 1 && bit_pos <= 16) ? audio_sample[16 - bit_pos] : 1'b0;
```

---

### `apio sim` — multiple testbench files found

**Symptom**: `apio sim` errors with "Multiple testbench files found".

**Cause**: The project has more than one `*_tb.v` file.

**Fix**: Specify the testbench explicitly:
```bash
apio sim sim/synth_top_tb.v
apio sim sim/uart_cmd_tb.v
```

---

### `apio sim` VCD file error

**Symptom**: `apio sim` fails with "Error opening .vcd file" or syntax errors.

**Cause**: Using `$dumpfile()` in the testbench conflicts with APIO's VCD handling.

**Fix**: Remove `$dumpfile()` — APIO passes the VCD path via command line (`vvp -dumpfile=`). Only call `$dumpvars()`:
```verilog
initial
begin
  $dumpvars(0, synth_top_tb);
  // ...
end
```

---

### `apio upload` — Libusb backend not found

**Symptom**:
```
Error: Libusb backend not found
Searched names: ['usb-1.0', 'libusb-1.0', 'usb']
```

**Cause**: Windows USB access requires administrator privileges.

**Fix**: Run Cursor (or your terminal) as Administrator — right-click the icon → "Run as administrator", then retry `apio upload`.

---

### `apio upload` — No matching USB device

**Symptom**:
```
Error: No matching USB device.
```

**Cause**: WinUSB driver not installed for the Go Board's FTDI chip. Required once per machine.

**Fix**: See [First-Time Setup](#first-time-setup-new-windows-machine) → Step 4.

---

### APIO packages incompatible after update

**Symptom**: `apio build` errors on startup about incompatible packages.

**Cause**: APIO version update left stale `oss-cad-suite` or `examples` packages installed.

**Fix**: Just run `apio build` — APIO detects and auto-reinstalls incompatible packages, then continues normally.
