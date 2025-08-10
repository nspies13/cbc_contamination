#!/usr/bin/env Rscript
renv::restore()
suppressPackageStartupMessages({
  library(tidyverse)
})

#' Full training pipeline: preprocess raw CBC data, simulate contamination,
#' and train models.
#'
#' Usage: Rscript standalone_train_pipeline.R raw_input.csv
#'
#' raw_input.csv: long-form CBC data with columns
#'   PATIENT_ID, DRAWN_DT_TM, ASSAY, RESULT
#' output_dir/   : directory for intermediate files and models

args <- commandArgs(trailingOnly = TRUE)
input_path <- args[1]

# location of this script and helper scripts
cmd_args <- commandArgs(trailingOnly = FALSE)
script_path <- sub("^--file=", "", cmd_args[grep("^--file=", cmd_args)])
script_dir <- dirname(script_path)
dir.create(paste0(script_dir, "/results/"), showWarnings = F)
dir.create(paste0(script_dir, "/models/"), showWarnings = F)

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

# Step 2: simulate contamination -------------------------------------------
message("Simulating contamination...")
system2(
  "Rscript",
  c(
    file.path(script_dir, "scripts", "standalone_simulate_cbc_contamination.R"),
    preproc_out,
    paste0(script_dir, "/results/")
  )
)

sim_out <- file.path(
  paste0(script_dir, "/results/"),
  "training_set_cbcs_with_simulated_contamination.csv"
)

# Step 3: train models ------------------------------------------------------
message("Training models...")
system2(
  "Rscript",
  c(
    file.path(script_dir, "scripts", "standalone_train_cbc_ML_models.R"),
    sim_out,
    paste0(script_dir, "/models/")
  )
)

message("Training pipeline complete. Models saved to output directory.")
