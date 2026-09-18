# Cumulative seasonal N2O-N exchange by trapezoidal integration.

library(readxl)
library(dplyr)
library(ggplot2)
library(janitor)
library(lmerTest)

# EDIT THESE SETTINGS ---------------------------------------------------------
metadata_file <- "data/field_flux_data.xlsx"
metadata_sheet <- "metadata"
# -----------------------------------------------------------------------------

treatment_colours <- c(
  "0 N" = "#4D4D4D", "Alzon Neo" = "#E69F00", "AN" = "#009E73",
  "CCm" = "#0072B2", "Cm" = "#0072B2", "Instinct" = "#CC79A7",
  "Limus" = "#56B4E9", "Urea" = "#D55E00"
)

metadata <- read_excel(metadata_file, sheet = metadata_sheet) |>
  clean_names() |>
  mutate(date = as.Date(date), n2o_qc = tolower(n2o_qc))

n2o_data <- metadata |>
  filter(n2o_qc == "included", !is.na(n2o_flux_nmol_m2_s)) |>
  transmute(
    date,
    plot_id = factor(plot_id),
    treatment = factor(treatment),
    block = factor(block),
    n2o_flux = n2o_flux_nmol_m2_s
  )

# Flux is nmol N2O m^-2 s^-1. The trapezoid area is first calculated as
# nmol N2O m^-2, then converted to mg N2O-N m^-2 using the mass of two N atoms.
cumulative_n2o <- n2o_data |>
  arrange(plot_id, date) |>
  group_by(plot_id, treatment, block) |>
  mutate(
    seconds_since_previous = as.numeric(date - lag(date)) * 86400,
    mean_interval_flux = (n2o_flux + lag(n2o_flux)) / 2,
    interval_nmol_m2 = coalesce(mean_interval_flux * seconds_since_previous, 0),
    cumulative_nmol_m2 = cumsum(interval_nmol_m2),
    cumulative_mg_n2o_n_m2 = cumulative_nmol_m2 * 28.0134 / 1e6
  ) |>
  ungroup()

cumulative_summary <- cumulative_n2o |>
  group_by(date, treatment) |>
  summarise(
    mean_cumulative_mg_n2o_n_m2 = mean(cumulative_mg_n2o_n_m2),
    se_cumulative_mg_n2o_n_m2 = sd(cumulative_mg_n2o_n_m2) / sqrt(n()),
    .groups = "drop"
  )

final_cumulative_n2o <- cumulative_n2o |>
  group_by(plot_id, treatment, block) |>
  slice_max(date, n = 1, with_ties = FALSE) |>
  ungroup()

final_cumulative_summary <- final_cumulative_n2o |>
  group_by(treatment) |>
  summarise(
    n = n(),
    mean_cumulative_mg_n2o_n_m2 = mean(cumulative_mg_n2o_n_m2),
    se_cumulative_mg_n2o_n_m2 = sd(cumulative_mg_n2o_n_m2) / sqrt(n()),
    .groups = "drop"
  )

cumulative_time_plot <- ggplot(cumulative_summary,
  aes(date, mean_cumulative_mg_n2o_n_m2, colour = treatment, group = treatment)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_errorbar(aes(ymin = mean_cumulative_mg_n2o_n_m2 - se_cumulative_mg_n2o_n_m2,
    ymax = mean_cumulative_mg_n2o_n_m2 + se_cumulative_mg_n2o_n_m2), width = 1.2) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.8) +
  scale_colour_manual(values = treatment_colours, drop = FALSE) +
  scale_x_date(date_labels = "%d %b", date_breaks = "1 week") +
  labs(title = "Cumulative N2O exchange over the season", x = "Sampling date",
    y = "Cumulative N2O-N (mg m^-2)", colour = "Treatment") +
  theme_classic(base_size = 12) +
  theme(legend.position = "bottom", legend.title = element_blank())

final_cumulative_plot <- ggplot(final_cumulative_summary,
  aes(treatment, mean_cumulative_mg_n2o_n_m2, fill = treatment)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_col(width = 0.65) +
  geom_errorbar(aes(ymin = mean_cumulative_mg_n2o_n_m2 - se_cumulative_mg_n2o_n_m2,
    ymax = mean_cumulative_mg_n2o_n_m2 + se_cumulative_mg_n2o_n_m2), width = 0.15) +
  geom_point(data = final_cumulative_n2o,
    aes(treatment, cumulative_mg_n2o_n_m2), inherit.aes = FALSE,
    position = position_jitter(width = 0, height = 0), size = 2.8,
    colour = "black", alpha = 0.65) +
  scale_fill_manual(values = treatment_colours, drop = FALSE) +
  labs(title = "Final cumulative N2O exchange by treatment", x = NULL,
    y = "Cumulative N2O-N (mg m^-2)") +
  theme_classic(base_size = 12) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1), legend.position = "none")

print(cumulative_time_plot)
print(final_cumulative_plot)

ggsave("results/Cumulative_N2O_over_season.png", cumulative_time_plot,
  width = 10, height = 6, dpi = 300)
ggsave("results/Final_cumulative_N2O_by_treatment.png", final_cumulative_plot,
  width = 9, height = 6, dpi = 300)
write.csv(cumulative_n2o, "results/Cumulative_N2O_by_plot_and_date.csv", row.names = FALSE)
write.csv(final_cumulative_n2o, "results/Final_cumulative_N2O_by_plot.csv", row.names = FALSE)
write.csv(final_cumulative_summary, "results/Final_cumulative_N2O_summary.csv", row.names = FALSE)

# One final cumulative value per plot: block remains a random effect.
cumulative_model <- lmer(
  cumulative_mg_n2o_n_m2 ~ treatment + (1 | block),
  data = final_cumulative_n2o,
  REML = TRUE
)

print(anova(cumulative_model, type = 3))
print(summary(cumulative_model))
print(isSingular(cumulative_model, tol = 1e-4))
