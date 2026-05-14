"""
Generate wavetable.hex — 1024-entry 16-bit signed wavetable for voice.v.
Layout: 4 waveforms × 256 entries, addressed by {wave[1:0], phase[7:0]}.

  0 = sine      (entries    0–255)
  1 = triangle  (entries  256–511)
  2 = sawtooth  (entries  512–767)
  3 = square    (entries 768–1023)

Writes wavetable.hex to the project root.
Run from anywhere: python scripts/gen_wavetable.py
"""

import math
import os

ENTRIES   = 256
AMPLITUDE = 32767

def sine(i):
    return round(AMPLITUDE * math.sin(2 * math.pi * i / ENTRIES))

def triangle(i):
    t = i / ENTRIES
    if t < 0.25:
        return round(AMPLITUDE * 4 * t)
    elif t < 0.75:
        return round(AMPLITUDE * (2 - 4 * t))
    else:
        return round(AMPLITUDE * (4 * t - 4))

def sawtooth(i):
    return round(AMPLITUDE * (2 * i / ENTRIES - 1))

def square(i):
    return AMPLITUDE if i < ENTRIES // 2 else -AMPLITUDE

waveforms = [sine, triangle, sawtooth, square]

output_path = os.path.join(os.path.dirname(__file__), "..", "wavetable.hex")

with open(output_path, "w") as f:
    for waveform in waveforms:
        for i in range(ENTRIES):
            value = waveform(i)
            if value < 0:
                value += 65536      # two's complement
            f.write(f"{value:04X}\n")

print(f"Wrote {len(waveforms) * ENTRIES} entries to wavetable.hex")
