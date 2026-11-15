# Mission Selene — Junior Astronaut Mission Trainer 🌒🧑‍🚀

A small, kid-friendly strategy game for the **2026 NASA Space Apps Challenge**
("Build a Junior Astronaut Mission Trainer"). You run a lunar outpost for ten
24-hour shifts (*sels*) and must keep the crew alive while balancing life
support, radiation shielding, power, food production and communication with
Earth.

## Play

| Action | What it does |
| --- | --- |
| **Play a card** | Spend battery to produce food/water, repair panels, exercise or collect science. Up to 3 cards per sel. |
| **☀️ End Day** | Run the night: panels decay, batteries charge/drain, oxygen/food/water tick, radiation and low gravity affect health. |
| **🛡️ Shelter** | During a solar storm, spend 8 battery to halve the storm's radiation bonus for that night. |
| **📡 Downlink** | Send waiting science points to Earth for 4 battery. Storms cause radio blackouts, so you may have to wait. |
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
its class, date, event ID and a link to the event page. The Data panel and the
end screen state that the values are **archived**, never live.

### Numbers and units

Game values use a friendly 0–100 scale. The conversion is defined in one place,
`game/data/constants.gd`:

- **1 radiation unit = 0.07 mSv/day** (so the base of 20 units ≈ 1.4 mSv/day,
  the lunar-surface reference used by the game).
- C/M/X storms add **+15 / +35 / +60** radiation units for **2 sels**; X-class
  storms also damage panels by 10%.
- Radiation health damage is `ceil(effective radiation / 25)` per night.
- The RadLab/OSDR figure is **absorbed dose in silicon (µGy/h)**, not a human
  equivalent dose; the Data panel says so explicitly.

Card, storm and scoring numbers live only in `constants.gd`; the DONKI archive
stores real event identity only, never gameplay tuning.

## Regenerate the embedded data

Requires Python 3.10+ and internet access (build time only):

```bash
python3 tools/fetch_nasa_data.py
```

The script uses NASA's CCMC DONKI service by default. If `NASA_API_KEY` is set,
it tries `api.nasa.gov` first. For APOD it uses `NASA_APOD_API_KEY` from the
environment or from `game/.env`, then falls back to the public APOD JSON feed.
`game/.env` is git-ignored and is never included in a build; do not put keys in
exported projects.

## Develop and test

Open `game/project.godot` in Godot 4.7 or run:

```bash
cd game
godot --path .                        # play
godot --headless --path . res://tests/test_runner.tscn   # rules + data tests
```

The test runner checks night math (including the Exercise oxygen rule), units,
storm/shelter damage, deck and crisis determinism, the discard cycle, the
DONKI archive schema, and a full ten-sel mission through the real scene.

## Web export

`game/export_presets.cfg` defines a **Web** preset with the **Compatibility**
renderer and threads disabled. JSON and image files are explicitly included
because Godot excludes `*.json` by default:

```
include_filter="*.json,*.jpg,*.png"
```

Export from the editor or:

```bash
cd game
godot --headless --export-release "Web" build/web/index.html
```

Serve the exported folder over HTTP (for example
`python3 -m http.server --directory build/web`) and test in a browser. The game
does not fetch anything at runtime, so it also works without a network
connection once loaded.

## Attribution

- Solar flare, SEP and CME data: **NASA DONKI / CCMC**.
- Radiation baseline: **NASA RadLab / OSDR**, CRaTER-D1D2 instrument on LRO.
- Astronomy picture: **NASA APOD**, with the photographer's credit shown in
  game.
- Space-weather context: **NOAA SWPC** (labelled separately from NASA data).
- UI emoji: **Noto Emoji** (SIL Open Font License), bundled so the Web export
  renders emoji without a system font.
- Built with **Godot Engine 4.7**.

NASA does not endorse this game. It is a challenge prototype; the simplified
0–100 values are for gameplay, not for mission planning.
