# Run once per R session from the repository root.

required_packages <- c(
  "readxl", "dplyr", "ggplot2", "janitor", "lmerTest", "emmeans"
)

missing_packages <- required_packages[!vapply(required_packages, requireNamespace,
  logical(1), quietly = TRUE)]

if (length(missing_packages) > 0) {
  install.packages(missing_packages)
}

invisible(lapply(required_packages, library, character.only = TRUE))

if (!dir.exists("results")) dir.create("results", recursive = TRUE)
