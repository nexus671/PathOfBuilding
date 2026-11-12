"""Generate original reference tones, not Path of Exile sound assets."""
import math
import struct
import wave
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "src/Assets/LootFilters"
root.mkdir(parents=True, exist_ok=True)
for alert in range(1, 17):
    samples = []
    rate = 22050
    for index in range(int(rate * 0.4)):
        time = index / rate
        envelope = min(1, time / 0.015) * max(0, 1 - time / 0.4) ** 2
        frequency = 330 + alert * 35
        value = envelope * (math.sin(2 * math.pi * frequency * time) + 0.3 * math.sin(2 * math.pi * frequency * 1.5 * time))
        samples.append(struct.pack("<h", int(11000 * value)))
    with wave.open(str(root / f"alert-{alert}.wav"), "wb") as output:
        output.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        output.writeframes(b"".join(samples))
print("Generated 16 original alert reference tones")
