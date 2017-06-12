-- inner function managed by "predictive_solver_advisor" that 
-- handles the execution of time series predictive models
drop function if exists sl_time_series_models_handler(sl_solver_arg, 
		 name,  text,
		 text,  text,  text,  text, 
		 name,  text,  text[]);
CREATE OR REPLACE FUNCTION sl_time_series_models_handler(arg sl_solver_arg, 
		target_column_name name, target_column_type text,
		attStartTime text, attEndTime text, attFrequency text, time_feature text, 
		input_table_tmp_name name, results_table text, ts_methods_to_test text[])
RETURNS text AS $$

DECLARE
	timeFrequency		int := null;
	tmp_string_array 	text[] := '{}';
	ts_target_tables	name[] := '{}';
	ts_training_tables	name[] := '{}';
	ts_training_sets	text[] := '{}'; 
	ts_test_sets		text[] := '{}'; 
	tmp_string		text;
	tmp_name		name;
	tmp_integer		integer;
	method_parameters	sl_model_parameter_type[] := '{}';
	tmp_numeric_array	numeric[] := '{}';
	tmp_record		record;
	tmp_numeric		numeric;
	i			int;
	training_test		text;

BEGIN
-- 	check time arguments (if time columns are present in the table)
	if time_feature is null THEN
		RAISE EXCEPTION 'No time columns present in the given Table. 
					Impossible to process time series.';
	END IF;
	
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
		IF attFrequency IS NOT NULL THEN
			timeFrequency := attFrequency::int; 
		ELSE	
			timeFrequency := -1;
		END IF;
		tmp_string := 'select ' || target_column_name || ' from ' || input_table_tmp_name || ' where ' || target_column_name || ' is not null limit 1';
		execute tmp_string into tmp_numeric;
	EXCEPTION
		WHEN SQLSTATE '22P02' THEN
			RAISE EXCEPTION 'Impossible to parse given argument/s';
	END;
	
	IF (attStartTime IS NOT NULL AND attEndTime IS NULL) OR (attStartTime IS NULL AND attEndTime IS NOT NULL) THEN
		RAISE EXCEPTION 'Prediction time interval needs to be defined with <start,end> as 
			start_time:="your_start_time", end_time:="your_end_time"';
	END IF;
		IF (attStartTime IS NOT NULL AND attEndTime IS NOT NULL) AND attStartTime > attEndTime THEN
		RAISE EXCEPTION 'Error in given time interval: start_time > end_time.';
	END IF;


-- 	separate training data from target data, depending if on NULL rows, or on time range
	tmp_string_array := '{}';
	tmp_string_array := tmp_string_array || time_feature;
	tmp_string_array := tmp_string_array || arg.tmp_id::text || target_column_name::text;

	-- FILL TIME RANGE
	IF attStartTime is not null AND attEndTime is not null THEN
		tmp_name := separate_input_relation_on_time_range(target_column_name, arg.tmp_id, 
				time_feature, timeFrequency, input_table_tmp_name, 
				attStartTime, attEndTime);
		IF tmp_name is null THEN 
			RAISE EXCEPTION 'No rows to fill in the given Table. Model training/saving not yet implemented.';
		END IF;
		ts_target_tables := ts_target_tables || tmp_name;

		tmp_name := sl_build_view_except_from_sql(input_table_tmp_name, tmp_name,
					arg.tmp_id, tmp_string_array);
		IF tmp_name is null THEN
			RAISE EXCEPTION 'No rows for training in the given Table. All rows have null values for the specified target.';
		END IF;
		ts_training_tables := ts_training_tables || tmp_name;
	ELSE	-- FILL NULL ROWS, TODO: implement
		null;
	END IF;

	-- Create 70%-30% (default value) split for each of the test/training set that need to be evaluated
	for i in 1.. array_length(ts_training_tables, 1) LOOP
		execute 'SELECT COUNT(*) FROM ' || ts_training_tables[i] into tmp_integer;
		tmp_string  := sl_get_unique_tblname() || '_pr_ts_training';
		EXECUTE format('CREATE VIEW %s AS SELECT %s,%s FROM %s LIMIT %s',
			tmp_string,
			time_feature,
			target_column_name,
			ts_training_tables[i],
			((tmp_integer/100) * 70)::int);
		ts_training_sets := ts_training_sets || tmp_string;
		tmp_string  := sl_get_unique_tblname() || '_pr_ts_test';
		EXECUTE format('CREATE TABLE %s AS SELECT %s,%s FROM %s OFFSET %s',
			tmp_string,
			time_feature,
			target_column_name,
			ts_training_tables[i],
			((tmp_integer/100) * 70)::int);
		ts_test_sets := ts_test_sets || tmp_string;
	END LOOP;

	for tmp_integer in 1..array_length(ts_training_sets, 1) LOOP
		-- create test values
		tmp_string := 'SELECT * FROM ' || ts_test_sets[tmp_integer];
		tmp_numeric_array := sl_extract_column_to_array(tmp_string, target_column_name);			

		for i in 1..array_length(ts_methods_to_test,1) LOOP
			-- get user defined parameter to test
			for tmp_record in execute format('select parameter_info from sl_pr_model_parameters  
				where model_id in (select sid from sl_pr_models where predict = %L)',
				ts_methods_to_test[i])
			LOOP
				method_parameters := method_parameters || tmp_record.parameter_info;
			END LOOP;
			-- call handler
			perform ts_method_handler_brute(results_table, time_feature, 
						target_column_name, ts_training_sets[i], 
						tmp_numeric_array, 
						ts_methods_to_test[i], method_parameters);
--		perform arima_handler(results_table, input_time_col_names[0], target_column_name, training_data_query, test_data_query);
		END LOOP;
	END LOOP;


	-- execute format('insert into temp values(''{"training" : "%s", "test" : "%s"}'')',
-- 	 ts_training_tables[1], ts_target_tables[1]);
	return format('{"training" : "%s", "test" : "%s"}',
		ts_training_tables[1], ts_target_tables[1]);
END;
$$ language plpgsql; 