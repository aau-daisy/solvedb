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
                  values ('methods' , 'text', 'prediction methods to test', null, null, null) 
                  RETURNING pid),
     sspar8 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar8
                  RETURNING sid)  

-- Perform the actual insert
SELECT count(*) FROM solver, method1, spar2, sspar2, spar3, sspar3, spar5, sspar5, spar7, sspar7, spar8, sspar8;

-- Set the default method
UPDATE sl_solver s
SET default_method_id = mid
FROM sl_solver_method m
WHERE (s.sid = m.sid) AND (s.name = 'predictive_solver') AND (m.name='advisor');


--Install the solver method
drop function if exists predictive_solver_advisor(sl_solver_arg);
CREATE OR REPLACE FUNCTION predictive_solver_advisor(arg sl_solver_arg) RETURNS setof record AS $$
DECLARE
     i		        	int;		-- tmp index   
     input_clmn 		record;
     input_feature_col_names  	name[] :=  '{}';
     input_feature_col_types  	text[] :=  '{}';
     input_time_col_names  	name[] :=  '{}';
     input_time_col_types  	text[] :=  '{}';
     -- currently handles a single target column
     target_column_name 	name;
     target_column_type 	text;
--      t       			sl_attribute_desc;
     attMethods			text;
     ml_methods_to_test		text[] := '{}';
     ts_methods_to_test		text[] := '{}';
     custom_methods_to_test	text[] := '{}';
     tmp_string_array 		text[] := '{}';
     attFeatures		text;
     attStartTime		text;
     attEndtime			text;
     attFrequency		text;
     input_table_tmp_name	name = sl_get_unique_tblname() ||'_pr_input_relation';
     final_ml_features		text[] = '{}';
     final_ts_features		text[] = '{}';
	k			int = 10;
-- 	ts_target_table		name;
	test_ml_methods		boolean;
	test_ts_methods		boolean;
	test_custom_methods	boolean;
	tmp_numeric		numeric;
	tmp_numeric_array	numeric[];
	tmp_string		text;
-- 	method 			VARCHAR[];
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
	
	PERFORM sl_create_view(sl_build_out(arg), input_table_tmp_name); 
	PERFORM sl_set_print_model_summary_off();
	
     -- Check if the arguments are given and table format are correct
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
	attFrequency       	= sl_param_get_as_text(arg, 'frequency');
	
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
	for input_clmn in select att_name, att_type, att_kind from  sl_get_attributes_from_sql('select * from ' || input_table_tmp_name || ' limit 1')
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

	-- prepare table for containing predictions




	


---------------------------------------- ////// END SETUP	---------------------------------------------------------
	if test_ts_methods THEN
		select sl_time_series_models_handler(arg, target_column_name, target_column_type, attStartTime, 
			attEndTime, attFrequency, final_ts_features[0], input_table_tmp_name, 
			results_table, ts_methods_to_test) into training_test;	
	END IF;
	-- DEBUG
	--IF test_ml_methods THEN
	--	SELECT sl_ml_models_handler(arg, target_column_name, target_column_type, final_ml_features,
	--		input_table_tmp_name, results_table, ml_methods_to_test, k) into training_test;
	--END IF;


-- 	look in the results table the model with the best result
-- 	result table contains the followiing values [method text, parameters json, result numeric]
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
	--raise notice 'training test is %', training_test->'test';
	
	training_data_query := format('SELECT * FROM %s', training_test->'training');

	--EXECUTE format('select lr_predict(features := %L,
	-- target_column_name := %L, training_data := %L, test_data := %L)', 
	--	'',
	--	'pvsupply', 
	--	training_data_query,
	--	format('SELECT * FROM %s', training_test->'test'))
	--	into predictions;

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


-- 	Write the predictions in the final table
----ML flow TODO: fix and integrate
-- 	i := 1;
-- 	for tmp_record in EXECUTE format('SELECT ts as t FROM %s where pvsupply is null order by ts', 
-- 		input_table_tmp_name) 
-- 	LOOP
-- 		EXECUTE format('UPDATE %s SET %s = %s WHERE %s=%L',
-- 				input_table_tmp_name,
-- 				target_column_name,
-- 				predictions[i],
-- 				'ts',
-- 				tmp_record.t);
-- 		i = i + 1;
-- 	END LOOP;
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
					input_table_tmp_name,
					target_column_name,
					predictions[i],
					input_time_col_names[0],
					tmp_string_array[i]
					);
				EXECUTE format('INSERT INTO %s(%s, %s) SELECT %L, %s WHERE NOT EXISTS (SELECT 1 FROM %s WHERE %s=%L)',
					input_table_tmp_name,
					input_time_col_names[0],
					target_column_name,
					tmp_string_array[i],
					predictions[i],
					input_table_tmp_name,
					input_time_col_names[0],
					tmp_string_array[i]
					);

		END LOOP;

        RETURN QUERY EXECUTE sl_return(arg, sl_build_out(arg));
        perform sl_drop_view_cascade(input_table_tmp_name);
END;
$$ LANGUAGE plpgsql STRICT;


