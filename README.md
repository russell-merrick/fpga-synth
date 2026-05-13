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

## Roadmap

1. Multi-note — map buttons/switches to different pitches
2. Better waveforms — sine or wavetable instead of square wave
3. Envelope (ADSR) shaping
4. Polyphony — multiple simultaneous voices
5. MIDI input via PMOD UART or dedicated MIDI PMOD
6. Effects — reverb, filter, etc. (stretch)

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
| `synth_top.v` | Top-level design |
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
