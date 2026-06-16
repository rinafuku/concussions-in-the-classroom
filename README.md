# HCAMP Concussion Study — Replication Code

This repository contains the Stata code for a study examining the association between concussions and academic and behavioral outcomes among Hawaii high school student-athletes.

**Data sources:** Hawaii Concussion Awareness Management Program (HCAMP) linked to Hawaii Department of Education P-20 administrative records (demographics, GPA, attendance, disciplinary offenses).

---

## Repository structure

```
code/
  data_cleaning.do    — cleans and merges raw HCAMP and P-20 files; outputs regdata_new.dta
  data_analysis.do    — runs all regressions, summary statistics, and figures
```

Output folders (`tables/`, `figures/`) are not tracked in this repository.

---

## Data

The raw data files are not included in this repository. Access to the HCAMP and Hawaii DOE P-20 data requires approval from the relevant data custodians.

Expected raw data files (place in `Data/raw_data/`):
- `DXP1027_HCAMP_Table0-Matched Participant Data_2010-2024.csv`
- `DXP1027_HCAMP_Table1-Demographics.xlsx`
- `DXP1027_HCAMP_Table2-Academics.xlsx`
- `DXP1027_HCAMP_Table2a-Academics (English Courses).xlsx`
- `DXP1027_HCAMP_Table2b-Academics (Math Courses).xlsx`
- `DXP1027_HCAMP_Table2c-Academics (Science Courses).xlsx`
- `DXP1027_HCAMP_Table3-Behavioral.xlsx`

---

## Setup

1. Open `code/data_cleaning.do` and `code/data_analysis.do` and update the `cd` path at the top of each file to your local HCAMP project root folder.

2. Create the output directories if they do not exist:
   ```
   tables/
   figures/
   ```

3. Run the scripts in order:
   ```
   do code/data_cleaning.do
   do code/data_analysis.do
   ```

---

## Requirements

- **Stata** (version 16 or later recommended)
- The following user-written packages (install via `ssc install`):
  - `reghdfe` — high-dimensional fixed effects regression
  - `csdid` — Callaway & Sant'Anna (2021) difference-in-differences
  - `estout` — regression table export (`esttab`, `eststo`, `estadd`, `estpost`)

---

## Analysis overview

`data_cleaning.do` produces a student × school-year panel (`regdata_new.dta`) with:
- **Outcomes:** annual GPA, subject-specific GPAs (math, English, science), AP courseload, behavioral offenses, days absent
- **Exposure:** school-year concussion count, lagged one year (`sy_conc_lag`)
- **Treatment variables:** first concussion school year (`g`), first 2+ concussion school year (`g2`), ever-treated indicators
- **Controls:** demographics, sports participation, special education status, learning disabilities, birth year

`data_analysis.do` produces:
- Summary statistics tables
- Callaway & Sant'Anna (2021) event-study estimates (1+ and 2+ concussions)
- Individual fixed effects OLS estimates
- Heterogeneity analysis (interaction models by gender, economic disadvantage, ELL status, SPED status, ADHD, autism, dyslexia)
- Figures (cumulative concussion distribution, pre-treatment GPA histograms, GPA trajectories by grade)
