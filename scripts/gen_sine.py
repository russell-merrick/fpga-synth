"""
Generate sine.hex — 256-entry 16-bit signed sine wavetable for voice.v.
Writes sine.hex to the project root (one level up from this script).
Run from anywhere: python scripts/gen_sine.py
"""

import math
import os

ENTRIES   = 256
AMPLITUDE = 32767   # peak value; keeps waveform symmetric (+32767 / -32767)

output_path = os.path.join(os.path.dirname(__file__), "..", "sine.hex")

with open(output_path, "w") as f:
    for i in range(ENTRIES):
        angle = 2 * math.pi * i / ENTRIES
        value = round(AMPLITUDE * math.sin(angle))
        if value < 0:
            value += 65536          # two's complement
        f.write(f"{value:04X}\n")

print(f"Wrote {ENTRIES} entries to sine.hex")
