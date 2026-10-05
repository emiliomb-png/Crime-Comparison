# Homicide in the U.S. vs. Europe

A class project comparing homicide rates in the United States with those in the EU27 + UK, using country-level data and a state-level breakdown for the U.S.

## Question

Is there a meaningful difference in lethal violence between the U.S. and Europe, and is the gap driven by a few states or is it broader?

## Why homicide?

Total police-recorded crime is not comparable across countries (offenses are defined, counted, and reported differently). Homicide is the least affected by those differences, and both data sources used here are based on death certificates.

## Data sources

| Data | Source | Details |
|------|--------|---------|
| Homicide rate by country | WHO Mortality Database, via Our World in Data | Annual homicides per 100,000 residents |
| Population, GDP per capita (PPP), Gini | World Bank (WDI) | `SP.POP.TOTL`, `NY.GDP.PCAP.PP.CD`, `SI.POV.GINI` |
| Homicide rate by U.S. state | CDC WONDER, Underlying Cause of Death (Single Race) | ICD-10 X85-Y09 and Y87.1; years 2018-2022 pooled; grouped by state; downloaded October 2026 |

**Scope:** 29 countries (the 27 EU members, the United Kingdom, and the United States), plus the 50 U.S. states and Washington, D.C.

## Method

- **Window:** 2018-2022 averages for all country and state comparisons. The window includes the COVID years (2020-2021).
- **Europe benchmark (bar chart, scatter plots, state comparison):** the population-weighted mean of the 28 European countries' 2018-2022 rates.
- **Europe benchmark (line chart):** total homicides divided by total population across reporting EU27 + UK countries, for each year from 2000 to 2020. The line stops at 2020 because after that WHO data is missing for large countries (e.g., Germany from 2021), which would change the country mix and distort the trend.
- **U.S. line:** the U.S. series is shown through 2022, the last year available.
- **State data:** CDC rates are pooled over five years to avoid suppression of small counts. No state was suppressed or flagged unreliable.
- **Scatter plots:** each country's 2018-2022 average homicide rate against its average GDP per capita (PPP) and its average Gini coefficient. The dashed trend lines are fitted to the 28 European countries only, so the U.S. does not influence them.

## Visualizations

| File | What it shows |
|------|---------------|
| `Results/chart1_bar.png` | Ranked homicide rates for the 29 countries, with the weighted Europe average |
| `Results/chart2_line.png` | U.S. vs. weighted Europe homicide rate over time |
| `Results/chart3_states.png` | Distribution of European countries vs. U.S. states and D.C. |
| `Results/chart4_scatter.png` | Homicide rate vs. GDP per capita and vs. Gini (two panels) |

## Key findings

- The U.S. rate is about 6.85 per 100,000, versus about 0.63 for Europe (population-weighted), roughly 11 times higher. Latvia is the highest European country at about 3.4.
- Europe's rate fell from about 1.45 (2000) to about 0.61 (2020). The U.S. stayed roughly between 5 and 7 and rose to almost 8 in 2021.
- All 51 U.S. jurisdictions are above the median European country (about 0.75), and 39 of 51 are above every European country. Rates range from about 1.7 (New Hampshire, Maine) to about 17.7 (Mississippi), with D.C. at about 25.6.
- Within Europe, the relationships between homicide and GDP (r about -0.3) and Gini (r about 0.3) are weak. The U.S. is far above the European trend in both, so neither wealth nor inequality alone explains the gap.

## Limitations

- **Descriptive only.** With 29 country-level observations, the analysis shows where and how large the gap is, not what causes it.
- **Leverage of the U.S. point.** The correlation with Gini across all 29 countries (about 0.5) is driven largely by the single U.S. observation. It falls to about 0.3 when only European countries are used.
- **Uneven data coverage.** Some countries have fewer than five years of homicide data in the window: Germany (2018-2020) and Portugal (3 years), and Belgium, Croatia, Romania, and the UK (4 years). Averages use the years available.
- **Hungary's Gini** has no observation in 2018-2022, so its most recent value (2017) is used. It is marked with a triangle in Figure 4.
- **Small countries** (e.g., Malta, Luxembourg, Cyprus) have volatile rates because of small counts.
- **Different sources.** Country data (WHO) and state data (CDC) are both death-certificate based but are not identical. At the national level they agree closely (6.85 vs. 6.9).
- **D.C.** is a city, not a state, and is a clear outlier. It is kept in the state comparison and labeled.
- **COVID years** are included in the window, which raises the U.S. average somewhat.

## Files

| File | Description |
|------|-------------|
| `Results/country_avg.csv` | One row per country, 2018-2022 averages (homicide rate, GDP per capita, Gini, population) |
| `Results/panel.csv` | Country-year data, 2000-2023 |
| `Results/europe_benchmark.csv` | Population-weighted Europe homicide rate by year, 2000-2020 |
| `Results/cdc_states.csv` | Homicide rate by state, 2018-2022 pooled |
| `Underlying_Cause_of_Death__2018-2024__Single_Race.tsv` | Raw CDC WONDER export |
| `[data preparation script].R` | Downloads and merges the WHO and World Bank data and creates the CSV files |
| `[charts script].R` | Builds and saves the four charts |

## Reproducing the analysis

1. Run the data preparation script. It pulls the WHO data from Our World in Data and the World Bank indicators through the `WDI` package, then writes `country_avg.csv`, `panel.csv`, and `europe_benchmark.csv`. These sources are updated over time, so results may differ slightly from those reported here (data accessed October 2026).
2. Load the CDC export (the raw `.tsv` is included), keep the first 51 data rows (the states), and save `cdc_states.csv`. CDC's official API only returns national totals, so state-level data must be exported from the CDC WONDER web interface using the settings listed under "Data sources."
3. Run the charts script to produce the four PNG files.

**R packages:** `dplyr`, `WDI`, `ggplot2`, `ggrepel`, `patchwork`, `scales`.
