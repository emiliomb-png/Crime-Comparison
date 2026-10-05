# U.S. vs. Europe homicide rates
# ______________________________
# HOW TO RUN: open the project's .Rproj file in RStudio (this sets the working
# directory to the project folder), then run this script from top to bottom.
#
# Required folder layout:
#   Data/Underlying Cause of Death, 2018-2024, Single Race.tsv   (CDC WONDER export)
#   Results/                                                     (created by this script)
#
# Requires an internet connection (WHO and World Bank data are downloaded).

# SETUP

pkgs    <- c("WDI", "dplyr", "ggplot2", "ggrepel", "patchwork", "scales")
missing <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(missing) > 0) install.packages(missing)

library(WDI)
library(dplyr)
library(ggplot2)
library(ggrepel)
library(patchwork)
library(scales)

dir.create("Results", showWarnings = FALSE)

# DATA WRANGLING
# ______________

# 1. Countries: EU27 + UK + US
countries <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","GR",
               "HU","IE","IT","LV","LT","LU","MT","NL","PL","PT","RO","SK",
               "SI","ES","SE","GB","US")

# 2. World Bank: population, GDP per capita (PPP), Gini
wb <- WDI(
  country   = countries,
  indicator = c(population = "SP.POP.TOTL",
                gdp_pc     = "NY.GDP.PCAP.PP.CD",
                gini       = "SI.POV.GINI"),
  start = 2000,
  end   = 2023
) |>
  select(country, iso3c, year, population, gdp_pc, gini)

# 3. WHO homicide rate (OWID): standardize column names
who <- read.csv("https://ourworldindata.org/grapher/homicide-rate-who-mortality-database.csv?v=1&csvType=full&useColumnShortNames=true")

names(who)            # check this: expect entity, code, year, then the rate column
names(who)[1:4] <- c("country_who", "iso3c", "year", "homicide_rate")

who <- who |> select(iso3c, year, homicide_rate)

# 4. Country-year panel (for the line chart and Europe benchmark)
panel <- wb |>
  left_join(who, by = c("iso3c", "year")) |>
  mutate(homicides = homicide_rate * population / 100000)

# 5. Europe benchmark: population-weighted, by year
# Only countries with homicide data in that year are counted in both numerator and denominator
europe_benchmark <- panel |>
  filter(iso3c != "USA", !is.na(homicide_rate), year <= 2020) |>
  group_by(year) |>
  summarise(
    n_countries   = n(),
    homicides     = sum(homicides),
    population    = sum(population),
    homicide_rate = homicides / population * 100000,
    .groups = "drop"
  )

# 6. Country-level table: 2018-2022 averages (for the bar chart and scatter plots)
country_avg <- panel |>
  filter(year >= 2018, year <= 2022) |>
  group_by(country, iso3c) |>
  summarise(
    n_years_homicide = sum(!is.na(homicide_rate)),
    n_years_gini     = sum(!is.na(gini)),
    homicide_rate    = mean(homicide_rate, na.rm = TRUE),
    gdp_pc           = mean(gdp_pc, na.rm = TRUE),
    gini             = mean(gini, na.rm = TRUE),
    population       = mean(population, na.rm = TRUE),
    .groups = "drop"
  )

# 7. Gini fallback (countries with no Gini in the window use their latest earlier value)
gini_fallback <- wb |>
  filter(year >= 2015, year <= 2022, !is.na(gini)) |>
  group_by(iso3c) |>
  slice_max(year, n = 1) |>
  ungroup() |>
  select(iso3c, gini_fallback = gini, gini_fallback_year = year)

country_avg <- country_avg |>
  left_join(gini_fallback, by = "iso3c") |>
  mutate(
    gini_filled = is.nan(gini) | is.na(gini),
    gini        = if_else(gini_filled, gini_fallback, gini)
  )

country_avg |> filter(iso3c == "HUN") |> select(country, gini, gini_fallback_year)

# 8. CDC: homicide by U.S. state
# Manual export from CDC WONDER, saved in the Data folder (the CDC API only returns national data)
cdc_file <- file.path("Data", "Underlying Cause of Death, 2018-2024, Single Race.tsv")

if (!file.exists(cdc_file)) {
  stop("CDC file not found: ", cdc_file, "\n",
       "Put the CDC WONDER export in the 'Data' folder of the project.\n",
       "R is currently looking in: ", getwd())
}

cdc <- read.delim(cdc_file, nrows = 51, quote = "\"")

cdc_states <- cdc |>
  transmute(state = State,
            deaths = Deaths,
            population = Population,
            homicide_rate = as.numeric(Crude.Rate))

cdc_states |> arrange(homicide_rate) |> slice(c(1:3, 49:51))

# 9. Save the tables
write.csv(country_avg,      file.path("Results", "country_avg.csv"),      row.names = FALSE)
write.csv(panel,            file.path("Results", "panel.csv"),            row.names = FALSE)
write.csv(europe_benchmark, file.path("Results", "europe_benchmark.csv"), row.names = FALSE)
write.csv(cdc_states,       file.path("Results", "cdc_states.csv"),       row.names = FALSE)

# DATA ANALYSIS
# _____________

country_avg$country <- recode(country_avg$country, "Slovak Republic" = "Slovakia")
panel$country       <- recode(panel$country,       "Slovak Republic" = "Slovakia")

us_col <- "#C0392B"
eu_col <- "#5B7FA6"

# Population-weighted Europe average over the same 2018-2022 window as the bars
europe_avg <- country_avg |>
  filter(iso3c != "USA") |>
  summarise(v = weighted.mean(homicide_rate, population)) |>
  pull(v)
us_rate <- country_avg |> filter(iso3c == "USA") |> pull(homicide_rate)
ratio   <- us_rate / europe_avg

# ---- Chart 1: ranked bar chart ----
p1 <- country_avg |>
  mutate(group = if_else(iso3c == "USA", "United States", "Europe")) |>
  ggplot(aes(x = reorder(country, homicide_rate), y = homicide_rate, fill = group)) +
  geom_col(width = 0.75) +
  geom_text(aes(label = sprintf("%.1f", homicide_rate)), hjust = -0.2, size = 3) +
  geom_hline(yintercept = europe_avg, linetype = "dashed", color = "grey60") +
  annotate("text", x = 3, y = europe_avg + 0.2,
           label = sprintf("Europe avg: %.2f", europe_avg),
           hjust = 0, size = 3.3, color = "grey60") +
  coord_flip() +
  scale_fill_manual(values = c("United States" = us_col, "Europe" = eu_col), guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
  labs(
    title    = sprintf("The U.S. homicide rate is about %.0fx Europe's", ratio),
    subtitle = "Homicides per 100,000 residents, 2018-2022 average",
    x = NULL, y = NULL,
    caption  = "Source: WHO Mortality Database via Our World in Data; World Bank. Europe = EU27 + UK, population-weighted.\nSome countries have only 3-4 years of data in the window."
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.major.y = element_blank())

# ---- Chart 2: trend over time ----
line_data <- bind_rows(
  europe_benchmark |> transmute(year, homicide_rate, series = "Europe"),
  panel |> filter(iso3c == "USA", !is.na(homicide_rate)) |>
    transmute(year, homicide_rate, series = "U.S.")
)
end_labels <- line_data |> group_by(series) |> filter(year == max(year)) |> ungroup()

p2 <- ggplot(line_data, aes(x = year, y = homicide_rate, color = series)) +
  annotate("rect", xmin = 2019.5, xmax = 2021.5, ymin = -Inf, ymax = Inf,
           fill = "grey85", alpha = 0.5) +
  annotate("text", x = 2020.5, y = 0.2, label = "COVID-19", size = 3, color = "grey40") +
  geom_line(linewidth = 1.2) +
  geom_text(data = end_labels, aes(label = series), hjust = -0.2,
            fontface = "bold", size = 3.8) +
  scale_color_manual(values = c("U.S." = us_col, "Europe" = eu_col), guide = "none") +
  scale_x_continuous(breaks = seq(2000, 2022, 2), limits = c(2000, 2025)) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.08))) +
  labs(
    title    = "Europe and the U.S.",
    subtitle = "Homicides per 100,000 residents",
    x = NULL, y = NULL,
    caption  = "Europe = EU27 + UK, population-weighted, shown through 2020 (latest year with near-complete WHO reporting).\nU.S. shown through 2022. Source: WHO Mortality Database via Our World in Data; World Bank."
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

# ---- Chart 3: European countries vs. U.S. states ----
set.seed(42)
chart3_data <- bind_rows(
  country_avg |> filter(iso3c != "USA") |>
    transmute(label = country, homicide_rate, group = "European countries (n = 28)"),
  cdc_states |>
    transmute(label = recode(state, "District of Columbia" = "D.C."),
              homicide_rate, group = "U.S. states + D.C. (n = 51)")
) |>
  mutate(group = factor(group, levels = c("European countries (n = 28)",
                                          "U.S. states + D.C. (n = 51)")),
         x_pos = as.numeric(group) + runif(n(), -0.15, 0.15))

label_these <- c("D.C.", "Mississippi", "Louisiana", "New Hampshire", "Maine",
                 "Latvia", "Estonia", "Ireland")

p3 <- ggplot(chart3_data, aes(x = x_pos, y = homicide_rate, color = group)) +
  geom_boxplot(aes(x = as.numeric(group), group = group), width = 0.45,
               outlier.shape = NA, fill = NA, linewidth = 0.5) +
  geom_point(size = 2.2, alpha = 0.8) +
  geom_hline(yintercept = europe_avg, linetype = "dashed", color = "grey40") +
  geom_text_repel(data = filter(chart3_data, label %in% label_these),
                  aes(label = label), size = 3, color = "grey20",
                  min.segment.length = 0, box.padding = 0.4, show.legend = FALSE) +
  scale_x_continuous(breaks = 1:2, labels = levels(chart3_data$group), limits = c(0.5, 2.5)) +
  scale_color_manual(values = c(eu_col, us_col), guide = "none") +
  labs(
    title    = "Homicide rates across U.S. states vs. European countries",
    subtitle = "Homicides per 100,000 residents, 2018-2022 average. Dashed line = Europe average.",
    x = NULL, y = NULL,
    caption  = "Sources: WHO Mortality Database (countries); CDC WONDER (states, ICD-10 X85-Y09, Y87.1).\nBoth are death-certificate based."
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.major.x = element_blank())

# ---- Chart 4: wealth and inequality (two panels) ----
make_scatter <- function(xvar, xlab, label_set, hungary_flag = FALSE) {
  d <- country_avg |>
    mutate(group   = if_else(iso3c == "USA", "United States", "Europe"),
           flagged = if (hungary_flag) gini_filled else FALSE)
  ggplot(d, aes(x = .data[[xvar]], y = homicide_rate)) +
    geom_smooth(data = filter(d, group == "Europe"), formula = y ~ x, method = "lm",
                se = FALSE, color = "grey60", linetype = "dashed", linewidth = 0.6) +
    geom_point(aes(color = group, shape = flagged), size = 3) +
    geom_text_repel(data = filter(d, country %in% label_set), aes(label = country),
                    size = 3, min.segment.length = 0) +
    scale_color_manual(values = c("United States" = us_col, "Europe" = eu_col), guide = "none") +
    scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 17), guide = "none") +
    labs(x = xlab, y = "Homicides per 100,000") +
    theme_minimal(base_size = 12)
}

p4a <- make_scatter("gdp_pc", "GDP per capita (PPP, 2018-2022 avg)",
                    c("United States", "Luxembourg", "Ireland", "Latvia")) +
  scale_x_continuous(labels = label_dollar(scale = 1/1000, suffix = "k")) +
  labs(title = "Wealth")

p4b <- make_scatter("gini", "Gini coefficient (income inequality, 2018-2022 avg)",
                    c("United States", "Latvia", "Lithuania", "Bulgaria", "Hungary"),
                    hungary_flag = TRUE) +
  labs(title = "Inequality")

p4 <- (p4a | p4b) +
  plot_annotation(
    title    = "Neither wealth nor inequality alone explains the U.S. gap",
    subtitle = "Dashed line = linear fit for the 28 European countries only",
    caption  = "Triangle = Hungary (Gini from 2017). Sources: WHO, World Bank."
  )

# ---- Save charts ----
ggsave(file.path("Results", "chart1_bar.png"),     p1, width = 8,  height = 7, dpi = 300)
ggsave(file.path("Results", "chart2_line.png"),    p2, width = 8,  height = 5, dpi = 300)
ggsave(file.path("Results", "chart3_states.png"),  p3, width = 7,  height = 6, dpi = 300)
ggsave(file.path("Results", "chart4_scatter.png"), p4, width = 11, height = 5, dpi = 300)