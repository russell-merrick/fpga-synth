"""
Hardware test script for FPGA synthesizer.
Sends UART commands to the Go Board and prints what was sent.
The human confirms audio / LED responses.

Usage:
    python scripts/hw_test.py                # run full scale + waveform test
    python scripts/hw_test.py --demo twinkle # play Twinkle Twinkle Little Star
    python scripts/hw_test.py --port COM4    # override port
    python scripts/hw_test.py --send a       # send a single key
"""

import serial
import time
import argparse
import sys

PORT     = "COM3"
BAUD     = 115200
CHAR_GAP = 0.6   # seconds between notes (long enough to hear each one)

# Note name for display
NOTE_NAMES = {
    'a': 'C',  'w': 'C#', 's': 'D',  'e': 'D#',
    'd': 'E',  'f': 'F',  't': 'F#', 'g': 'G',
    'y': 'G#', 'h': 'A',  'u': 'A#', 'j': 'B',
    'k': 'C+1oct',
    'z': 'octave down', 'x': 'octave up',
    ' ': 'gate toggle',
    '1': 'wave: sine', '2': 'wave: triangle',
    '3': 'wave: sawtooth', '4': 'wave: square',
}

def send(ser, char, label=None):
    name = label or NOTE_NAMES.get(char, f'0x{ord(char):02X}')
    ser.write(char.encode())
    print(f"  sent '{char}'  ->  {name}")

def run_scale(ser):
    print("\n--- Chromatic scale (C through B) ---")
    for key in ['a', 'w', 's', 'e', 'd', 'f', 't', 'g', 'y', 'h', 'u', 'j']:
        send(ser, key)
        time.sleep(CHAR_GAP)

    print("\n--- Octave up ---")
    send(ser, 'x')
    time.sleep(0.3)
    send(ser, 'a')
    time.sleep(CHAR_GAP)

    print("\n--- Octave down x2 ---")
    send(ser, 'z')
    time.sleep(0.3)
    send(ser, 'z')
    time.sleep(0.3)
    send(ser, 'a')
    time.sleep(CHAR_GAP)

    print("\n--- Gate toggle (silence then restore) ---")
    send(ser, ' ')
    time.sleep(CHAR_GAP)
    send(ser, ' ')
    time.sleep(CHAR_GAP)

    print("\n--- Back to default A4 ---")
    send(ser, 'x')   # octave back to 4
    time.sleep(0.2)
    send(ser, 'h')   # A
    time.sleep(CHAR_GAP)

    print("\n--- Waveform sweep (A4, each waveform) ---")
    for key in ['1', '2', '3', '4']:
        send(ser, key)
        time.sleep(CHAR_GAP)
    send(ser, '1')   # back to sine

    print("\n--- Gate off ---")
    send(ser, ' ')

    print("\nDone. Confirm: scale, octave shift, gate toggle, then 4 waveforms on A4.")

def run_twinkle(ser):
    BPM = 100
    Q   = 60 / BPM        # quarter note
    H   = Q * 2           # half note
    GAP = 0.04            # brief gate-off gap between notes for articulation

    def note(key, dur):
        ser.write(key.encode())
        time.sleep(dur - GAP)
        ser.write(b' ')   # gate off
        time.sleep(GAP)

    print("\n--- Twinkle Twinkle Little Star ---")
    print("    Resetting: octave 4, sine wave...")

    for _ in range(8):
        ser.write(b'z')
        time.sleep(0.04)
    for _ in range(4):
        ser.write(b'x')
        time.sleep(0.04)
    ser.write(b'1')   # sine
    time.sleep(0.4)

    print("    Playing...")

    # C C G G A A G       (Twinkle twinkle little star)
    note('a', Q); note('a', Q); note('g', Q); note('g', Q)
    note('h', Q); note('h', Q); note('g', H)

    # F F E E D D C       (How I wonder what you are)
    note('f', Q); note('f', Q); note('d', Q); note('d', Q)
    note('s', Q); note('s', Q); note('a', H)

    # G G F F E E D       (Up above the world so high)
    note('g', Q); note('g', Q); note('f', Q); note('f', Q)
    note('d', Q); note('d', Q); note('s', H)

    # G G F F E E D       (Like a diamond in the sky)
    note('g', Q); note('g', Q); note('f', Q); note('f', Q)
    note('d', Q); note('d', Q); note('s', H)

    # C C G G A A G       (Twinkle twinkle little star)
    note('a', Q); note('a', Q); note('g', Q); note('g', Q)
    note('h', Q); note('h', Q); note('g', H)

    # F F E E D D C       (How I wonder what you are)
    note('f', Q); note('f', Q); note('d', Q); note('d', Q)
    note('s', Q); note('s', Q); note('a', H)

    print("    Done.")



def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', default=PORT)
    parser.add_argument('--send', help='send a single character and exit')
    parser.add_argument('--demo', choices=['twinkle'], help='play a demo song')
    args = parser.parse_args()

    try:
        ser = serial.Serial(args.port, BAUD, timeout=1)
    except serial.SerialException as e:
        print(f"Error opening {args.port}: {e}")
        sys.exit(1)

    print(f"Connected to {args.port} at {BAUD} baud")

    if args.send:
        send(ser, args.send[0])
    elif args.demo == 'twinkle':
        run_twinkle(ser)
    else:
        run_scale(ser)

    ser.close()

if __name__ == '__main__':
    main()
