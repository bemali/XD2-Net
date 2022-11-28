# XDD-Net: Explainable Dual Learning Deep (Neural) Network for Process Outcome Prediction

This project is a deep neural architecture designed for which uses two feature sets for learning (Dual Learning) and one feature set for explaining the model prediction.

## Project File Description
#### SQL scripts
The sql scripts to convert the three event logs into datasets that can be used as inputs for the model
#### Functions
Support functions for the main notebooks are written as packages in these files
* `Data_proc.py` : Data pre-processing functions
* `Inputs.py`: Generating input vectors with pre-processed dataset
#### Main notebooks
* `XD2_Net.ipynb`: Main note book in which outcome prediction and generation of explanations is done
* `XD2_Net_Explanation_Evaluation.ipynb`: Notebook for evaluating the model performance and model explanations
