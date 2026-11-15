# Mission Selene — Junior Astronaut Mission Trainer 🌒🧑‍🚀

> Mission Selene: the game title is named after the Ancient Greek goddess and personification of the Moon.

A small, kid-friendly strategy game for the **2026 NASA Space Apps Challenge: "Build a Junior Astronaut Mission Trainer"**. You run a lunar outpost for ten lunar revolutions (__*Sels*__) and must keep the crew alive while balancing life
support, radiation shielding, power, food production and communication with
Earth.

> *Sel* is a word that we invented (Sel -> Selene) for semplicity that represent a lunar revolution.

## Play

| Action | What it does |
| --- | --- |
| **Play a card** | Spend battery to produce food/water, repair panels, exercise or collect science. Up to 3 cards per sel. |
| **☀️ End Sel** | Panels decay, batteries charge/drain, oxygen/food/water tick, radiation and low gravity affect health. |
| **🛡️ Shelter** | During a solar storm, spend 8 battery to halve the storm's radiation bonus for that sel. |
| **📡 Downlink** | Send waiting science points to Earth for 4 battery. New data needs one sel to be packaged, and storms cause radio blackouts, so you may have to wait. |
| **🛰️ Data** | Shows every real NASA source used, with links and the archived retrieval date. |

You win by surviving all ten sels with oxygen, food and water above zero. The
final score rewards health, remaining supplies and **downlinked** science.
After a mission you can start a new one or retry the same mission seed.

### Mission seeds

Each mission has a four-letter seed shown in the top bar. The same seed always
produces the same card order and the same sequence of solar storms, so a
classroom can compare strategies on an identical mission.

## NASA data, embedded at build time

The game makes **no network requests at runtime** and needs no API key to play.
Real data is fetched once by `tools/fetch_nasa_data.py` and committed as game
assets, so the Web export works offline:

| File | Source |
| --- | --- |
| `game/data/donki_events.json` | [NASA DONKI](https://ccmc.gsfc.nasa.gov/tools/DONKI/) — solar flares (FLR), solar energetic particles (SEP) and coronal mass ejections (CME). Curated: all selected X-class flares (up to 4) plus 2 M-class and 2 C-class events. |
| `game/data/nasa_reference.json` | [NASA RadLab / OSDR](https://visualization.osdr.nasa.gov/radlab/) CRaTER-D1D2 (LRO) absorbed-dose baseline, the latest [APOD](https://apod.nasa.gov/) entry, and NOAA SWPC Kp (clearly labelled as NOAA, not NASA). |
| `game/data/apod_fallback.jpg` | Astronomy Picture of the Day image, bundled for offline display (credit shown in game). |

Every solar storm in the game is tied to a **real DONKI event**: the UI shows
its class, date, event ID and a link to the event page.

### Numbers and units

Game values use a friendly 0–100 scale. The conversion is defined in one place,
`game/data/constants.gd`:

- **1 radiation unit = 0.07 mSv/day** (so the base of 20 units ≈ 1.4 mSv/day,
  the lunar-surface reference used by the game).
- C/M/X storms add **+15 / +35 / +60** radiation units for **2 sels**; X-class
  storms also damage panels by 10%.
- Radiation health damage is `ceil(effective radiation / 25)` per sel.
- The RadLab/OSDR figure is **absorbed dose in silicon (µGy/h)**, not a human
  equivalent dose; the Data panel says so explicitly.

## Regenerate the embedded data

Requires Python 3.10+ and internet access (build time only):

```bash
python3 tools/fetch_nasa_data.py
```

## Develop

Open `game/project.godot` in Godot 4.7 or run:

```bash
cd game
godot --path .                        # play
```

## Attribution

- Solar flare, SEP and CME data: **NASA DONKI / CCMC**.
- Radiation baseline: **NASA RadLab / OSDR**, CRaTER-D1D2 instrument on LRO.
- Astronomy picture: **NASA APOD**, with the photographer's credit shown in
  game.
- UI emoji: **EmojiOne Color** (MIT License).
- Built with **Godot Engine 4.7**.
