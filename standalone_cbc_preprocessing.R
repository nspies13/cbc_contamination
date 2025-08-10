#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(tidyverse)
})

#' Preprocess a long-form CBC CSV file.
#'
#' Usage: Rscript preprocess_long_form_cbc.R input.csv output_folder/
#'
#' The input file must contain columns:
#'   PATIENT_ID - Patient identifier
#'   DRAWN_DT_TM - Specimen collection time
#'   ASSAY - Must contain "Hgb", "Plt", and "WBC"
#'   RESULT - Result value
#'
#' The script removes '<' and '>' from RESULT, filters to Hgb, Plt, and WBC,
#' pivots to wide format, and adds prior/post values for each patient. Prior and
#' post values outside of a 48 hour window are set to NA. The resulting data is
#' written to the specified output file in CSV format.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript standalone_cbc_preprocessing.R input.csv output_folder/", call. = FALSE)
}

input_path <- args[1]
output_path <- args[2]

# Read data and convert result values to numeric
data_long <- suppressMessages(read_csv(input_path, show_col_types = FALSE)) |> 
  mutate(
    RESULT = as.numeric(str_replace_all(RESULT, "<|>", "")),
    DRAWN_DT_TM = as_datetime(DRAWN_DT_TM)
  ) |> 
  filter(ASSAY %in% c("Hgb", "Plt", "WBC"))

# Pivot to wide format
cbc_wide <-   
  data_long |> 
  arrange(DRAWN_DT_TM) |> 
  pivot_wider(id_cols = c("PATIENT_ID", "DRAWN_DT_TM"), names_from = "ASSAY", values_from = "RESULT", 
              values_fn = last,
              values_fill = NA) |> 
  distinct()

# Add prior and post values
cbc_pre_post <-
  cbc_wide |>
    group_by(PATIENT_ID) |>
    arrange(DRAWN_DT_TM) |>
    mutate(
      hours_since_prior = as.numeric(
        DRAWN_DT_TM - lag(DRAWN_DT_TM),
        units = "hours"
      ),
      hours_to_post = as.numeric(
        lead(DRAWN_DT_TM) - DRAWN_DT_TM,
        units = "hours"
      ),
      across(c("Hgb", "WBC", "Plt"), ~ lag(.), .names = "{.col}_prior"),
      across(c("Hgb", "WBC", "Plt"), ~ lead(.), .names = "{.col}_post")
    ) |>
    ungroup()

# Add deltas 
cbc_with_deltas <- 
  cbc_pre_post |> 
    mutate(
      across(c("Hgb", "WBC", "Plt"), ~ . - get(paste0(cur_column(), "_prior")), .names = "{.col}_delta_prior"),
      across(ends_with("delta_prior"), ~ . / hours_since_prior, .names = "{.col}_per_hour"),
      across(c("Hgb", "WBC", "Plt"), ~ get(paste0(cur_column(), "_delta_prior")) / get(paste0(cur_column(), "_prior")) , .names = "{.col}_delta_prop_prior"),
      across(ends_with("delta_prop_prior"), ~ . / hours_since_prior, .names = "{.col}_per_hour"),
      across(c("Hgb", "WBC", "Plt"), ~ get(paste0(cur_column(), "_post")) - ., .names = "{.col}_delta_post"),
      across(ends_with("delta_post"), ~ . / hours_to_post, .names = "{.col}_per_hour"),
      across(c("Hgb", "WBC", "Plt"), ~ get(paste0(cur_column(), "_delta_post")) / ., .names = "{.col}_delta_prop_post"),
      across(ends_with("delta_prop_post"), ~ . / hours_to_post, .names = "{.col}_per_hour"), 
      across(c("Hgb", "WBC", "Plt"), ~ abs(get(paste0(cur_column(), "_delta_prior"))) + abs(get(paste0(cur_column(), "_delta_post"))), .names = "{.col}_distance"),
      across(c("Hgb", "WBC", "Plt"), ~ abs(get(paste0(cur_column(), "_prior")) - get(paste0(cur_column(), "_post"))), .names = "{.col}_change")
    )

# Mask any value outside 48h, drop rows with missing data
cbc_filtered <- 
  cbc_with_deltas |> 
    filter(hours_since_prior <= 48 & hours_to_post <= 48) |> 
    drop_na(c("Hgb", "WBC", "Plt", 
              "Hgb_prior", "WBC_prior", "Plt_prior", 
              "Hgb_post", "WBC_post", "Plt_post"))

# Write output
write_csv(cbc_with_deltas, paste0(output_path, "cbcs_with_deltas_all.csv"))
write_csv(cbc_filtered, paste0(output_path, "cbcs_with_deltas_filtered_ml_inputs.csv"))
print(paste0( "Preprocessed CBCs saved to  ", paste0(output_path, "cbcs_with_deltas_all.csv")))
print(paste0( "Preprocessed CBCs filtered to match ML inputs saved to  ", paste0(output_path, "cbcs_with_deltas_filtered_ml_inputs.csv")))
