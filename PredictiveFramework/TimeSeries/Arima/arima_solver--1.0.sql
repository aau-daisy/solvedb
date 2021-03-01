-- cleaning tables for the new solver installation
truncate sl_pr_solver_method cascade;
truncate sl_pr_parameter cascade;
truncate sl_pr_method cascade;
delete from sl_solver where name = 'arima_solver';
-- Installation script for ARIMA solver
WITH
-- Registers the solver
  solver AS   (INSERT INTO sl_solver(name, version, author_name, author_url, description)
                 values ('arima_solver', 1.0, 'Davide Frazzetto', 'http://vbn.aau.dk/en/persons/davide-frazzetto(448b0269-416f-4a18-80b8-ec6b6f0bdb71).html', 'solver for ARIMA time series prediction') 
              returning sid),     

-- Registers the BASIC method. It has no parameters.
 method1 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'arima', 'default predictive solver', 'arima_solver', 'predictive problem', 'ARIMA predictive model' 
		  FROM solver RETURNING mid),

-- Register the non-solver method associated to this solver (the method that peforms the the prediction)
pr_method AS (INSERT INTO sl_pr_method(name, version, funct_name, description, type)
		VALUES ('arima_method', '1.0', 'arima_predict','function that performs arima prediction','ts')
		returning mid),

sl_pr_sol_method AS (INSERT INTO sl_pr_solver_method(sid, mid)
		SELECT sid, mid from solver, pr_method
		returning sid),


-- Register the parameters of the solver
     spar2 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('start_time' , 'text', 'starting_time', null, null, null) 
                  RETURNING pid),
     sspar2 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar2
                  RETURNING sid),
     spar3 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('end_time' , 'text', 'ending_time', null, null, null) 
                  RETURNING pid),
     sspar3 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar3
                  RETURNING sid),
     spar5 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('frequency' , 'text', 'prediction frequency', null, null, null) 
                  RETURNING pid),
     sspar5 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar5
                  RETURNING sid),
     spar7 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('features' , 'text', 'feature columns to use', null, null, null) 
                  RETURNING pid),
     sspar7 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar7
                  RETURNING sid), 
     spar8 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('predictions' , 'int', 'number of points to predict', null, null, null) 
                  RETURNING pid),
     sspar8 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar8
                  RETURNING sid),   
     spar9 AS   (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
			values ('time_window', 'int', 'percentage of data to use for prediction', null, 5, 100)
			returning pid),
     sspar9 AS (INSERT INTO sl_solver_param(sid, pid)
		SELECT sid, pid FROM solver, spar9
		returning sid),
     spar10 AS   (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
			values ('p', 'int', 'AR component', null, 0, 5)
			returning pid),
     sspar10 AS (INSERT INTO sl_solver_param(sid, pid)
		SELECT sid, pid FROM solver, spar10
		returning sid),
     spar11 AS   (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
			values ('d', 'int', 'I component', null, 0, 2)
			returning pid),
     sspar11 AS (INSERT INTO sl_solver_param(sid, pid)
		SELECT sid, pid FROM solver, spar11
		returning sid),
    spar12 AS   (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
			values ('q', 'int', 'MA component', null, 0, 5)
			returning pid),
     sspar12 AS (INSERT INTO sl_solver_param(sid, pid)
		SELECT sid, pid FROM solver, spar12
		returning sid),

                      

     -- Register the parameters that need to be fit by cross validation (including parameters already registered above)
     spar13 AS   (INSERT INTO sl_pr_parameter(name, type, description, value_default, value_min, value_max)
			values ('time_window', 'int', 'percentage of data to use for prediction', null, 5, 100)
			returning pid),
     sspar13 AS (INSERT INTO sl_pr_method_param(mid, pid)
		SELECT mid, pid FROM pr_method, spar13
		returning mid),
     spar14 AS   (INSERT INTO sl_pr_parameter(name, type, description, value_default, value_min, value_max)
			values ('p', 'int', 'AR component', null, 0, 5)
			returning pid),
     sspar14 AS (INSERT INTO sl_pr_method_param(mid, pid)
		SELECT mid, pid FROM pr_method, spar14
		returning mid),
     spar15 AS   (INSERT INTO sl_pr_parameter(name, type, description, value_default, value_min, value_max)
			values ('d', 'int', 'I component', null, 0, 2)
			returning pid),
     sspar15 AS (INSERT INTO sl_pr_method_param(mid, pid)
		SELECT mid, pid FROM pr_method, spar15
		returning mid),
    spar16 AS   (INSERT INTO sl_pr_parameter(name, type, description, value_default, value_min, value_max)
			values ('q', 'int', 'MA component', null, 0, 5)
			returning pid),
     sspar16 AS (INSERT INTO sl_pr_method_param(mid, pid)
		SELECT mid, pid FROM pr_method, spar16
		returning mid)

-- Perform the actual insert
SELECT count(*) FROM solver, method1, pr_method, sl_pr_sol_method, spar2, sspar2, 
spar3, sspar3, spar5, sspar5, spar7, sspar7, 
spar8, sspar8, spar9, sspar9, spar10, sspar10, spar11, sspar11, spar12, sspar12,
spar13, sspar13, spar14, sspar14, spar15, sspar15, spar16, sspar16;


-- Set the default method
UPDATE sl_solver s
SET default_method_id = mid
FROM sl_solver_method m
WHERE (s.sid = m.sid) AND (s.name = 'arima_solver') AND (m.name='arima');

---------------------------------------
-- arima solver default method
drop function if exists arima_solver(arg sl_solver_arg);
CREATE OR REPLACE FUNCTION arima_solver(arg sl_solver_arg) RETURNS SETOF record as $$

DECLARE
	-- todo make this dynamic, check solver id in arg?
	method 			name := 'arima_predict'::name;
	target_column_name 	name := ((arg).problem).cols_unknown[1];
	par_val_pairs		text[][];
	i			int;
	query			sl_solve_query;

BEGIN
	-- get arg information
	query := ((arg).problem, 'predictive_solver'::name, '');
	par_val_pairs := array_cat(par_val_pairs, array[['features', sl_param_get_as_text(arg, 'features')]]);
	par_val_pairs := array_cat(par_val_pairs, array[['start_time', sl_param_get_as_text(arg, 'start_time')]]);
	par_val_pairs := array_cat(par_val_pairs, array[['end_time', sl_param_get_as_text(arg, 'end_time')]]);
	par_val_pairs := array_cat(par_val_pairs, array[['frequency', sl_param_get_as_int(arg, 'frequency')::text]]);
	par_val_pairs := array_cat(par_val_pairs, array[['predictions', sl_param_get_as_int(arg, 'predictions')::text]]);

-- CALL THE PREDICTIVE ADVISOR SOLVER WITH METHODS:= 'arima_predict'
RETURN QUERY EXECUTE sl_pr_generate_predictive_solve_query(query, par_val_pairs);
END;
$$ LANGUAGE plpgsql strict;
------------------------------------------------------------------------------------------

-- METHOD USER BY THE arima_solver
-- training_data/test_data: 	sql views
-- returns an array with the predicted values
DROP FUNCTION IF EXISTS arima_predict(int,int, int,  int, text, text, text, int);
CREATE OR REPLACE FUNCTION arima_predict(time_window int, p int, d int, q int, time_column_name text,
 target_column_name text, training_data text, number_of_predictions int)
RETURNS NUMERIC[]
AS $$
	import pandas as pd
	import statsmodels.api as sm
	import numpy as np
	from datetime import datetime
	import sys
	from sklearn.metrics import mean_squared_error
	from math import sqrt
	import math
	from pandas import DataFrame
	import dateutil.parser as parser

	
	training_time	= []
	training_target	= []

	rv = plpy.execute(training_data)
	for x in rv:
		training_target.append(x[target_column_name])
		training_time.append(parser.parse(x[time_column_name]));

	
	x_train = np.array(training_time)
	y_train = np.array(training_target)

	series = pd.Series(y_train[int(len(y_train) - (len(y_train) / float(100) * time_window)):len(y_train)],
                            x_train[int(len(x_train) - (len(x_train) / float(100) * time_window)):len(x_train)])

                    
	try:
		arima_mod = sm.tsa.ARIMA(series.astype(float), order=(p,d,q))
		arima_res = arima_mod.fit()
		predictions = arima_res.forecast(number_of_predictions)[0]

		#if needed print information about the model to the client
		if GD["print_model_summary"]:
			plpy.notice(arima_res.summary())
			residuals = DataFrame(arima_res.resid)
			plpy.notice('-------ARIMA Residuals Description-------')
			plpy.notice(residuals.describe())
		
	except Exception as ex:
		plpy.notice('------ARIMA model cannot be fit with parameters')
		plpy.warning(format(ex))
		#predictions = np.array(y_train[len(y_train) - number_of_predictions:len(y_train)])
		predictions = np.zeros(number_of_predictions)
	except ValueError as err:
		plpy.notice('------ARIMA model cannot be fit with parameters')
		plpy.warning(format(err))
		#predictions = np.zeros(number_of_predictions)
		predictions = np.array(y_train[len(y_train) - number_of_predictions:len(y_train)])
	#--check for predictions that are nan
	for pr in range(len(predictions)):
		if math.isnan(predictions[pr]):
			plpy.warning('prediction is nan')
			predictions[pr] = np.mean(np.array(y_train[len(y_train) - number_of_predictions:len(y_train)]))
	
	return predictions.tolist();

$$ LANGUAGE plpythonu; 
---------------------------------
