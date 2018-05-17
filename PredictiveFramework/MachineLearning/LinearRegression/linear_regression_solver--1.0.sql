-- TODO: solver not complete, it does not work yet
-- Installation script for linear regression solver
delete from sl_solver where name = 'lr_solver';

WITH
-- Registers the solver
  solver AS   (INSERT INTO sl_solver(name, version, author_name, author_url, description)
                 values ('lr_solver', 1.0, 'Davide Frazzetto', 'http://vbn.aau.dk/en/persons/davide-frazzetto(448b0269-416f-4a18-80b8-ec6b6f0bdb71).html', 'solver for linear regression') 
              returning sid),     

--Registers the BASIC method. It has no parameters.
 method1 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'lr', 'linear regression solver', 'lr_solver', 'predictive problem', 'linear regression model' 
		  FROM solver RETURNING mid),

--Register the non-solver method associated to this solver (the method that peforms the the prediction)
pr_method AS (INSERT INTO sl_pr_method(name, version, funct_name, description, type)
		VALUES ('lr_method', '1.0', 'lr_predict','function that performs arima prediction','ml')
		returning mid),

sl_pr_sol_method AS (INSERT INTO sl_pr_solver_method(sid, mid)
		SELECT sid, mid from solver, pr_method
		returning sid),


--Register the parameters

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
                  RETURNING sid)   
   

--Perform the actual insert
SELECT count(*) FROM solver, method1, pr_method, sl_pr_sol_method, spar2, sspar2, spar3, sspar3, spar5, sspar5, spar7, sspar7, spar8, sspar8;

--Set the default method
UPDATE sl_solver s
SET default_method_id = mid
FROM sl_solver_method m
WHERE (s.sid = m.sid) AND (s.name = 'lr_solver') AND (m.name='lr');

--linear regression solver default method
drop function if exists lr_solver(arg sl_solver_arg);
CREATE OR replace function lr_solver(arg sl_solver_arg ) RETURNS SETOF record as $$

DECLARE
	method 			name := 'lr_predict'::name;
	target_column_name 	name := ((arg).problem).cols_unknown[1];
	attFeatures       	text := sl_param_get_as_text(arg, 'features');
	attStartTime       	text := sl_param_get_as_text(arg, 'start_time');
	attEndTime       	text := sl_param_get_as_text(arg, 'end_time');
	attFrequency       	text := sl_param_get_as_text(arg, 'frequency');
	par_val_pairs		text[][];
	i			int;
	query			sl_solve_query;

BEGIN

	raise notice 'lr solver';
	-- get arg information
	query := ((arg).problem, 'predictive_solver'::name, '');

	for i in 1..array_length((arg).params, 1) loop
		par_val_pairs := par_val_pairs || array[[((arg).params)[i].param::text, ((arg).params)[i].value_t::text]];
	end loop;
	par_val_pairs := par_val_pairs || array[['methods'::text, method::text]];

--CALL THE PREDICTIVE ADVISOR SOLVER WITH METHODS:= 'arima_predict'
RETURN QUERY EXECUTE sl_pr_generate_predictive_solve_query(query, par_val_pairs);
END;
$$ LANGUAGE plpgsql strict;


--Method for linear_regression_solver
DROP FUNCTION IF EXISTS lr_predict(text[], text, text, text, text, int);
CREATE OR REPLACE FUNCTION lr_predict(
features text[], time_feature text,
 target_column_name text, training_data text, test_data text, number_of_predictions int)
RETURNS NUMERIC[]
AS $$
	import numpy as np
	import math
	from sklearn import linear_model
	import dateutil.parser as parser
	train_x	= []
	train_y	= []
	test_x  = []
	rv = plpy.execute(training_data)

	for x in rv:
		f_list = []
		for feature in features:
			f_list.append(x[feature])
		# split time feature:
		curr_time = parser.parse(str(x[time_feature]))
		#year, month, day, hour, minute, second
		f_list.append(curr_time.year)
		f_list.append(curr_time.month)
		f_list.append(curr_time.day)
		f_list.append(curr_time.hour)
		f_list.append(curr_time.minute)
		f_list.append(curr_time.second)
		train_x.append(f_list)
		train_y.append(x[target_column_name])

	rv = plpy.execute(test_data)
	for x in rv:
		f_list = []
		for feature in features:
			f_list.append(x[feature])
		#year, month, day, hour, minute, second
		curr_time = parser.parse(str(x[time_feature]))
		f_list.append(curr_time.year)
		f_list.append(curr_time.month)
		f_list.append(curr_time.day)
		f_list.append(curr_time.hour)
		f_list.append(curr_time.minute)
		f_list.append(curr_time.second)
		test_x.append(f_list)       

	regr = linear_model.LinearRegression().fit(train_x, train_y)
	predictions = regr.predict(test_x)
	#if needed print information about the model to the client
	if GD["print_model_summary"]:
		plpy.notice("Coefficients: ", regr.coef_)
		plpy.notice("Score: ", regr.score(train_x, train_y))
	#except Exception as ex:
	#	#plpy.warning(format(ex))
	#	predictions = np.array(y_train[len(y_train) - number_of_predictions:len(y_train)])
	#except ValueError as err:
	#	#plpy.warning(format(err))
	#	predictions = np.array(y_train[len(y_train) - number_of_predictions:len(y_train)])
	#--check for predictions that are nan
	for pr in range(len(predictions)):
		if math.isnan(predictions[pr]):
			plpy.notice("linear regression prediction is Nan for n:", pr);
			predictions[pr] = np.mean(np.array(y_train[len(y_train) - number_of_predictions:len(y_train)]))

	return predictions.tolist();
$$ LANGUAGE plpythonu;