#!/usr/bin/env python3
"""Synthesises the workout sounds (#169) and writes them where each platform
looks for them.

Every sound is made here from sine waves and decay envelopes — no samples, no
recordings, nothing licensed from anyone. The output is deterministic: running
this again writes the same bytes, so a diff in the .wav files means a change
here.

Each sound is written twice, because each platform plays only from its own
bundle — a notification's sound has to be a file the OS can find without the
app running:

- `ios/Runner/Sounds/<name>.wav` — the app bundle; `UNNotificationSound(named:)`
  and the in-app player both read it.
- `android/app/src/main/res/raw/<name>.wav` — a raw resource, which a
  notification channel's sound and the in-app player both name.

The names are the contract with Dart (`WorkoutSound` in heart_state, and the
`heart/sounds` channel): change one and change all three.

    python3 scripts/sounds.py
"""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

RATE = 22050  # every partial below sits under 7 kHz; half of 44.1 kHz is plenty
PEAK = 0.7  # about -3 dBFS: loud enough to hear, never clipping

ROOT = Path(__file__).resolve().parent.parent
TARGETS = (
    ROOT / 'ios' / 'Runner' / 'Sounds',
    ROOT / 'android' / 'app' / 'src' / 'main' / 'res' / 'raw',
)


def silence(seconds: float) -> list[float]:
    return [0.0] * int(seconds * RATE)


def tone(
    frequency: float,
    seconds: float,
    partials: tuple[tuple[float, float, float], ...] = ((1.0, 1.0, 1.0),),
    decay: float = 0.3,
    attack: float = 0.004,
) -> list[float]:
    """A struck note: each partial is (ratio to [frequency], amplitude, decay
    multiplier), fading exponentially with time constant [decay] × its
    multiplier, after a short linear [attack] that keeps the onset from
    clicking."""
    samples = []
    for n in range(int(seconds * RATE)):
        t = n / RATE
        rise = min(1.0, t / attack) if attack > 0 else 1.0
        value = sum(
            amplitude * math.exp(-t / (decay * multiplier)) * math.sin(2 * math.pi * frequency * ratio * t)
            for ratio, amplitude, multiplier in partials
        )
        samples.append(rise * value)
    return samples


def mix(length: float, *voices: tuple[float, list[float]]) -> list[float]:
    """[voices] as (start in seconds, samples), summed into [length] seconds."""
    out = [0.0] * int(length * RATE)
    for start, samples in voices:
        offset = int(start * RATE)
        for index, sample in enumerate(samples):
            if offset + index < len(out):
                out[offset + index] += sample
    return out


def fade_out(samples: list[float], seconds: float = 0.02) -> list[float]:
    """The last [seconds] taken to zero, so the file never ends on a click."""
    count = min(len(samples), int(seconds * RATE))
    for index in range(count):
        samples[-1 - index] *= index / count
    return samples


# a glassy, mostly-fundamental timbre for the chime and the record
GLASS = ((1.0, 1.0, 1.0), (2.0, 0.25, 0.6), (3.0, 0.08, 0.4))

# a struck bell's inharmonic partials (hum, prime, tierce, quint, nominal…)
BELL = (
    (0.5, 0.35, 1.6),
    (1.0, 1.0, 1.0),
    (1.183, 0.45, 0.8),
    (1.506, 0.3, 0.6),
    (2.0, 0.4, 0.55),
    (2.514, 0.15, 0.4),
    (3.011, 0.1, 0.3),
)

# wood: a strong fundamental and the bar's high, quickly-dying overtones
WOOD = ((1.0, 1.0, 1.0), (3.932, 0.18, 0.25), (9.538, 0.05, 0.1))


def rest_chime() -> list[float]:
    """Two glassy notes a fourth apart, rising: the rest is over, go."""
    return mix(
        1.1,
        (0.0, tone(1318.5, 0.9, GLASS, decay=0.28)),  # E6
        (0.14, tone(1760.0, 0.95, GLASS, decay=0.32)),  # A6
    )


def rest_bell() -> list[float]:
    """One struck bell, left to ring."""
    return tone(880.0, 1.4, BELL, decay=0.45, attack=0.002)


def rest_beeps() -> list[float]:
    """The kitchen timer: three short beeps."""
    beep = tone(1000.0, 0.12, ((1.0, 1.0, 1.0), (3.0, 0.12, 1.0)), decay=10.0, attack=0.006)
    beep = fade_out(beep, 0.015)
    return mix(0.66, (0.0, beep), (0.22, beep), (0.44, beep))


def rest_marimba() -> list[float]:
    """Two soft wooden notes, a fifth apart."""
    return mix(
        0.8,
        (0.0, tone(784.0, 0.6, WOOD, decay=0.16, attack=0.002)),  # G5
        (0.16, tone(1174.7, 0.62, WOOD, decay=0.18, attack=0.002)),  # D6
    )


def set_tick() -> list[float]:
    """A short, quiet pop for a ticked set: heard, not noticed."""
    samples = []
    for n in range(int(0.07 * RATE)):
        t = n / RATE
        # the pitch falls as it fades, which reads as a tap rather than a beep
        frequency = 1500.0 * math.exp(-t / 0.05) + 600.0
        samples.append(math.exp(-t / 0.012) * math.sin(2 * math.pi * frequency * t) * min(1.0, t / 0.001))
    return fade_out(samples, 0.01)


def record_fanfare() -> list[float]:
    """A quick rising arpeggio, C E G C: something worth hearing happened."""
    notes = (1046.5, 1318.5, 1568.0, 2093.0)  # C6 E6 G6 C7
    return mix(
        1.0,
        *((index * 0.075, tone(frequency, 0.75, GLASS, decay=0.22)) for index, frequency in enumerate(notes)),
    )


SOUNDS = {
    'rest_chime': rest_chime,
    'rest_bell': rest_bell,
    'rest_beeps': rest_beeps,
    'rest_marimba': rest_marimba,
    'set_tick': set_tick,
    'record_fanfare': record_fanfare,
}


def normalised(samples: list[float]) -> bytes:
    top = max(abs(sample) for sample in samples) or 1.0
    scale = PEAK * 32767 / top
    return b''.join(struct.pack('<h', round(sample * scale)) for sample in fade_out(samples, 0.01))


def main() -> None:
    for target in TARGETS:
        target.mkdir(parents=True, exist_ok=True)
    for name, make in SOUNDS.items():
        frames = normalised(make())
        for target in TARGETS:
            with wave.open(str(target / f'{name}.wav'), 'wb') as out:
                out.setnchannels(1)
                out.setsampwidth(2)
                out.setframerate(RATE)
                out.writeframes(frames)
        print(f'{name}: {len(frames) / 2 / RATE:.2f}s')


if __name__ == '__main__':
    main()
