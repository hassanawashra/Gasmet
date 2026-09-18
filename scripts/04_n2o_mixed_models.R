# Repeated-measures N2O mixed models: seasonal treatment effects and soil moisture.

library(readxl)
library(dplyr)
library(janitor)
library(lmerTest)

# EDIT THESE SETTINGS ---------------------------------------------------------
metadata_file <- "data/field_flux_data.xlsx"
metadata_sheet <- "metadata"
# -----------------------------------------------------------------------------

metadata <- read_excel(metadata_file, sheet = metadata_sheet) |>
  clean_names() |>
  mutate(date = as.Date(date))

n2o_model_data <- metadata |>
  filter(tolower(n2o_qc) == "included", !is.na(n2o_flux_nmol_m2_s)) |>
  mutate(
    block = factor(block),
    plot_id = factor(plot_id),
    treatment = factor(treatment),
    event = factor(event, levels = unique(event[order(date)])),
    n2o_asinh = asinh(n2o_flux_nmol_m2_s)
  )

# Fixed effects: treatment, event, and whether treatment differences vary by
# event. Random intercepts account for the blocked design and repeated plots.
n2o_seasonal_model <- lmer(
  n2o_asinh ~ treatment * event + (1 | block) + (1 | plot_id),
  data = n2o_model_data,
  REML = TRUE
)

print(anova(n2o_seasonal_model, type = 3))
print(summary(n2o_seasonal_model))
print(isSingular(n2o_seasonal_model, tol = 1e-4))

plot_diagnostics <- function(model, name) {
  residuals <- resid(model)
  fitted_values <- fitted(model)
  png(file.path("results", paste0(name, "_diagnostics.png")),
    width = 1800, height = 900, res = 180)
  par(mfrow = c(1, 2))
  plot(fitted_values, residuals, xlab = "Fitted values", ylab = "Residuals",
    main = "Residuals vs fitted")
  abline(h = 0, lty = 2, col = "red")
  qqnorm(residuals, main = "Normal Q-Q plot")
  qqline(residuals, col = "red")
  par(mfrow = c(1, 1))
  dev.off()
}

plot_diagnostics(n2o_seasonal_model, "N2O_seasonal_model")

# Soil-moisture model: only dates/plots with measured soil moisture are used.
n2o_soil_data <- n2o_model_data |>
  filter(!is.na(soil_moisture)) |>
  mutate(soil_moisture_z = as.numeric(scale(soil_moisture)))

if (nrow(n2o_soil_data) > 0) {
  n2o_soil_base <- lmer(
    n2o_asinh ~ treatment + event + (1 | block) + (1 | plot_id),
    data = n2o_soil_data, REML = FALSE
  )
  n2o_soil_model <- lmer(
    n2o_asinh ~ treatment + event + soil_moisture_z + (1 | block) + (1 | plot_id),
    data = n2o_soil_data, REML = FALSE
  )

  print(anova(n2o_soil_base, n2o_soil_model))

  # Refit with REML for coefficient estimates and type-III tests.
  n2o_soil_model_reml <- update(n2o_soil_model, REML = TRUE)
  print(anova(n2o_soil_model_reml, type = 3))
  print(summary(n2o_soil_model_reml))
  print(isSingular(n2o_soil_model_reml, tol = 1e-4))
  plot_diagnostics(n2o_soil_model_reml, "N2O_soil_moisture_model")
}
