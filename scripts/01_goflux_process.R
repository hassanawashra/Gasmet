# Process one Gasmet GT5000 export with goFlux.
# Follow the goFlux documentation before adapting chamber geometry or units:
# https://qepanna.quarto.pub/goflux/

library(readxl)

# EDIT THESE SETTINGS ---------------------------------------------------------
raw_file <- "data/raw_gasmet/RESULTS_3.txt"
auxiliary_file <- "data/auxiliary_measurements.xlsx"
output_file <- "results/goflux_fluxes.csv"
# -----------------------------------------------------------------------------

if (!requireNamespace("goFlux", quietly = TRUE)) {
  stop("Install goFlux following https://qepanna.quarto.pub/goflux/ before running this script.")
}

aux_data <- read_excel(auxiliary_file)

gasmet_data <- goFlux::import.GT5000(
  inputfile = raw_file,
  date.format = "ymd",
  timezone = "UTC",
  save = FALSE,
  keep_all = FALSE,
  prec = c(1.6, 23, 13, 2, 23, 33)
)

observation_windows <- goFlux::obs.win(
  inputfile = gasmet_data,
  auxfile = aux_data,
  gastype = "CO2dry_ppm",
  obs.length = 1000,
  shoulder = 160
)

# Select the actual chamber closure and valid observation window interactively.
# Save the returned object if you need to audit or repeat the selections.
selected_windows <- goFlux::click.peak2(
  ow.list = observation_windows,
  gastype = "CO2dry_ppm",
  sleep = 10,
  plot.lim = c(50, 1000),
  warn.length = 20,
  save.plots = "results/selected_windows",
  width = 14,
  height = 8,
  abline = TRUE,
  abline_corr = TRUE
)
selected_windows$UniqueID <- as.character(selected_windows$UniqueID)

estimate_flux <- function(gas_type) {
  flux_results <- goFlux::goFlux(
    dataframe = selected_windows,
    gastype = gas_type,
    H2O_col = "H2O_ppm",
    warn.length = 20,
    k.min = 0
  )

  best <- goFlux::best.flux(
    flux.result = flux_results,
    criteria = c("MAE", "RMSE", "AICc", "SE", "g.factor", "kappa",
      "MDF", "nb.obs", "intercept", "p-value"),
    g.limit = 2,
    p.val = 0.05,
    k.ratio = 1,
    warn.length = 60
  )

  data.frame(
    UniqueID = best$UniqueID,
    flux = best$best.flux,
    model = best$model,
    stringsAsFactors = FALSE
  )
}

n2o <- estimate_flux("N2Odry_ppb")
names(n2o)[2:3] <- c("N2O_flux_nmol_m2_s", "N2O_model")

co2 <- estimate_flux("CO2dry_ppm")
names(co2)[2:3] <- c("CO2_flux_umol_m2_s", "CO2_model")

flux_table <- merge(n2o, co2, by = "UniqueID", all = TRUE)
write.csv(flux_table, output_file, row.names = FALSE)

# Check the printed goFlux output and its units for your installed package
# version before merging this table into the field metadata workbook.
