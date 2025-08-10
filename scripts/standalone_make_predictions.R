#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(tidyverse)
  library(tidymodels)
  library(bonsai)
})

#' Makes predictions from pre-trained models
#'
#' Usage: Rscript scripts/standalone_make_predictions.R input.csv models.RDS /output_path
#'
#' The input file must be of the same shape as the output from standalone_cbc_preprocessing.R, while the models should be in list form. 

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop(
    "Usage: Rscript scripts/standalone_make_predictions.R input.csv models.RDS /output_path",
    call. = FALSE
  )
}

input_path <- args[1]
models_path <- args[2]
output_path <- args[3]

input <- suppressMessages(read_csv(input_path))
models <- readRDS(models_path) |> map(bundle::unbundle)

input$.pred_contaminated_retrospective <- predict(models$retro, input, type = "prob") |> pluck(2)
input$.pred_contaminated_realtime <- predict(models$realtime, input, type = "prob") |> pluck(2)

write_csv(input, paste0(output_path, "/cbcs_with_contamination_predictions.csv"))
print(paste0("CBCs with predictions saved to ", paste0(output_path, "cbcs_with_contamination_predictions.csv")))

