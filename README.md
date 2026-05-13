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

- I2S audio pipeline fully implemented and confirmed working on hardware
- Outputs a 440 Hz (A4) square wave tone via the CS4344 DAC
- SW1 button toggles tone on/off
- LEDs blink at divided clock rates as a visual heartbeat
- **UART modules integrated** — `UART_RX.v` and `UART_TX.v` sourced from [nandland/UART](https://github.com/nandland/UART) and added to the project
- **UART loopback test verified on hardware** — fabric loopback (`o_TX_Serial` → `i_RX_Serial`) transmits `0x55` ('U') every second; LEDs show `1 0 1 0` pattern on success; confirmed via serial terminal at 115200 baud

> **Currently loaded:** UART loopback test. Next commit restores the synth with UART RX command handling wired in.

## Roadmap

1. **UART control** — play and control the synth from a PC keyboard over USB serial
2. **Multi-note** — map UART keys (and physical switches) to a full octave of pitches
3. **Wavetable sine oscillator** — replace square wave with a ROM-based sine lookup
4. **ADSR envelope** — attack/decay/sustain/release shaping per note
5. **Polyphony** — multiple simultaneous voices
6. **MIDI input** — via PMOD UART or dedicated MIDI PMOD (future)
7. **Effects** — reverb, filter, etc. (stretch)

## Next Up: UART → Synth Integration

UART modules are in and verified. Next step is restoring the synth with live UART control:

1. Restore I2S audio pipeline in `synth_top.v` alongside the UART RX module
2. Wire received bytes into a command decoder — case statement maps ASCII keys to note frequencies
3. Add a testbench that bit-bangs bytes onto RX and verifies the correct audio sample appears at the I2S output

**Planned command set (single ASCII bytes):**

| Key(s) | Action |
|--------|--------|
| `a s d f g h j` | Play notes C D E F G A B |
| `z` | Mute / unmute |
| `1` / `2` | Octave down / up |

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

### 3. Install the Go Board USB driver

Plug in the Go Board, then run:

```bash
apio drivers install ftdi
```

In the Zadig window that opens:
1. Select the Go Board from the dropdown — pick **Interface 0** if it appears twice
2. Set the target driver to **WinUSB**
3. Click **Replace Driver** and wait for completion
4. Close Zadig, then unplug and replug the board

### 4. Flash and verify

```bash
apio upload
apio devices scan-usb   # if upload fails, use this to confirm the board is visible
```

---

## Common Commands

```bash
apio build              # synthesize bitstream
apio test               # run self-checking testbench (no GUI)
apio sim                # run testbench + open GTKWave for waveform inspection
apio upload             # build and flash to board
apio devices scan-usb   # list connected USB devices
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

## Project Files

| File | Description |
|------|-------------|
| `synth_top.v` | Top-level design (currently: UART loopback test) |
| `UART_RX.v` | UART receiver — 8N1, parameterized `CLKS_PER_BIT` (source: nandland/UART) |
| `UART_TX.v` | UART transmitter — 8N1, parameterized `CLKS_PER_BIT` (source: nandland/UART) |
| `synth_top_tb.v` | Self-checking testbench (`apio test`) |
| `go-board.pcf` | Pin constraints for Go Board |
| `apio.ini` | APIO project config |

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

### `apio sim` VCD file error

**Symptom**: `apio sim` fails with "Error opening .vcd file" or syntax errors.

**Cause**: Using `$dumpfile()` in the testbench conflicts with APIO's VCD handling.

**Fix**: Remove `$dumpfile()` — APIO passes the VCD path via command line (`vvp -dumpfile=`). Only call `$dumpvars()`:
```verilog
initial begin
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

**Fix**: See [First-Time Setup](#first-time-setup-new-windows-machine) → Step 3.

---

### APIO packages incompatible after update

**Symptom**: `apio build` errors on startup about incompatible packages.

**Cause**: APIO version update left stale `oss-cad-suite` or `examples` packages installed.

**Fix**: Just run `apio build` — APIO detects and auto-reinstalls incompatible packages, then continues normally.
