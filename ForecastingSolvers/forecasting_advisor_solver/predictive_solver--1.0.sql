--Install the solver method
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
     test_joining_columns 	name[] := '{}';
     test_not_joining_columns 	name[] := '{}';
     t       			sl_attribute_desc;
     v_o     			sl_viewsql_out;
     v_d     			sl_viewsql_dst;     
     tmp_forecasting_table_name text;
     attMethods			text;
     ml_methods_to_test		text[] := '{}';
     ts_methods_to_test		text[] := '{}';
     tmp_string_array 		text[] := '{}';
     attFeatures		text;
     attStartTime		text;
     attEndtime			text;
     attFrequency		text;
     input_table_tmp_name	name = 'pr_input_relation';
     final_ml_features		text[] = '{}';
     final_ts_features		text[] = '{}';
	k			int = 10;
	kCrossTestViews 	text[] := '{}';
	kCrossTrainingViews 	text[] := '{}';
	ts_training		text := 'pr_ts_training';
	ts_test			text := 'pr_ts_test';
	tsSplitQuery		text;
	input_length		int;
	ts_features		text[] := '{}';
	ml_features		text[] := '{}';
	timeFrequency		int := null;
	ml_target_table		name;
	ts_target_table		name;
	test_ml_methods		boolean;
	test_ts_methods		boolean;
	tmp_numeric		numeric;
	tmp_string		text;
	ml_training_table	name;
	ts_training_table	name;
	method 			VARCHAR[];
	row_data		sl_pr_model_parameters%ROWTYPE;


	-- for testing only, before parameter solving is
	model_parameter_name	text[];
	model_parameter_value	numeric[];
	model_parameter_low	numeric[];
	model_parameter_high	numeric[];
	model_parameter_type	text[];

	model_fit_result	numeric[];
     
BEGIN       

	raise notice 'this is the default method';   
	input_table_tmp_name := sl_get_unique_tblname() || input_table_tmp_name;
	PERFORM sl_create_view(sl_build_out(arg), input_table_tmp_name); 

	execute 'select * from python_test()' into tmp_string;
	raise notice 'pl: %', tmp_string;


	--------//////     	SETUP		////-------------------------------
	
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
		ml_methods_to_test := enum_range(null::sl_supported_ml_forecasting_methods)::text[];
		test_ml_methods := True;
		ts_methods_to_test := enum_range(null::sl_supported_ts_forecasting_methods)::text[];
		test_ts_methods := True;
	ELSE
		tmp_string_array := string_to_array(attMethods, ',');
		for i in 1..array_length(tmp_string_array,1) LOOP
			IF coalesce((select tmp_string_array[i] = any (enum_range(null::sl_supported_ml_forecasting_methods)::text[])), false) then
				ml_methods_to_test := ml_methods_to_test || tmp_string_array[i];
			ELSIF coalesce((select tmp_string_array[i] = any (enum_range(null::sl_supported_ts_forecasting_methods)::text[])), false) then
				ts_methods_to_test := ts_methods_to_test || tmp_string_array[i];
			ELSE
				raise exception 'The method "%" is not supported. The currently supported methods are: %, %', tmp_string_array[i], enum_range(null::sl_supported_ml_forecasting_methods)::text[], enum_range(null::sl_supported_ts_forecasting_methods)::text[];
			END IF;
		END LOOP;
	END IF;

	-- control that sets if to test ML/TS
	IF array_length(ml_methods_to_test, 1) > 0 THEN
		test_ml_methods := True;
	END IF;
	IF array_length(ts_methods_to_test, 1) > 0 THEN
		test_ts_methods := True;
	END IF;
	
	-- separates columns in target, time columns and feature columns
	for input_clmn in select att_name, att_type from  sl_get_attributes_from_sql('select * from ' || input_table_tmp_name || ' limit 1')
	loop
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

	IF test_ts_methods THEN
		-- check time arguments (if time columns are present in the table)
		 if array_length(input_time_col_names,1) = 0 THEN
			RAISE EXCEPTION 'No time columns present in the given Table. Impossible to process time series.';
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

		
	END IF;

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


	 -- split into training data (with filled target column) and target data (with empty target column/given time range)
	-- separate traning data from target data (for ml methods)
	IF test_ml_methods THEN
		ml_target_table := separate_input_relation_on_empty_rows(target_column_name, final_ml_features, input_table_tmp_name);
		IF ml_target_table is null THEN 
			RAISE EXCEPTION 'No rows to fill in the given Table. Model training/saving not yet implemented.';
		END IF;

		ml_training_table := sl_build_view_except_from_sql(format('SELECT * FROM  %s', ml_target_table));
		IF ml_training_table is null THEN
			RAISE EXCEPTION 'No rows for training in the given Table. All rows have null values for the specified target.';
		END IF;
	END IF;
	

	-- separate training data from target data (for time series)
	IF test_ts_methods THEN
		ts_target_table := separate_input_relation_on_time_range(target_column_name, final_ts_features[0], timeFrequency, input_table_tmp_name, attStartTime, attEndTime);
		IF ts_target_table is null THEN 
			RAISE EXCEPTION 'No rows to fill in the given Table. Model training/saving not yet implemented.';
		END IF;

		ts_training_table := sl_build_view_except_from_sql(format('SELECT * FROM  %s', ts_target_table));
		IF ts_training_table is null THEN
			RAISE EXCEPTION 'No rows for training in the given Table. All rows have null values for the specified target.';
		END IF;
	END IF;



	-- ML METHODS: create K views for k cross folding on the training data 
	-- TO DO: PUSH IT INSIDE THE METHOD, AS THE FEATURE SELECTION WILL PROJECT SOME OF THE COLUMNS
	if test_ml_methods THEN
		execute 'SELECT COUNT(*) FROM ' || ml_training_table into input_length;
		for i in 0..(k-1) loop
			tmp_string := sl_get_unique_tblname() || 'ml_cross_test_' || i;
			EXECUTE format('CREATE OR REPLACE TEMP VIEW %s (%s,%s) AS SELECT %s,%s FROM %s LIMIT (%s) OFFSET (%s)', 
				tmp_string,
				(SELECT string_agg(format('%s',quote_ident(input_feature_col_names[j])), ',')
				FROM generate_subscripts(input_feature_col_names, 1) AS j),
				target_column_name,
				(SELECT string_agg(format('%s',quote_ident(input_feature_col_names[j])), ',')
				FROM generate_subscripts(input_feature_col_names, 1) AS j),
				target_column_name,
				input_table_tmp_name,
				input_length/k,
				i * (input_length/k));
			kCrossTestViews := kCrossTestViews || tmp_string;
			tmp_string := sl_get_unique_tblname() || 'ml_cross_training_' || i;
			EXECUTE format('CREATE OR REPLACE TEMP VIEW %s (%s, %s) AS SELECT %s, %s from %s EXCEPT SELECT * FROM %s',
				tmp_string,
				(SELECT string_agg(format('%s',quote_ident(input_feature_col_names[j])), ',')
				FROM generate_subscripts(input_feature_col_names, 1) AS j),
				target_column_name,
				(SELECT string_agg(format('%s',quote_ident(input_feature_col_names[j])), ',')
				FROM generate_subscripts(input_feature_col_names, 1) AS j),
				target_column_name,
				input_table_tmp_name,
				kCrossTestViews[i+1]);
			 kCrossTrainingViews := kCrossTrainingViews || tmp_string;
		end loop;
	END IF;

	-- TS METHODS: Create 70%-30% split on the training data
	IF array_length(input_time_col_names,1) > 0 THEN
		ts_training := sl_get_unique_tblname() || ts_training;
		EXECUTE format('CREATE TEMP VIEW %s AS SELECT %s,%s FROM %s LIMIT %s',
			ts_training,
			input_time_col_names[0],
			target_column_name,
			input_table_tmp_name,
			((input_length/100) * 70)::int);
		ts_test := sl_get_unique_tblname() || ts_test;
		EXECUTE format('CREATE TEMP TABLE %s AS SELECT %s,%s FROM %s OFFSET %s',
			ts_test,
			input_time_col_names[0],
			target_column_name,
			input_table_tmp_name,
			((input_length/100) * 70)::int);
	END IF;



	-- test only for each TS model to test, 
		-- fit the model on the training data
			-- provide the user with information on the model performance
		-- fill rows with prediction
		-- join with original table


	FOREACH method SLICE 1 IN ARRAY ts_methods_to_test LOOP
		raise notice 'fitting method: %', method[1];
		-- get user defined parameter to test
		for row_data in execute format('select * from sl_pr_model_parameters  where model_id in (select sid from sl_pr_models where name = ''%s'')', 'arima_stats_models')
		LOOP
			model_parameter_name    := model_parameter_name ||	row_data.name;
			model_parameter_value	:= model_parameter_value || 	row_data.value;
			model_parameter_low	:= model_parameter_low ||	row_data.low_range;
			model_parameter_high	:= model_parameter_high ||	row_data.high_range;
			model_parameter_type	:= model_parameter_type ||	row_data.type;
		END LOOP;

		-- for each parameter, loop through the values
		FOR i IN 1..array_length(model_parameter_name, 1)
		LOOP
			raise notice '%', model_parameter_name[i];
		END LOOP;
		

		-- create instance
		-- fit instance
		-- select best instance, discard other instances


	-- OF THE ENSAMBLE METHODS, SELECT THE METHOD THAT GIVES THE BEST RESULTS
		



		
		-- this method needs to return or save some performance measure.
	--	perform ts_model_fitter(method[1], ts_training_view) --ts model fitter that takes the sql wrapper, writes on Models table the parameters as json object, to be processed by the actual python function
	--  	perform arima_prediction(target_column_name, input_time_col_names[0], 'input_schema', tmp_forecasting_table_name, sl_param_get_as_text(arg, 'start_time'), sl_param_get_as_text(arg, 'end_time'));
	END LOOP;


	-- choose the best model acording to performance measure, write on the ts_test_view
	--perform ts_model_forecaster(best_method, ts_test_view)

	-- create array of columns to join (in the default case only time feature and target feature)
	-- test_joining_columns := input_time_col_names || target_column_name;
-- 	for input_clmns in select att_name from  sl_get_attributes(arg) LOOP
-- 		IF (SELECT input_clmns.att_name = ANY (test_joining_columns)) THEN
-- 			null;
-- 		else
-- 			test_not_joining_columns := test_not_joining_columns || input_clmns.att_name;
-- 		END IF;
-- 	end loop;
-- 
--          RETURN QUERY EXECUTE sl_return(arg, sl_build_union_right_join_debug(arg, test_not_joining_columns, test_joining_columns, tmp_forecasting_table_name));
         perform sl_drop_view_cascade(input_table_tmp_name);



END;
$$ LANGUAGE plpgsql STRICT;


-- 
solveselect watt in (select * from device_log) 
using predictive_solver(start_time:='November 6, 2012', end_time := 'December 6, 2012');
-- 
-- drop function python_test();
-- create function python_test() returns text as $$
-- 	return " ,--- python ";
-- $$ language plpythonu;
-- drop function pl_test();
-- create function pl_test() returns text as $$
-- begin
-- 	return  'miao';
-- end;
-- $$ language plpgsql;




