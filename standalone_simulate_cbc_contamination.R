#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(tidyverse)
})

#' Simulates contamination in a filtered, wide-form, cbc data set
#'
#' Usage: Rscript standalone_simulate_cbc_contamination input.csv /output_path
#'
#' The input file must take the same shape as the output files from standalone_cbc_preprocessing.R

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript standalone_simulate_cbc_contamination input.csv /output_path", call. = FALSE)
}

input_path <- args[1]
output_path <- args[2]

makeSimulatedTrainingSets <- function(input, prevalence = 0.5, min_mixture = 0.15){
  
  negatives <- input
  
  n_positives_to_simulate <- round(nrow(negatives) * prevalence)
  rows_to_simulate <- sample(1:nrow(negatives), n_positives_to_simulate, replace = F)
  
  final_negatives <- negatives[-rows_to_simulate,] 
  positives_to_simulate <- negatives[rows_to_simulate,]
  
  mix_ratios <- rbeta(n_positives_to_simulate, 1.5, 7) + min_mixture
  mix_ratios[mix_ratios > 0.95] <- 0.95
  
  positives_to_simulate$mix_ratio <- mix_ratios
  
  simulated_positives <- 
    positives_to_simulate |> 
    mutate(
      across(c("Hgb", "WBC", "Plt"), ~ round(. * (1 - mix_ratio), 1)),
      Plt = round(Plt),
      across(c("Hgb", "WBC", "Plt"), ~ ifelse(. == 0, 0.1, .)),
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
  
  training_set <- 
    bind_rows(
      final_negatives |> mutate(target = 0, mix_ratio = 0),
      simulated_positives |> mutate(target = 1)
    ) |> 
    mutate(target = as.factor(target))
  
  training_set
  
}

# Read data and convert result values to numeric
input <- suppressMessages(read_csv(input_path, show_col_types = FALSE))

# Run simulation
train <- makeSimulatedTrainingSets(input)

# Write output
write_csv(train, paste0(output_path, "/training_set_cbcs_with_simulated_contamination.csv"))