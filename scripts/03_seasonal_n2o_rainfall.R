# Seasonal treatment mean N2O flux with daily rainfall context.

library(readxl)
library(dplyr)
library(ggplot2)
library(janitor)

# EDIT THESE SETTINGS ---------------------------------------------------------
metadata_file <- "data/field_flux_data.xlsx"
metadata_sheet <- "metadata"
rainfall_sheet <- "rainfall"
output_file <- "results/N2O_seasonal_flux_with_rainfall.png"
# -----------------------------------------------------------------------------

treatment_colours <- c(
  "0 N" = "#4D4D4D", "Alzon Neo" = "#E69F00", "AN" = "#009E73",
  "CCm" = "#0072B2", "Cm" = "#0072B2", "Instinct" = "#CC79A7",
  "Limus" = "#56B4E9", "Urea" = "#D55E00"
)

metadata <- read_excel(metadata_file, sheet = metadata_sheet) |>
  clean_names() |>
  mutate(date = as.Date(date))

rainfall <- read_excel(metadata_file, sheet = rainfall_sheet) |>
  clean_names() |>
  transmute(date = as.Date(date), rainfall_mm = as.numeric(rainfall_mm)) |>
  filter(!is.na(date), !is.na(rainfall_mm), rainfall_mm >= 0)

n2o_data <- metadata |>
  filter(tolower(n2o_qc) == "included", !is.na(n2o_flux_nmol_m2_s)) |>
  mutate(treatment = factor(treatment))

n2o_summary <- n2o_data |>
  group_by(date, treatment) |>
  summarise(
    mean_flux = mean(n2o_flux_nmol_m2_s),
    se_flux = sd(n2o_flux_nmol_m2_s) / sqrt(n()),
    .groups = "drop"
  )

# Scale rainfall only for display. The secondary axis converts the plotted bar
# height back to millimetres. This does not put rainfall in N2O units.
flux_range <- range(c(
  n2o_summary$mean_flux - n2o_summary$se_flux,
  n2o_summary$mean_flux + n2o_summary$se_flux, 0
), na.rm = TRUE)
rain_scale <- max(abs(flux_range)) * 0.35 / max(rainfall$rainfall_mm)

if (!is.finite(rain_scale) || rain_scale <= 0) {
  stop("Rainfall must include at least one positive value.")
}

n2o_time_plot <- ggplot() +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_col(data = rainfall, aes(x = date, y = rainfall_mm * rain_scale),
    inherit.aes = FALSE, fill = "#9ECAE1", width = 0.8, alpha = 0.7) +
  geom_errorbar(data = n2o_summary,
    aes(x = date, ymin = mean_flux - se_flux, ymax = mean_flux + se_flux,
      colour = treatment), width = 1.1) +
  geom_line(data = n2o_summary,
    aes(x = date, y = mean_flux, colour = treatment, group = treatment),
    linewidth = 1) +
  geom_point(data = n2o_summary,
    aes(x = date, y = mean_flux, colour = treatment), size = 2.8) +
  scale_colour_manual(values = treatment_colours, drop = FALSE) +
  scale_x_date(date_labels = "%d %b", date_breaks = "1 week") +
  scale_y_continuous(
    name = "N2O flux (nmol m^-2 s^-1)",
    sec.axis = sec_axis(~ . / rain_scale, name = "Rainfall (mm)")
  ) +
  labs(title = "N2O flux over time", x = "Sampling date", colour = "Treatment") +
  theme_classic(base_size = 12) +
  theme(legend.position = "bottom", legend.title = element_blank())

print(n2o_time_plot)
ggsave(output_file, n2o_time_plot, width = 10, height = 6, dpi = 300)
write.csv(n2o_summary, "results/N2O_seasonal_treatment_summary.csv", row.names = FALSE)
