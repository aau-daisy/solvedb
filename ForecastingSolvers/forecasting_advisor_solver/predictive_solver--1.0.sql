-- complain if script is sourced in psql, rather than via CREATE EXTENSION
--\echo Use "CREATE EXTENSION predictive_solver" to load this file. \quit

-- Registers the solver and 1 method.
delete from sl_solver where name = 'predictive_solver';

WITH
-- Registers the solver
  solver AS   (INSERT INTO sl_solver(name, version, author_name, author_url, description)
                 values ('predictive_solver', 1.0, 'Davide Frazzetto', 'http://vbn.aau.dk/en/persons/davide-frazzetto(448b0269-416f-4a18-80b8-ec6b6f0bdb71).html', 'Main Predictive solver advisor') 
              returning sid),     

-- Registers the BASIC method. It has no parameters.
 method1 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'advisor', 'default predictive solver', 'predictive_solver_advisor', 'predictive problem', 'Manages the generic prediction tasks' 
		  FROM solver RETURNING mid),

-- Register the parameters

     spar1 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('start_time' , 'text', 'starting_time', null, null, null) 
                  RETURNING pid),
     sspar1 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar1
                  RETURNING sid),
     spar2 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('end_time' , 'text', 'ending_time', null, null, null) 
                  RETURNING pid),
     sspar2 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar2
                  RETURNING sid),
     spar3 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('features' , 'text', 'feature columns to use', null, null, null) 
                  RETURNING pid),
     sspar3 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar3
                  RETURNING sid),     
     spar4 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('methods' , 'text', 'prediction methods to test', null, null, null) 
                  RETURNING pid),
     sspar4 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar4
                  RETURNING sid),  
     spar5 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('predictions' , 'int', 'number of predictios to make', null, null, null) 
                  RETURNING pid),
     sspar5 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar5
                  RETURNING sid)  

-- Perform the actual insertion of the solver, method, and parameters.
SELECT count(*) FROM solver, method1, spar1, sspar1, spar2, sspar2 spar3, sspar3, spar4, sspar4, spar5, sspar5;

-- Set the default method
UPDATE sl_solver s
SET default_method_id = mid
FROM sl_solver_method m
WHERE (s.sid = m.sid) AND (s.name = 'predictive_solver') AND (m.name='advisor');


----Solver specification
----
----
----
----
----
----
drop function if exists predictive_solver_advisor(sl_solver_arg);
CREATE OR REPLACE FUNCTION predictive_solver_advisor(arg sl_solver_arg) RETURNS setof record AS $$
DECLARE
	-- All the variable of PGSQL code are declared at the beginning of the function
	-- unique id name of the input relation
	input_table	name = sl_get_unique_tblname() ||'_pr';

	--training/prediction sets from the input relation
	target_tables	name[] := '{}';
	training_tables	name[] := '{}';

	i		        	int;		   
	input_clmn 		record;
	input_feature_col_names  	name[] :=  '{}';
	input_feature_col_types  	text[] :=  '{}';
	input_time_col_names  	name[] :=  '{}';
	input_time_col_types  	text[] :=  '{}';
	target_column_name 	name;
	target_column_type 	text;
	attMethods			text;
	ml_methods_to_test		text[] := '{}';
	ts_methods_to_test		text[] := '{}';
	custom_methods_to_test	text[] := '{}';
	tmp_string_array 		text[] := '{}';
	attFeatures		text;
	attStartTime		text;
	attEndtime			text;
	attFrequency		text;
	attNumberOfPredictions int;
	tmp_name		text;
	final_ml_features		text[] = '{}';
	final_ts_features		text[] = '{}';
	k			int = 10;
	ts_target_table		name;
	test_ml_methods		boolean;
	test_ts_methods		boolean;
	test_custom_methods	boolean;
	tmp_numeric		numeric;
	tmp_numeric_array	numeric[];
	tmp_string		text;
	training_data_query 	text;
	tmp_record		record;
	results_table		text := sl_build_pr_results_table();
	chosen_method		text;
	-- for testing only
	predictions		numeric[];
	training_test		jsonb;		--temporary containers for result tables (use GD)
	ml_training_test	jsonb;	
     
BEGIN       
	--------//////     	SETUP		////-------------------------------

	-- Creates the view for the input relation, with name id @input_table
	PERFORM sl_create_view(sl_build_out(arg), input_table); 
	-- turns off verbose message printing of model training
	PERFORM sl_set_print_model_summary_off();
	
     -- Input/parameter import and checking 
	IF array_length(((arg).problem).cols_unknown, 1) != 1 THEN
		RAISE EXCEPTION 'Single target prediction supported. 
		Select a single column as SOLVESELECT target, 
		e.g. "SOLVESELECT your_column IN (SELECT * FROM your_table) USING predictive_solver()"';
	END IF;
	target_column_name 	= ((arg).problem).cols_unknown[1];
	attMethods       	= sl_param_get_as_text(arg, 'methods');
	attFeatures       	= sl_param_get_as_text(arg, 'features');
	attStartTime       	= sl_param_get_as_text(arg, 'start_time');
	attEndTime       	= sl_param_get_as_text(arg, 'end_time');
	attNumberOfPredictions 	= sl_param_get_as_int(arg, 'predictions');
	
	-- check the ensamble of forecasting methods to test (from input or default)
	IF attMethods is null THEN
		for tmp_record in select * from sl_pr_method loop
			if tmp_record.type = 'ts' then
				ts_methods_to_test := ts_methods_to_test || tmp_record.funct_name::text;
			elsif tmp_record.type = 'ml' then
				ml_methods_to_test := ml_methods_to_test || tmp_record.funct_name::text;
			elsif tmp_record.type = 'custom' then
				custom_methods_to_test := custom_methods_to_test || tmp_record.funct_name::text;
			end if;
		end loop;
	ELSE
		tmp_string_array := string_to_array(attMethods, ',');
		for i in 1..array_length(tmp_string_array,1) LOOP
			execute format('select type::text from sl_pr_method where funct_name = %L',
					tmp_string_array[i]) into tmp_string;
			CASE 
				WHEN tmp_string = 'ts' then
					ts_methods_to_test := ts_methods_to_test || tmp_string_array[i];
				WHEN tmp_string = 'ml' then
					ml_methods_to_test := ml_methods_to_test || tmp_string_array[i];
				WHEN tmp_string = 'custom' then
					custom_methods_to_test := custom_methods_to_test || tmp_string_array[i];
				ELSE 
			END CASE;
		END LOOP;
	END IF;

	-- control that sets if to test ML/TS
	IF array_length(ml_methods_to_test, 1) > 0 THEN
		test_ml_methods := True;
	END IF;
	IF array_length(ts_methods_to_test, 1) > 0 THEN
		test_ts_methods := True;
	END IF;
	IF array_length(custom_methods_to_test, 1) > 0 THEN
		test_custom_methods := True;
	END IF;

		-- separates columns in target, time columns and feature columns
	for input_clmn in select att_name, att_type, att_kind from  sl_get_attributes_from_sql('select * from ' || input_table || ' limit 1')
	loop
		-- check if feature is solvedb id, skip it
		if input_clmn.att_name = arg.tmp_id then
			continue;
		end if;
		if input_clmn.att_name = target_column_name then
			target_column_type  = input_clmn.att_type;
		else
			if coalesce((select input_clmn.att_type = any (enum_range(null::sl_supported_time_types)::text[])), false) then
				input_time_col_names[coalesce(array_length(input_time_col_names, 1), 0)] := input_clmn.att_name;
				input_time_col_types[coalesce(array_length(input_time_col_types, 1), 0)] := input_clmn.att_type;
			else
				input_feature_col_names[coalesce(array_length(input_feature_col_names, 1), 0)] := input_clmn.att_name;
				input_feature_col_types[coalesce(array_length(input_feature_col_types, 1), 0)] := input_clmn.att_type;
			end if;
		end if;		
	 end loop;

	 -- set the user defined features (if found)
	IF attFeatures IS NULL THEN
		-- NOTHING, THE FEATURE SELECTOR WILL CHOOSE THE FEATURES
		final_ts_features := input_time_col_names;
		final_ml_features := input_feature_col_names;
	ELSE
		tmp_string_array := string_to_array(attFeatures, ',');
		for i in 1..array_length(tmp_string_array,1) LOOP
			IF (select tmp_string_array[i] = ANY (input_feature_col_names::text[])) then
				final_ml_features := final_ml_features || tmp_string_array[i];
			ELSIF (select tmp_string_array[i] = ANY (input_time_col_names::text[])) then
 				final_ts_features := final_ts_features || tmp_string_array[i];
 			ELSE
				RAISE EXCEPTION 'Column % not present in input Table', tmp_string_array[i];
			END IF;
		END LOOP;
		-- check if multiple time columns are present, alert the user
		if test_ts_methods AND array_length(final_ts_features, 1) > 1 then
			raise notice 'Multiple time variables in input schema. Column % will be used. 
			To select a specific column for the time series, add argument "time_column := your_time_column"', final_ts_features[0];
		end if;
	END IF;

	raise notice 'final_ml_features-----------%', final_ml_features;
	raise notice 'ts:%, ml:%', test_ts_methods, test_ml_methods;
	raise notice 'target:%', target_column_name;

	-- PREPARE THE TABLES FOR THE TYPE OF PREDICTION (TIME/NULL ROWS/NUMBER OF PREDICTIONS)
	IF attStartTime IS NOT NULL THEN
		attStartTime = convert_date_string(attStartTime);
		IF attStartTime IS NULL THEN
			RAISE EXCEPTION 'Given START TIME is not a recognizable time format, or the date is incorrect.';
		END IF;
	END IF;
	
	IF attEndTime IS NOT NULL THEN
		attEndTime = convert_date_string(attEndTime);
		IF attEndTime IS NULL THEN
			RAISE EXCEPTION 'Given END TIME is not a recognizable time format, or the date is incorrect.';
		END IF;
	END IF;
	
 	BEGIN
		-- check that target column is of numeric value (only numeric predictions supported in current version)
		tmp_string := 'select ' || target_column_name || ' from ' || input_table || ' where ' || target_column_name || ' is not null limit 1';
		execute tmp_string into tmp_numeric;
	EXCEPTION
		WHEN SQLSTATE '22P02' THEN
			RAISE EXCEPTION 'Impossible to parse given argument/s';
	END;
	
	IF (attStartTime IS NOT NULL AND attEndTime IS NOT NULL) AND attStartTime > attEndTime THEN
		RAISE EXCEPTION 'Error in given time interval: start_time > end_time.';
	END IF;

 	--separate training data from target data, depending if on NULL rows, or on time range
 	--TODO the following 3 lines select only the columns that should be selected. REMOVE and select all columns
	--tmp_string_array := '{}';
	--tmp_string_array := tmp_string_array || time_feature;
	--tmp_string_array := tmp_string_array || arg.tmp_id::text || target_column_name::text;

	-- Predictions are based on the time range given by the user
	IF attEndTime is not null THEN
		tmp_name := separate_input_relation_on_time_range(target_column_name, arg.tmp_id, 
				final_ts_features[0], input_table, attStartTime, attEndTime);
		IF tmp_name is null THEN 
			RAISE EXCEPTION 'No rows to fill in the given Table. Model training/saving not yet implemented.';
		END IF;

		target_tables := target_tables || tmp_name;
		tmp_name := sl_build_view_except_from_sql(input_table, tmp_name, 
							arg.tmp_id, (input_time_col_names || input_feature_col_names || target_column_name || arg.tmp_id), time_feature);
		IF tmp_name is null THEN
			RAISE EXCEPTION 'No rows for training in the given Table. 
				All rows have null values for the specified target.';
		END IF;
		training_tables := training_tables || tmp_name;
	-- Predictions are based on the number of predictions specified by the user
	ELSIF number_of_predictions IS NOT NULL THEN
		raise exception 'number of predictions not implemented yet';
	-- Predictions fill the NULL values (AT THE END) of the time series
	ELSE	
		raise exception 'filling null values not implemented yet';
	END IF;

---------------------------------------- ////// END SETUP	---------------------------------------------------------
	if test_ts_methods THEN
		select sl_time_series_models_handler(arg, target_column_name, target_column_type, final_ts_features[0], 
			results_table, ts_methods_to_test) into training_test;	
	END IF;
	-- DEBUG
	--IF test_ml_methods THEN
	--	SELECT sl_ml_models_handler(arg, target_column_name, target_column_type, final_ml_features,
	--		input_table, results_table, ml_methods_to_test, k) into training_test;
	--END IF;


	--look in the results table the model with the best result
	--result table contains the followiing values [method text, parameters json, result numeric]
--	find the best model method
	execute format('select method from %s where result is not null order by result desc limit 1', results_table) into chosen_method;
	execute format('select result from %s where result is not null order by result desc limit 1', results_table) into tmp_numeric;
	execute format('select parameters from %s where result is not null order by result desc limit 1', results_table) into tmp_string;

	--PRINT INFORMATION FOR THE USER
	raise notice '---------------------------------------------';
	raise notice 'Best method found for the given data: %s', chosen_method;
	raise notice 'Parameters for the method: %', tmp_string;
	raise notice 'The method has given a RMSE of % on the training data', tmp_numeric;
	PERFORM sl_set_print_model_summary_on();

	
	training_data_query := format('SELECT * FROM %s', training_test->'training');

-- -- -- -- -- -- -- 
-- -- -- -- -- -- -- 	--EXECUTE format('select lr_predict(features := %L,
-- -- -- -- -- -- -- 	-- target_column_name := %L, training_data := %L, test_data := %L)', 
-- -- -- -- -- -- -- 	--	'',
-- -- -- -- -- -- -- 	--	'pvsupply', 
-- -- -- -- -- -- -- 	--	training_data_query,
-- -- -- -- -- -- -- 	--	format('SELECT * FROM %s', training_test->'test'))
-- -- -- -- -- -- -- 	--	into predictions;

	-- FOR Ts--TODO:FIX THE FLOW
 	EXECUTE format('SELECT count(*) FROM %s', training_test->'test') into i;
 	EXECUTE format('SELECT %s(%s, time_column_name:=%L, target_column_name:=%L, training_data:=%L, number_of_predictions:=%s)',
 			chosen_method,
 			tmp_string, 
 			input_time_col_names[0],
 			target_column_name,
 			training_data_query,
 			i) into predictions;

 	tmp_string_array := '{}';


-- -- -- -- -- -- -- 	Write the predictions in the final table
-- -- -- -- -- -- ----ML flow TODO: fix and integrate
-- -- -- -- -- -- -- 	i := 1;
-- -- -- -- -- -- -- 	for tmp_record in EXECUTE format('SELECT ts as t FROM %s where pvsupply is null order by ts', 
-- -- -- -- -- -- -- 		input_table) 
-- -- -- -- -- -- -- 	LOOP
-- -- -- -- -- -- -- 		EXECUTE format('UPDATE %s SET %s = %s WHERE %s=%L',
-- -- -- -- -- -- -- 				input_table,
-- -- -- -- -- -- -- 				target_column_name,
-- -- -- -- -- -- -- 				predictions[i],
-- -- -- -- -- -- -- 				'ts',
-- -- -- -- -- -- -- 				tmp_record.t);
-- -- -- -- -- -- -- 		i = i + 1;
-- -- -- -- -- -- -- 	END LOOP;
-- 	
	
				

--TS flow, TODO: fix and integrate with ML

	for tmp_record in EXECUTE format('SELECT %s as t FROM %s ORDER BY %s ASC', 
			input_time_col_names[0],
			training_test->'test',
			input_time_col_names[0]
			) 
		LOOP
			tmp_string_array := tmp_string_array || tmp_record.t::text;
	END LOOP;
	for i in 1..array_length(tmp_string_array, 1) LOOP
			EXECUTE format('UPDATE %s SET %s = %s WHERE %s=%L',
					input_table,
					target_column_name,
					predictions[i],
					input_time_col_names[0],
					tmp_string_array[i]
					);
			EXECUTE format('INSERT INTO %s(%s, %s) SELECT %L, %s WHERE NOT EXISTS (SELECT 1 FROM %s WHERE %s=%L)',
					input_table,
					input_time_col_names[0],
					target_column_name,
					tmp_string_array[i],
					predictions[i],
					input_table,
					input_time_col_names[0],
					tmp_string_array[i]
					);

	END LOOP;

        RETURN QUERY EXECUTE sl_return(arg, sl_build_out(arg));
        perform sl_drop_view_cascade(input_table);
END;
$$ LANGUAGE plpgsql STRICT;


