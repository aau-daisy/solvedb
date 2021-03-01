
-- This function selects the most relevant features for prediction from the dataset, that account to [80%] of the importance (Default percentage)
-- It also removes irrelevant features
-- For time series forecasting: if a time_column is not given, select a random time column (TODO: update this function to analyse the dataset for the best time column)
CREATE OR REPLACE FUNCTION f_selector(arg sl_solver_arg, target_column_name name, source text) returns void AS $$
DECLARE

END;

$$ LANGUAGE plpgsql volatile strict;
