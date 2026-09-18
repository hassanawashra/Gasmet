# One sampling-date treatment plot and one-way ANOVA.

library(readxl)
library(dplyr)
library(ggplot2)

# EDIT THESE SETTINGS ---------------------------------------------------------
metadata_file <- "data/field_flux_data.xlsx"
sheet_name <- "12-05"
gas_column <- "N2O flux"
y_axis_label <- "N2O flux (nmol m^-2 s^-1)"
plot_title <- "N2O fluxes, 12 May"
output_prefix <- "N2O_12_May"
# -----------------------------------------------------------------------------

data <- read_excel(metadata_file, sheet = sheet_name)

if (!all(c("trt", gas_column) %in% names(data))) {
  stop("The selected sheet must contain columns named 'trt' and the requested gas column.")
}

plot_data <- data |>
  transmute(treatment = .data$trt, flux = .data[[gas_column]]) |>
  filter(!is.na(treatment), !is.na(flux))

summary_data <- plot_data |>
  group_by(treatment) |>
  summarise(
    n = n(),
    mean_flux = mean(flux),
    se_flux = sd(flux) / sqrt(n),
    .groups = "drop"
  )

one_way_model <- aov(flux ~ treatment, data = plot_data)
anova_p <- anova(one_way_model)[["Pr(>F)"]][1]

flux_plot <- ggplot(summary_data, aes(x = treatment, y = mean_flux)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_col(fill = "#73A9D8", width = 0.55) +
  geom_errorbar(aes(ymin = mean_flux - se_flux, ymax = mean_flux + se_flux),
    width = 0.12) +
  geom_point(data = plot_data, aes(x = treatment, y = flux),
    inherit.aes = FALSE, position = position_jitter(width = 0, height = 0),
    size = 2.8, colour = "black", alpha = 0.55) +
  labs(
    title = plot_title,
    subtitle = paste("One-way ANOVA: p =", format.pval(anova_p, digits = 3)),
    x = NULL, y = y_axis_label
  ) +
  theme_classic(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

print(anova(one_way_model))
print(flux_plot)

ggsave(file.path("results", paste0(output_prefix, "_plot.png")),
  flux_plot, width = 8, height = 6, dpi = 300)
write.csv(summary_data, file.path("results", paste0(output_prefix, "_summary.csv")),
  row.names = FALSE)

# Individual-date ANOVAs are descriptive follow-up analyses. Use the seasonal
# mixed model for the primary repeated-measures treatment inference.
