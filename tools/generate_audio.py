"""Generate original, loopable music and short feedback tones (no external samples)."""
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050


def write(name, seconds, sample):
    path = ROOT / 'assets' / 'audio' / name
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, sample(i / RATE))) * 32767))
                                   for i in range(round(seconds * RATE))))


def main():
    # Sixteen beats at 96 BPM: exact phase recurrence at the loop boundary.
    beat = .625
    notes = [261.626, 329.628, 391.995, 329.628, 220, 261.626, 329.628, 261.626,
             174.614, 220, 261.626, 220, 195.998, 246.942, 293.665, 246.942]

    def music(t):
        index = min(15, int(t / beat))
        phase = t % beat
        envelope = min(1, phase / .025) * max(0, 1 - phase / beat) ** 2
        frequency = notes[index]
        return .17 * envelope * (math.sin(2 * math.pi * frequency * phase)
                                 + .2 * math.sin(4 * math.pi * frequency * phase))

    write('shore-loop.wav', 16 * beat, music)
    write('collect.wav', .25, lambda t: .15 * math.sin(2 * math.pi * (660 + 400 * t) * t)
          * min(1, t / .01) * max(0, 1 - t / .25) ** 2)
    write('confirm.wav', .4, lambda t: .13 * math.sin(2 * math.pi * (523.25 if t < .15 else 783.99) * t)
          * min(1, t / .01) * max(0, 1 - t / .4) ** 2)


if __name__ == '__main__':
    main()
