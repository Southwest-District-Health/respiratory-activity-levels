# Weekly refresh

How to update the activity levels page each Monday, September through May.
It takes about ten minutes, and anyone with access to the ED visit exports and
write access to this repo can do it.

All the work happens in the project folder:
`Documents\Respiratory activity map` (in R, `~/Respiratory activity map`).

---

## 1. Drop in this week's data

Save the three exports into the project folder, replacing last week's files:

- `flulevels.xlsx`
- `rsvlevels.xlsx`
- `covidlevels.xlsx`

Each file needs one column per county: `ID_Adams`, `ID_Canyon`, `ID_Gem`,
`ID_Owyhee`, `ID_Payette`, and `ID_Washington`. The script drops the last row
of each file, the same way the original app did.

If a column is missing or has a blank cell, the script stops and tells you
which file and which county. It won't publish a page with a hole in it.

## 2. Change the date

Open `build_levels.R` and update `WEEK_ENDING` near the top:

```r
WEEK_ENDING <- "09/19/26"
```

This is the only date the public sees, so it's worth a second look. Use the
Saturday that ends the week the data covers.

## 3. Run the script

```r
source("build_levels.R", echo = TRUE)
```

When it finishes, the console prints a small table with every county's level
for flu, RSV, and COVID-19. Read it before you publish. A county jumping two or
more levels in one week isn't necessarily wrong, but it's worth a quick look at
the source data before it goes out.

## 4. Check the page

Open `index.html` from the project folder in a browser. Look at three things:

- The header shows this week's date.
- Each disease shows the colors you expect from the console table.
- The street map loads behind the counties.

## 5. Publish

In this repo, click **Add file**, then **Upload files**, and drag in the new
`index.html`. Commit with a message like `Week ending 09/19/26`.

GitHub updates the live page within a couple of minutes. Open it and press
**Ctrl+F5** to skip your browser's saved copy, then confirm the date in the
header.

Only upload `index.html`. The Excel files and the log stay on your machine.

---

## Good to know

**The published log.** Every run adds that week's levels to
`published_levels_log.csv` in the project folder. If you rerun the same week,
it replaces that week's rows instead of adding duplicates. Keep this file
somewhere backed up. It's the answer to "what did the map say on this date?"

**County boundaries.** `hd3_counties.geojson` was built once from the Census
shapefile. You only need to rebuild it if boundaries change: delete the file
and rerun the script, and it will rebuild from the shapefile (downloading it
if needed).

**Level thresholds.** `THRESHOLDS` in `build_levels.R` sets where each level
begins, in standard deviations above baseline. The same numbers color the map
and write the explanation on the page. Changing them changes the published
method, so treat that as a program decision, not a quick edit.

**Baselines.** Each county's baseline center and SD for each disease live in
the `DISEASES` block of `build_levels.R`. Update them there when baselines are
recalculated for a new season.

**Off-season.** Between June and August, nothing needs to happen. If the
district decides to keep the page live over summer, update `UPDATE_NOTE` in
the script so the header doesn't promise weekly updates.

**Basemap.** The street map comes from Esri under the district's ArcGIS
Online license. Leave the attribution line in the corner of the map as is.
