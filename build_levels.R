# build_levels.R ------------------------------------------------------------
# Computes weekly respiratory illness activity levels (Flu, RSV, COVID-19) by
# county and writes index.html: a standalone page with the map, methodology,
# and guidance panels. No Shiny server needed.
#
# Author: Lekshmi Rita-Venugopal, Southwest District Health
#
# Run:  source("build_levels.R", echo = TRUE)
#
# Needs in the project folder:
#   flulevels.xlsx, rsvlevels.xlsx, covidlevels.xlsx
#   levels_template.html
#   Activity_Levels_Table_1.png   (here or in www/)
#   tl_2020_us_county.shp         (first run only; downloaded if missing)
# ---------------------------------------------------------------------------

PROJECT_DIR <- "~/Respiratory activity map"
setwd(PROJECT_DIR)

library(tidyverse)
library(readxl)
library(sf)
library(jsonlite)

# --- Settings to review each week -----------------------------------------
WEEK_ENDING <- "09/12/26"                 # shown in the page header
UPDATE_NOTE <- "Updated every Monday during respiratory virus season (September through May)"

# --- Settings that rarely change -------------------------------------------
TEMPLATE  <- "levels_template.html"
OUT_HTML  <- "index.html"
OUT_LOG   <- "published_levels_log.csv"   # running record of every week published
GEO_CACHE <- "hd3_counties.geojson"       # built once from the shapefile

DEFAULT_DISEASE <- "flu"

# SD above baseline where each level begins: Low, Moderate, High, Very High.

THRESHOLDS <- c(2, 4, 7, 9)

LEVEL_NAMES  <- c("Minimal", "Low", "Moderate", "High", "Very High")
LEVEL_COLORS <- c("#008B00",   # green4
                  "#FFD700",   # gold
                  "#FF4500",   # orangered
                  "#CD0000",   # red3
                  "#551A8B")   # purple4

TABLE_IMAGE <- "Activity_Levels_Table_1.png"
TABLE_ALT   <- paste("Table explaining what each respiratory illness activity",
                     "level means and the recommended actions at each level.")

COUNTIES <- c("Adams", "Canyon", "Gem", "Owyhee", "Payette", "Washington")

DISEASES <- list(
  flu = list(
    label = "Influenza (Flu)",
    file  = "flulevels.xlsx",
    baselines = list(
      canyon     = list(center = 1.481, sd = 0.620),
      adams      = list(center = 0.646, sd = 0.583),
      gem        = list(center = 0.737, sd = 0.491),
      owyhee     = list(center = 1.285, sd = 0.763),
      payette    = list(center = 0.811, sd = 0.483),
      washington = list(center = 0.731, sd = 0.561)
    )
  ),
  rsv = list(
    label = "Respiratory Syncytial Virus (RSV)",
    file  = "rsvlevels.xlsx",
    baselines = list(
      canyon     = list(center = 0.044, sd = 0.061),
      adams      = list(center = 0.010, sd = 0.027),
      gem        = list(center = 0.024, sd = 0.053),
      owyhee     = list(center = 0.023, sd = 0.051),
      payette    = list(center = 0.022, sd = 0.040),
      washington = list(center = 0.016, sd = 0.041)
    )
  ),
  covid = list(
    label = "SARS-CoV-2 (COVID-19)",
    file  = "covidlevels.xlsx",
    baselines = list(
      canyon     = list(center = 2.613, sd = 0.791),
      adams      = list(center = 1.966, sd = 0.977),
      gem        = list(center = 1.962, sd = 0.912),
      owyhee     = list(center = 2.309, sd = 0.804),
      payette    = list(center = 2.307, sd = 0.908),
      washington = list(center = 1.985, sd = 0.863)
    )
  )
)

stopifnot(length(THRESHOLDS) == 4, !is.unsorted(THRESHOLDS),
          DEFAULT_DISEASE %in% names(DISEASES))

if (!file.exists(TEMPLATE)) {
  stop(TEMPLATE, " not found in ", getwd(), call. = FALSE)
}

# --- 1. County boundaries (built once, then reused) ------------------------
if (!file.exists(GEO_CACHE)) {
  message("Building ", GEO_CACHE, " from the county shapefile (first run only)...")

  shp <- c("tl_2020_us_county.shp",
           file.path("tl_2020_us_county", "tl_2020_us_county.shp"))
  shp <- shp[file.exists(shp)][1]

  if (is.na(shp)) {
    message("Shapefile not found. Downloading from Census TIGER...")
    zip <- "tl_2020_us_county.zip"
    download.file(
      "https://www2.census.gov/geo/tiger/TIGER2020/COUNTY/tl_2020_us_county.zip",
      zip, mode = "wb"
    )
    unzip(zip, exdir = "tl_2020_us_county")
    shp <- file.path("tl_2020_us_county", "tl_2020_us_county.shp")
  }

  hd3 <- st_read(shp, quiet = TRUE) %>%
    filter(STATEFP == "16", NAME %in% COUNTIES) %>%
    select(NAME, GEOID) %>%
    st_transform(5070)

  # Full-resolution TIGER lines are far more detail than a zoom-7 map needs.
  # rmapshaper keeps shared borders aligned; st_simplify is the fallback.
  hd3 <- if (requireNamespace("rmapshaper", quietly = TRUE)) {
    rmapshaper::ms_simplify(hd3, keep = 0.05, keep_shapes = TRUE)
  } else {
    st_simplify(hd3, preserveTopology = TRUE, dTolerance = 150)
  }

  st_write(st_transform(hd3, 4326), GEO_CACHE, driver = "GeoJSON",
           layer_options = "COORDINATE_PRECISION=5",
           delete_dsn = TRUE, quiet = TRUE)

  message("Saved ", GEO_CACHE, " (", round(file.size(GEO_CACHE) / 1024), " KB)")
}

geo_names <- st_read(GEO_CACHE, quiet = TRUE)$NAME
if (length(setdiff(COUNTIES, geo_names))) {
  stop("Missing from ", GEO_CACHE, ": ",
       paste(setdiff(COUNTIES, geo_names), collapse = ", "),
       ". Delete the file and rerun to rebuild it.", call. = FALSE)
}
geojson <- paste(readLines(GEO_CACHE, warn = FALSE), collapse = "\n")

# --- 2. Activity level calculation (same method as the Shiny app) ----------
make_ewma <- function(vals, alpha = 0.3) {
  ewma <- numeric(length(vals))
  ewma[1] <- vals[1]
  for (i in 2:length(vals)) {
    ewma[i] <- alpha * vals[i] + (1 - alpha) * ewma[i - 1]
  }
  ewma
}

make_activity <- function(ewma, center, sd, cut = THRESHOLDS) {
  b <- center + cut * sd
  case_when(
    ewma <= b[1] ~ 1L,
    ewma <= b[2] ~ 2L,
    ewma <= b[3] ~ 3L,
    ewma <= b[4] ~ 4L,
    ewma >  b[4] ~ 5L
  )
}

process_disease <- function(id, d) {
  if (!file.exists(d$file)) {
    stop(d$file, " not found in ", getwd(), call. = FALSE)
  }

  # The final row is dropped, as in the original app.
  dat  <- read_excel(d$file) %>% slice(-n())
  cols <- paste0("ID_", COUNTIES)

  missing <- setdiff(cols, names(dat))
  if (length(missing)) {
    stop(d$file, " is missing column(s): ", paste(missing, collapse = ", "),
         call. = FALSE)
  }

  levels_now <- map_int(COUNTIES, function(cty) {
    b    <- d$baselines[[tolower(cty)]]
    ewma <- make_ewma(dat[[paste0("ID_", cty)]])
    tail(make_activity(ewma, b$center, b$sd), 1)
  })

  if (anyNA(levels_now)) {
    stop(d$file, ": no activity level for ",
         paste(COUNTIES[is.na(levels_now)], collapse = ", "),
         ". Check for blank cells in that county's column.", call. = FALSE)
  }

  tibble(Disease = id, County = COUNTIES, Level = levels_now)
}

results <- imap_dfr(DISEASES, ~ process_disease(.y, .x))

# --- 3. Keep a running record of what was published ------------------------
this_week <- results %>%
  mutate(LevelName  = LEVEL_NAMES[Level],
         WeekEnding = WEEK_ENDING,
         Thresholds = paste(THRESHOLDS, collapse = "/")) %>%
  select(WeekEnding, Disease, County, Level, LevelName, Thresholds) %>%
  mutate(across(everything(), as.character))

if (file.exists(OUT_LOG)) {
  prior <- read_csv(OUT_LOG, col_types = cols(.default = "c")) %>%
    filter(WeekEnding != WEEK_ENDING)   # rerunning a week replaces it
  this_week <- bind_rows(prior, this_week)
}
write_csv(this_week, OUT_LOG)

# --- 4. Table image, embedded so the page stays a single file --------------
img_path  <- c(TABLE_IMAGE, file.path("www", TABLE_IMAGE))
img_path  <- img_path[file.exists(img_path)][1]
table_uri <- if (!is.na(img_path)) {
  base64enc::dataURI(file = img_path, mime = "image/png")
} else {
  warning(TABLE_IMAGE, " not found. The page will build without it.",
          call. = FALSE)
  NA_character_
}

# --- 5. Assemble the payload ----------------------------------------------
levels_payload <- results %>%
  split(.$Disease) %>%
  map(~ as.list(set_names(.x$Level, .x$County)))

payload <- list(
  weekEnding     = WEEK_ENDING,
  updateNote     = UPDATE_NOTE,
  defaultDisease = DEFAULT_DISEASE,
  diseases       = map(names(DISEASES),
                       ~ list(id = .x, label = DISEASES[[.x]]$label)),
  counties       = I(COUNTIES),
  thresholds     = I(THRESHOLDS),
  levelNames     = I(LEVEL_NAMES),
  levelColors    = I(LEVEL_COLORS),
  levels         = levels_payload,
  tableImage     = table_uri,
  tableAlt       = TABLE_ALT,
  geojson        = structure(geojson, class = "json")
)

json <- toJSON(payload, auto_unbox = TRUE, json_verbatim = TRUE,
               na = "null", null = "null")

# --- 6. Inject into the template ------------------------------------------
tpl   <- paste(readLines(TEMPLATE, warn = FALSE), collapse = "\n")
parts <- strsplit(tpl, "/*__DATA__*/", fixed = TRUE)[[1]]

if (length(parts) != 2) {
  stop("Could not find the /*__DATA__*/ placeholder in ", TEMPLATE,
       ". Use the original template file.", call. = FALSE)
}

writeLines(paste0(parts[1], json, parts[2]), OUT_HTML, useBytes = TRUE)

# --- 7. Report -------------------------------------------------------------
message("\nWrote ", normalizePath(OUT_HTML), " (",
        round(file.size(OUT_HTML) / 1024), " KB)")
message("Week ending: ", WEEK_ENDING,
        " | thresholds: ", paste(THRESHOLDS, collapse = "/"), " SD\n")

results %>%
  mutate(Level = LEVEL_NAMES[Level]) %>%
  pivot_wider(names_from = Disease, values_from = Level) %>%
  print()
