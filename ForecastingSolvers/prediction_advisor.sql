--//-----------------prediction solver advisor----------------//
--finds prediction/target features and select best features from table (feature selector function) (to be done)
--finds time range for prediction, create temporary table to fill (create_temporary_forecasting_table function)
--create views for training and test splitting (to be done)
--initialize parameters to test
--create model instance with specific parameters (arima solver, now text_extraction function) to be done
--compare model results, choose and save best model
--fill temporary table ((create_temporary_forecasting_table function)
--join with original table (join_prediction_and_original_table function)

drop fcuntion predict();
create or replace function predict()
returns void as
$$





$$