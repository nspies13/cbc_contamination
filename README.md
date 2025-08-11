# Stand-alone CBC Contamination Scripts
Input data must be long-form CBC results with four columns: ***PATIENT_ID, DRAWN_DT_TM, ASSAY, RESULT***. An example can be found in *data/sample_cbc_input.csv*.  

Run the model training script using: 
```
Rscript standalone_train_pipeline.R <path_to_input_cbc_training_data>
```
This will populate a set of outputs into the `results/` folder, including a wide-form version of the inputs with their priors and posts, and a training dataset with simulated contamination. 

Run the inference script using: 
```
Rscript standalone_make_predictions.R <path_to_input_cbc_test_data> models/cbc_fit_models_list.RDS
```

