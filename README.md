# Respiratory Illness Activity Levels

Weekly activity levels for flu, RSV, and COVID-19 in the six counties of
Health District 3: Adams, Canyon, Gem, Owyhee, Payette, and Washington.

**Live page:** https://southwest-district-health.github.io/respiratory-activity-levels/

Updated every Monday during respiratory virus season, September through May.

---

## What the page shows

Each county gets one of five levels for each disease: Minimal, Low, Moderate,
High, or Very High. The level tells you how busy emergency rooms are with that
illness compared with a quiet stretch of the year, when very few people are
sick with it.

Below the map, the page lists every county's level in plain text, so you don't
have to hover over the map to read it. The right side of the page covers what
the levels mean for you and simple steps to protect yourself and others.

## How the levels are calculated

The calculation starts with weekly emergency room visits for each illness in
each county. Those weekly numbers are smoothed with an exponentially weighted
moving average, which keeps one unusual week from swinging the level up or
down on its own.

The smoothed value is then compared with that county's baseline for that
illness. How far it sits above the baseline, measured in standard deviations,
decides the level. The cut points are set once in `build_levels.R`, and the
same numbers feed both the map colors and the explanation printed on the
page, so the two always agree.

Only the level itself is published. Visit counts and the smoothed values stay
on the district's machines.

## What's in this repo

| File | What it is |
|---|---|
| `index.html` | The published page. Everything it needs is inside this one file. |
| `build_levels.R` | Calculates the levels and writes `index.html`. |
| `levels_template.html` | Page layout, styling, and the guidance text. |
| `hd3_counties.geojson` | Simplified county boundaries from the Census Bureau. |
| `Activity_Levels_Table_1.png` | The "what each level means" table shown on the page. |
| `REFRESH.md` | Step-by-step weekly update instructions. |

The weekly Excel exports and the running log of published levels are
deliberately kept out of this repo.

## Updating the page

See [`REFRESH.md`](REFRESH.md). The short version: drop in the new data,
change one date, run the script, upload `index.html`.

## Map credits

Basemap tiles are provided by Esri, under Southwest District Health's ArcGIS
Online license. The attribution in the corner of the map is required by Esri's
terms and should stay in place. County boundaries come from the U.S. Census
Bureau's 2020 TIGER/Line files.

## Contact

Maintained by Lekshmi Rita-Venugopal
Epidemiologist Program Manager 1
Southwest District Health.

This page is for general awareness and is not a medical diagnosis.
