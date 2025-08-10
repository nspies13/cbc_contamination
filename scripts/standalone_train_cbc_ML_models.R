#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(tidyverse)
  library(tidymodels)
  library(bonsai)
})

#' Trains ML models using simulated CBC contamination
#'
#' Usage: Rscript scripts/standalone_train_cbc_ML_models.R input.csv /output_path
#'
#' The input file must be of the same shape as the output from standalone_simulate_cbc_contamination.R

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop(
    "Usage: Rscript scripts/standalone_train_cbc_ML_models.R input.csv /output_path",
    call. = FALSE
  )
}

input_path <- args[1]
output_path <- args[2]

input <- suppressMessages(read_csv(input_path)) |> mutate(target = factor(target, labels = c("Real", "Contaminated")))
cv <- vfold_cv(input, v = 5)

model <- boost_tree(trees = 1000, tree_depth = 10, learn_rate = 0.1, engine = "lightgbm") |> set_mode("classification")
base_rec <- recipe(input)

retrospective_recipe <-
  base_rec |>
    update_role(everything(), new_role = "metadata") %>%
    update_role_requirements("metadata", bake = F) %>%
    update_role(target, new_role = "outcome") %>%
    update_role(c("Hgb", "Plt", "WBC", "Hgb_delta_prior", "Plt_delta_prior", "WBC_delta_prior", "Hgb_delta_post", "Plt_delta_post", "WBC_delta_post"), new_role = "predictor") |>
    step_pca(all_predictors() & matches("delta"), num_comp = 2, keep_original_cols = T, options = list(center = T, scale. = T))

realtime_recipe <-
  base_rec |>
    update_role(everything(), new_role = "metadata") %>%
    update_role_requirements("metadata", bake = F) %>%
    update_role(target, new_role = "outcome") %>%
    update_role(c("Hgb", "Plt", "WBC", "Hgb_delta_prior", "Plt_delta_prior", "WBC_delta_prior",), new_role = "predictor") |>
    step_pca(all_predictors() & matches("delta"), num_comp = 2, keep_original_cols = T, options = list(center = T, scale. = T))

wf_retrospective <- workflow(retrospective_recipe, model)
wf_realtime <- workflow(realtime_recipe, model)

print("Evaluating models on cross-validation...")
wf_retro_resamples <- fit_resamples(wf_retrospective, resamples = cv, control = control_resamples(verbose = T))
wf_realtime_resamples <- fit_resamples(wf_realtime, resamples = cv, control = control_resamples(verbose = T))

print(paste0("Retrospective auROC in Cross-Validation:  " , wf_retro_resamples |> collect_metrics() |> reframe(metric = .metric, mean, std_err) |> pluck(2, 3) |> round(3)))
print(paste0("Real-time auROC in Cross-Validation:  " , wf_realtime_resamples |> collect_metrics() |> reframe(metric = .metric, mean, std_err) |> pluck(2, 3) |> round(3)))

print("Fitting Retrospective Model...")
wf_fit_retrospective <- wf_retrospective |> fit(input) |> bundle::bundle()

print("Fitting Real-Time Model...")
wf_fit_realtime <- wf_realtime |> fit(input) |> bundle::bundle()

model_list <- list(retro = wf_fit_retrospective, realtime = wf_fit_realtime)
write_rds(model_list, paste0(output_path, "cbc_fit_models_list.RDS"))
print(paste0( "Fit models saved to ", paste0(output_path, "cbc_fit_models_list.RDS")))

