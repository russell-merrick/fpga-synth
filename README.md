# FPGA Synthesizer

An open-source FPGA synthesizer built on the **Nandland Go Board** (iCE40 HX1K), developed iteratively and shared on social media. Fully open-source toolchain using APIO (Yosys / NextPNR / Icarus Verilog).

## Hardware

| Component | Details |
|-----------|---------|
| FPGA board | **Go Board** (iCE40 HX1K) or **IceSugar-Pro** (ECP5 LFE5U-25F-6BG256C). Both 25 MHz (IceSugar clock is P6). |
| Audio DAC | Digilent PMOD I2S2 (CS4344) — Go Board PMOD pins 1–4, or IceSugar-Pro **P4** bottom row only (see below) |
| PMOD jumper | Set to **SLV** (slave mode — FPGA drives all clocks) |
| Audio output | **Green** 3.5mm jack (LINE OUT) — not the blue one |
| IceSugar LED | Green RGB blinks ~1.5 Hz (alive). Red = gate (on at boot; off after space or seq stop). |

## Current State

- I2S audio pipeline confirmed working on hardware (CS4344 DAC via PMOD I2S2)
- **UART-controlled synth** — play notes from a PC keyboard over USB serial at 115200 baud. IceSugar-Pro: **2-voice** (last two notes); Go Board: 1 voice.
- Wavetable oscillator with 4 selectable waveforms: sine, triangle, sawtooth, square
- Chromatic scale across octaves 0–7, Ableton Computer MIDI Keyboard layout (see [Playing the Synth](#playing-the-synth) below)
- **ADSR envelope** — live `r` / `-` / `=` (A D S R). Defaults ~8 ms attack, ~7 ms decay, 78% sustain, ~26 ms release
- **303-style VCF** — resonant LPF; each note opens the filter then it closes over ~340 ms (IceSugar). Accent (`.`), slide (`/`), drive (`o`). Go Board skips VCF/drive/slide.
- **2-op FM + wavefolder** (IceSugar) — sine modulator into the carrier wavetable (`i` index, `n` ratio 1–8), then 8× oversampled fold (`l`). Defaults off so the 303 patch is unchanged.
- **16-step sequencer** (IceSugar) — sample-accurate 16ths, default A-minor acid line, BPM 40–240. Stop mutes both voices (no hanging last note).
- **Browser GUI** — `python gui/server.py --port COM4` → http://127.0.0.1:8080. Pattern grid, knobs, Play/Stop.
- LED1 / IceSugar red = gate. LED2–4 = octave in binary (Go Board).

Go Board builds skip the heavy IceSugar path: `NUM_VOICES=1 SKIP_UART_MENU=1 SKIP_FILTER=1 SKIP_SLIDE=1 SKIP_FM=1 SKIP_SEQ=1`.

## Architecture

IceSugar path (Go Board stubs seq / VCF / FM / voice1). UART writes regs; `i2s_tx` `DV` ticks seq, voices, VCF, and drive once per sample.

```
  PC  miniterm / gui/server.py :8080
              |  115200 8N1
              v
         iCELink COM
              |
     RX ------+---------------------------- TX
              |                              ^
         +----+-----+                   +----+------+
         | UART_RX  |  byte             | uart_menu |
         +----+-----+                   | help/stat |
              |                         +----+------+
              v                              ^
         +----+-----+  notes, ADSR, C/Q,     |
         | uart_cmd |  FM, fold, drive,      |
         |  + mute  |  :P :J :C…             |
         +--+----+--+------------------------+
            |    |
            |    | play bpm pattern
            |    v
            |  +--------+  16ths from LRCK DV
            |  |  seq   |  16 steps  rest/acc/sld
            |  +---+----+
            |      |
            |      |  seq_play ?
            |      |    yes → seq note/gate/acc/sld/trig
            |      |    no  → live v0 (muted on stop)
            |      v
            |  +---+---+
            |  |  mux  |-------- voice1 gate=0 while seq
            |  +---+---+
            |      |
     params |      |                  shared: oct wave ADSR FM fold
            |      v
            |  +-----------+     +-----------+
            |  |  voice 0  |     |  voice 1  |   (2-voice only)
            |  | wavetable |     | same      |
            |  | 2-op FM   |     |           |
            |  | 8× folder |     |           |
            |  | ADSR/slide|     |           |
            |  +-----+-----+     +-----+-----+
            |        |                 |
            |        +--------+--------+
            |                 v
            |              mix + sat
            |                 |
            |                 v
            |         +-------+-------+
            |         |  VCF (SVF)    |  cutoff/res + fenv on trig
            |         |  + drive/sat  |  accent bumps res/drive
            |         +-------+-------+
            |                 |
            |                 v
            |         +-------+-------+
            +-------->|    i2s_tx     |-----> P4 I2S2  CS4344
              DV 48.8k| MCLK LRCK     |        green jack
                      | SCLK SDATA    |
                      +---------------+
                              CLK 25 MHz
```

Voice 0 internals:

```
 note/oct ──► phase acc ──► (+ sine mod × index/ratio)
                  │                    │
               slide slew         wavetable[wave]
                  │                    │
                  └────────────────────┤
                                       v
                                  8× OS folder
                                       v
                                  × ADSR (×1.5 if accent)
```

## Playing the Synth

Connect a serial terminal at **115200 8N1** (IceSugar: the **iCELink** COM port, not the breakout DAPLink). After ~80 ms the board prints a help menu (`?` reprints it). Commands print a status line; `*` marks the param `r` selected, then `-` / `=` change it by 8.

Boot is **A4 saw** on IceSugar (sine on Go Board) on voice 0. Each new note key takes the other voice and retriggers the filter sweep unless **slide** is on. Space mutes both. Sequencer **stop** also mutes — it does not fall back to the A4 drone.

`.` accent. `/` slide. `o` drive. `i` FM index, `n` ratio (1–8), `l` fold. `p` seq play/stop, `[` `]` BPM. Close miniterm before the GUI (COM is exclusive).

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
| `.` | Toggle accent (next notes louder + more snap) |
| `/` | Toggle slide (glide into next note, no filter retrig) |
| `i` | Select FM index, then `-` / `=` |
| `n` | Select FM ratio (1–8, step 1) |
| `l` | Select wavefold amount |
| `o` | Select drive, then `-` / `=` |
| `c` | Select cutoff, then `-` / `=` |
| `q` | Select resonance |
| `v` | Select filter-env amount |
| `b` | Select filter-env decay |
| `p` | Sequencer play / stop (stop mutes both voices) |
| `[` / `]` | BPM down / up |
| `r` | Cycle next param (A D S R C Q E K O I N L) |
| `-` | Decrease selected value (step 8) |
| `=` or `+` | Increase selected value |
| `?` | Reprint help menu |

### Sequencer (IceSugar)

16 steps of 16th notes, clocked from LRCK (`bpm × 23` added to a 24-bit phase acc per sample). Default 120 BPM, length 16, baked A-minor line:

`A A C A D E D~ C A G A C! D C A G` (`~` slide, `!` accent)

While playing, live keys `a`–`k` are ignored; voice 1 is held off. Stop (`p` or GUI Stop) gates both voices off so the last step does not sustain forever.

Step byte: `[7] rest  [6] accent  [5] slide  [4] +oct  [3:0] note` (0=C … 9=A … 11=B).

### UART line protocol (GUI / scripts)

Absolute set, ASCII, 115200 8N1. Line starts with `:` and ends with `\n`.

| Command | Meaning |
|---------|---------|
| `:A080` … `:R020` | ADSR (3-digit decimal, 0–255) |
| `:C040 :Q210 :E255 :K064` | cutoff, res, filter-env amount, filter-env decay |
| `:O096 :I000 :N002 :L000` | drive, FM index, FM ratio (1–8), fold |
| `:B120 :X004 :W002 :Y016` | BPM (40–240), octave (0–7), wave (0–3), length (1–16) |
| `:P001` / `:P000` | seq play / stop (stop mutes) |
| `:J` + 32 hex chars | write all 16 step bytes |

Example: `:C100\n` sets cutoff to 100. `:J0909000902042200…\n` loads a pattern.

`c` / `q` / `v` / `b` on the keyboard **select** cutoff/res/env/decay for `-`/`=`. They are not the letters in `:C` / `:Q`. Status `*C` means cutoff is selected. `e`/`k` are note keys, not filter keys.

### Browser GUI

Close miniterm, then:

```bash
python gui/server.py --port COM4
```

Open http://127.0.0.1:8080 — Connect, Play/Stop, BPM/octave/length/wave, 16-step grid, filter/amp/tone knobs, Push pattern.

Grid **A / S / R** = **Accent / Slide / Rest** (not ADSR). FPGA owns the 16th clock; the page only edits. After HDL or GUI changes, restart `server.py` (COM exclusive).

### LEDs during playback

| LED | Meaning |
|-----|---------|
| LED1 | Gate — lit while a note is held; off after space or seq stop; sound fades ~26 ms (ADSR release) |
| LED2 | Octave bit 0 (LSB) |
| LED3 | Octave bit 1 |
| LED4 | Octave bit 2 (MSB) |

Default octave is 4 → LEDs show `OFF ON OFF OFF` (binary 0100).

---

## Roadmap

1. ~~**UART control**~~ ✓ — Ableton-layout keyboard over USB serial, confirmed on hardware
2. ~~**Modular refactor**~~ ✓ — `synth_top.v` is pure instantiation of `uart_top`, `voice`, `i2s_tx`
3. ~~**Wavetable oscillator**~~ ✓ — ROM-based wavetable with 4 selectable waveforms (sine, triangle, sawtooth, square), selected via keys 1–4
4. ~~**ADSR envelope**~~ ✓ — live `r` / `-` / `=` on UART; help/status menu on TX
5. ~~**Polyphony**~~ ✓ — two voices on IceSugar-Pro (round-robin; space mutes both). Go Board stays 1 voice (`NUM_VOICES=1`).
6. ~~**Resonant VCF**~~ ✓ — Chamberlin LPF + decay env on IceSugar (`SKIP_FILTER` on Go Board)
7. ~~**Accent / slide / drive**~~ ✓ — `.` `/` `o` on IceSugar
8. ~~**2-op FM + wavefolder**~~ ✓ — `i` `n` `l`, 8× oversampled fold
9. ~~**16-step sequencer + GUI**~~ ✓ — sample-accurate 16ths, UART `:P` / `:J`, `python gui/server.py`
10. ~~**Seq stop mute**~~ ✓ — stop gates both voices (no hanging last note)
11. **MIDI input / delay** — stretch

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

### 3. Install pyserial (for `hw_test.py`, `miniterm`, and `gui/server.py`)

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
# Build / flash — Go Board (default)
apio build                          # synthesize bitstream
apio upload                         # build and flash to board
apio devices scan-usb               # list connected USB devices

# IceSugar-Pro — USB-C on the **FPGA module** (iCELink), not the green breakout DAPLINK
apio build  -e icesugar-pro-ram
apio upload -e icesugar-pro-ram     # SRAM (lost on power-cycle)
apio upload -e icesugar-pro         # SPI flash (boots after unplug)

python gui/server.py --port COM4    # then http://127.0.0.1:8080  (close miniterm first)
```

### IceSugar-Pro USB / programming

| Cable | Drive | USB ID | Programs this FPGA? |
|-------|-------|--------|---------------------|
| USB-C on the **FPGA module** | `iCELink` | `1d50:602b` MuseLab CMSIS-DAP | Yes |
| USB-C on the **green breakout** | `DAPLINK` | `0d28:0204` ARM CMSIS-DAP | No |

The breakout DAPLink is for Colorlight i5/i9 JTAG (pogo pins). IceSugar-Pro JTAG is wired to on-module iCELink only — a JTAG scan on the breakout returns an empty chain.

Do not drag a `.bit` onto the breakout `DAPLINK` drive (mbed may treat it as debugger firmware). Drag-and-drop onto the **iCELink** drive does program SPI flash; this project uses `apio upload` via CMSIS-DAP instead.

RGB LED is **active-high** (LiteX examples often name these `_n`; the hardware is the opposite): red B11, green A11, blue A12. This synth: green ~1.5 Hz heartbeat, red = gate.

Module docs: [icesugar-pro](https://github.com/wuxx/icesugar-pro) · [pinmap](https://github.com/wuxx/icesugar-pro/blob/master/doc/iCESugar-pro-pinmap.png) · [schematic](https://github.com/wuxx/icesugar-pro/tree/master/schematic)

HDMI on the green breakout is real TMDS video (Muse Lab ships `hdmi_test_pattern.bit`). This synth does not use it — audio is I2S2 on P4. See below.

IceSugar-Pro **P4** (between HDMI/P3 and P5): I2S2 on the **bottom/outer row only**, HDMI end, do not flip. Count from HDMI.

Pinout: [iCESugar-pro-pinmap.png](https://github.com/wuxx/icesugar-pro/blob/master/doc/iCESugar-pro-pinmap.png) — **P4** table.

| P4 (from HDMI, outer row) | I2S2 | IceSugar |
|---------------------------|------|----------|
| 1 | 6 VCC | 3V3 |
| 2 | 5 GND | GND |
| 3 | 4 SDATA | R7 |
| 4 | 3 SCLK | D5 |
| 5 | 2 LRCK | D4 |
| 6 | 1 MCLK | E4 |

Inner row (R8 C4 C3 E3) unused.

### IceSugar-Pro HDMI (unused by this synth)

The green breakout HDMI jack is wired to the ECP5 as **DVI-style TMDS** (RGB + clock only — no DDC/I2C, no HDMI audio). Muse Lab’s [hdmi_test_pattern](https://github.com/wuxx/icesugar-pro/tree/master/src/hdmi_test_pattern) bitstream drives it. Pins (from that demo LPF): G1/F1, J1/H2, L1/K2, E2/D3.

This project’s audio path is P4 I2S2, not HDMI.

```bash
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
  synth_top.v       Top-level — uart_top, seq, voice(s), vcf, drive, i2s_tx
  icesugar_top.v    IceSugar-Pro wrapper — RGB heartbeat, maps SynthTop to ECP5 pins
  uart_top.v        UART wiring — RX, uart_cmd, uart_menu, TX
  uart_menu.v       Help banner + status line printer
  uart_cmd.v        Command decoder — notes, params, seq play/stop, `:…` line protocol
  seq.v             16-step sequencer — 16ths from LRCK phase acc, pattern write port
  voice.v           Oscillator — wavetable, 2-op FM, 8× OS wavefolder, ADSR, slide
  adsr.v            ADSR envelope generator — 5-state FSM, 16-bit envelope, driven by LRCK tick
  vcf.v             Resonant LPF (Chamberlin SVF) + decay-only filter envelope
  drive.v           Soft-clip overdrive after the VCF
  i2s_tx.v          I2S transmitter — generates MCLK/LRCK/SCLK, serializes sample
  constants.vh      Project-wide defines — clock bits, baud rate, synth/ADSR/VCF/seq defaults
  UART_RX.v         8N1 UART receiver, parameterized CLKS_PER_BIT (source: nandland/UART)
  UART_TX.v         8N1 UART transmitter, parameterized CLKS_PER_BIT (source: nandland/UART)

sim/        Simulation
  synth_top_tb.v    Self-checking testbench for full synth stack
  uart_cmd_tb.v     Self-checking testbench for uart_cmd (no UART timing needed)
  i2s_tx_tb.v       Self-checking testbench for I2S transmitter
  adsr_tb.v         Self-checking testbench for ADSR envelope FSM
  vcf_tb.v          Self-checking testbench for resonant VCF + filter env
  seq_tb.v          Self-checking testbench for the 16-step sequencer
  test_utils.vh     Shared pass_fail / finish_test tasks
  uart_cmd_tb.gtkw  GTKWave signal layout for uart_cmd

gui/
  server.py         HTTP + pyserial bridge (stdlib + pyserial)
  static/           Browser UI (index.html, styles.css, app.js)

data/
  wavetable.hex     1024-entry ROM image (4 waveforms × 256 × 16-bit PCM)

scripts/
  gen_wavetable.py  Generates data/wavetable.hex
  hw_test.py        Hardware test — sends note sequences via pyserial

go-board.pcf        Pin constraints for Nandland Go Board
icesugar-pro.lpf    Pin constraints for IceSugar-Pro (P4 I2S)
apio.ini            APIO project config (go-board default; icesugar-pro / icesugar-pro-ram)
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
