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
-- function managed by "predictive_solver_advisor" that 
--handles the execution of time series predictive models
--returns the names of the tables where the results have been written
drop function if exists sl_time_series_models_handler(sl_solver_arg, 
		 name,  text,
		 text,  text,  text,  text, 
		 name,  text,  text[]);
CREATE OR replace function sl_time_series_models_handler(arg sl_solver_arg, 
		target_column_name name, target_column_type text,
		time_feature text, 
		 results_table text, ts_methods_to_test text[])
RETURNS text AS $$

DECLARE

	tmp_string_array 	text[] := '{}';
	
	
	ts_training_sets	text[] := '{}'; 
	ts_test_sets		text[] := '{}'; 
	tmp_string		text;
	tmp_name		name;
	tmp_integer		integer;
	method_parameters	sl_method_parameter_type[] := '{}';
	tmp_numeric_array	numeric[] := '{}';
	tmp_record		record;
	tmp_numeric		numeric;
	i			int;
	training_test		text;
	predictions		numeric[];

BEGIN

---check time arguments (if time columns are present in the table)
	if time_feature is null THEN
		RAISE EXCEPTION 'No time columns present in the given Table. 
					Impossible to process time series.';
	END IF;	

-- Create 70%-30% (default value) split for each of the test/training set that need to be evaluated
	for i in 1.. array_length(ts_training_tables, 1) LOOP
		execute 'SELECT COUNT(*) FROM ' || ts_training_tables[i] into tmp_integer;
		tmp_string  := sl_get_unique_tblname() || '_pr_ts_training';
		EXECUTE format('CREATE TEMP TABLE %s AS SELECT %s,%s FROM %s LIMIT %s',
			tmp_string,
			time_feature,
			target_column_name,
			ts_training_tables[i],
			((tmp_integer::numeric/100.0) * 70.0)::int);
		ts_training_sets := ts_training_sets || tmp_string;
		tmp_string  := sl_get_unique_tblname() || '_pr_ts_test';
		EXECUTE format('CREATE TEMP TABLE %s AS SELECT %s,%s FROM %s OFFSET %s',
			tmp_string,
			time_feature,
			target_column_name,
			ts_training_tables[i],
			((tmp_integer::numeric/100.0) * 70.0)::int);
		ts_test_sets := ts_test_sets || tmp_string;
	END LOOP;

	for tmp_integer in 1..array_length(ts_training_sets, 1) LOOP
		-- create test values
		tmp_string := 'SELECT * FROM ' || ts_test_sets[tmp_integer];
		tmp_numeric_array := sl_extract_column_to_array(tmp_string, target_column_name);


		for i in 1..array_length(ts_methods_to_test,1) LOOP
			--raise notice 'Training: %', ts_methods_to_test[i];
			-- get user defined parameter to test
			for tmp_record in execute format('select a.name::text, type, value_default, value_min, value_max
						from sl_pr_parameter as a
						inner join
						sl_pr_method_param as b
						on a.pid = b.pid
						where b.mid in 
						(
						select mid
						from sl_pr_method
						where funct_name = %L)',
				ts_methods_to_test[i])
			LOOP
				method_parameters := method_parameters || (tmp_record.name, tmp_record.type, tmp_record.value_default,
										tmp_record.value_min, tmp_record.value_max)::sl_method_parameter_type;
			END LOOP;

--FIT method as SOLVESELECT rewriting into optimization problem using solversw)
-- tmp_string contains the pairs param:=value of the trained model, to be formatted
			tmp_string := sl_convert_ts_fit_to_solveselect(time_feature, target_column_name, 
							ts_training_sets[tmp_integer], tmp_numeric_array,
							ts_methods_to_test[i], method_parameters);


			-- format the param:= value pairs
			tmp_string_array := string_to_array(tmp_string, ',');
 			tmp_string := format('%s',
				(SELECT string_agg(format('%s := %s',
					(method_parameters[j]).name,
					tmp_string_array[j]), ',')
				FROM generate_subscripts(method_parameters, 1) AS j));

			-- run again to get the RMSE of the trained model
			EXECUTE format('SELECT %s(%s, time_column_name:=%L, target_column_name:=%L, training_data:=%L, 
								number_of_predictions:=%s)',
			ts_methods_to_test[i],
			tmp_string, 
			time_feature,
			target_column_name,
			('select * from ' || ts_training_sets[tmp_integer]),
			array_length(tmp_numeric_array,1)) into predictions;
			tmp_numeric := sl_evaluation_rmse(tmp_numeric_array, predictions);
			
			
			EXECUTE format('INSERT INTO %s(method, parameters, result) VALUES (%L, %L, %s)',
			results_table,
			ts_methods_to_test[i],
			tmp_string,
			tmp_numeric);	
		END LOOP;
	END LOOP;

	-- return the tables where the results of the models have been written
	return format('{"training" : "%s", "test" : "%s"}',
		ts_training_tables[1], ts_target_tables[1]);
END;
$$ language plpgsql; 

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
                  RETURNING sid)    


--Perform the actual insert
SELECT count(*) FROM solver, method1, pr_method, sl_pr_sol_method, spar2, sspar2, spar3, sspar3, spar5, sspar5, spar7, sspar7;

--Set the default method
UPDATE sl_solver s
SET default_method_id = mid
FROM sl_solver_method m
WHERE (s.sid = m.sid) AND (s.name = 'lr_solver') AND (m.name='lr');


--arima solver default method
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


