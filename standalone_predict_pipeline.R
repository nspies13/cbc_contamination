#!/usr/bin/env Rscript
renv::restore()
suppressPackageStartupMessages({
  library(tidyverse)
  library(tidymodels)
})

#' Prediction pipeline: preprocess raw CBC data and generate predictions
#' using pre-trained models saved by standalone_train_pipeline.R.
#'
#' Usage: Rscript standalone_predict_pipeline.R raw_input.csv models_list.RDS
#'
#' raw_input.csv: long-form CBC data with columns
#'   PATIENT_ID, DRAWN_DT_TM, ASSAY, RESULT
#' model_rds:   path to RDS file created by training pipeline
#' output_dir/: directory where predictions will be written

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop(paste("Usage: Rscript standalone_predict_pipeline.R raw_input.csv models_list.RDS"), call. = FALSE)
}

input_path <- args[1]
model_path <- args[2]

# location of this script and helper scripts
cmd_args <- commandArgs(trailingOnly = FALSE)
script_path <- sub("^--file=", "", cmd_args[grep("^--file=", cmd_args)])
script_dir <- dirname(script_path)

# Step 1: preprocessing ----------------------------------------------------
message("Preprocessing CBC data...")
system2(
  "Rscript",
  c(
    file.path(script_dir, "scripts", "standalone_cbc_preprocessing.R"),
    input_path,
    paste0(script_dir, "/results/")
  )
)

preproc_out <- file.path(
  paste0(script_dir, "/results/"),
  "cbcs_with_deltas_filtered_ml_inputs.csv"
)
cbc_data <- read_csv(preproc_out, show_col_types = FALSE)

# Step 2: generate predictions --------------------------------------------
message("Generating predictions...")
system2(
  "Rscript",
  c(
    file.path(script_dir, "scripts", "standalone_make_predictions.R"),
    preproc_out,
    model_path,
    paste0(script_dir, "/results/")
  )
)
message("Predictions saved to output directory.")
