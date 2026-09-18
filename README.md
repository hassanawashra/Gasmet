# Gasmet static-chamber flux workflow

Reproducible R workflow for processing Gasmet GT5000 static-chamber measurements with [goFlux](https://qepanna.quarto.pub/goflux/) and analysing treatment effects in a blocked, repeated-measures field experiment.

The repository is designed for gas-flux datasets with measurements repeated on fixed plots across sampling dates. It includes scripts for:

- importing Gasmet GT5000 data and calculating chamber fluxes with goFlux;
- plotting individual sampling dates;
- plotting seasonal N2O fluxes with rainfall;
- fitting a mixed model for seasonal N2O fluxes;
- testing the soil-moisture association; and
- calculating cumulative seasonal N2O-N exchange.

## Before you start

1. Install R (version 4.1 or later recommended) and RStudio.
2. Download or install goFlux following its official documentation: <https://qepanna.quarto.pub/goflux/>.
3. Clone or download this repository.
4. Put input files in the `data/` folder.
5. Run `scripts/00_setup.R` once, then run the remaining scripts in numerical order as needed.

The scripts use relative file paths. Open the R project (or set the working directory to the repository root) before running them.

## Data structure

### goFlux auxiliary file

The goFlux processing script uses an auxiliary Excel file with these fields:

| Column | Meaning | Example |
| --- | --- | --- |
| `UniqueID` | Unique chamber measurement identifier | `101` |
| `start.time` | Measurement start time, stored as an Excel date-time | `2026-02-25 10:34:00` |
| `Area` | Chamber soil area (use the unit required by goFlux) | `491` |
| `Vtot` | Chamber total volume (use the unit required by goFlux) | `12.83` |
| `Tcham` | Chamber air temperature | `18.7` |
| `Pcham` | Chamber pressure | `1016` |

The supplied example auxiliary file contains real measurements and is deliberately **not** included here. Create your own for your data.

### Master metadata workbook

The field-level scripts expect an Excel sheet called `metadata` with the following columns. Column names are converted to lower case by `janitor::clean_names()`.

| Excel header | Description |
| --- | --- |
| `Date` | Sampling date |
| `Event` | Ordered sampling event, e.g. `Baseline` or `4 days after 1st fertiliser application` |
| `Block` | Field block or replicate |
| `Plot_ID` | Permanent plot identifier |
| `Treatment` | Fertiliser treatment |
| `N2O_flux_nmol_m2_s` | N2O flux in nmol m^-2 s^-1 |
| `N2O_model` | goFlux selected model, e.g. `LM` or `HM` |
| `CO2_flux_umol_m2_s` | CO2 flux in umol m^-2 s^-1 |
| `CO2_model` | goFlux selected model |
| `N2O_QC` | `Included` or an explicit reason for exclusion |
| `CO2_QC` | `Included` or an explicit reason for exclusion |
| `soil_moisture` | Plot-level soil moisture; leave missing where not measured |

Store rainfall in a separate `rainfall` sheet with `Date` and `rainfall_mm` columns.

## Workflow and key decisions

1. **Select the observation window in goFlux.** Use the actual chamber-closure period identified with the Ops-window/clicking workflow. Do not assume that the notebook start time is the same as the first valid chamber data point.
2. **Use goFlux flux units.** The workflow reports CO2 in umol m^-2 s^-1 and N2O (and other trace gases) in nmol m^-2 s^-1. Keep the unit in every table and axis title.
3. **Quality-control transparently.** Record a reason for every exclusion in the QC column. Do not iteratively delete observations to obtain a chosen R-squared value.
4. **Keep repeated plots in the model.** The seasonal model includes a random intercept for `Plot_ID`; `Block` is also a random intercept. This accounts for repeated measurements and the blocked field design.
5. **Use an asinh transformation for N2O when diagnostics require it.** `asinh()` accommodates negative, zero, and positive fluxes. Report model results as applying to transformed N2O flux, while graphs can remain on the original flux scale.
6. **Integrate cumulative flux by plot.** The cumulative script uses trapezoidal integration between sampling dates and expresses totals as mg N2O-N m^-2.

## Running the scripts

| Script | Purpose |
| --- | --- |
| `00_setup.R` | Loads required packages and creates `results/`. |
| `01_goflux_process.R` | Imports one GT5000 result file, selects windows, estimates N2O and CO2 fluxes, and saves a flux table. |
| `02_individual_date_plot.R` | Creates one treatment plot and one-way ANOVA summary for a selected sampling-date sheet. |
| `03_seasonal_n2o_rainfall.R` | Plots treatment mean N2O flux through time with rainfall on a secondary axis. |
| `04_n2o_mixed_models.R` | Fits the seasonal repeated-measures N2O mixed model and the soil-moisture model. |
| `05_cumulative_n2o.R` | Calculates, plots, and tests final cumulative N2O-N exchange. |

Each script has a small `EDIT THESE SETTINGS` section near the top. Replace only those paths, sheet names, and labels for a new dataset.

## Interpretation notes

- A significant `Treatment:Event` interaction means treatment differences vary by sampling event. Interpret treatment contrasts within events rather than quoting only a season-wide treatment effect.
- Rainfall is shown as environmental context, not as a causal statistical test in the seasonal figure.
- The soil-moisture model is fitted only to dates with soil-moisture measurements. It therefore answers whether plot-level soil moisture explains additional variation **within that subset**, after treatment and event.
- Cumulative N2O is an integrated estimate between the first and last sampling dates. It does not capture unmeasured peaks between visits.

## Citation

If you use goFlux, cite the package and follow the citation guidance provided by the goFlux project. Cite this repository using its GitHub release DOI if you create one through Zenodo.

## Licence and data sharing

No licence has been selected yet. Choose an institutional-approved open-source licence (for example, MIT or GPL-3.0) before making the repository public. Confirm separately that field data, treatment names, and instrument files may be released.
