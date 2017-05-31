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
     input_table_tmp_name	text = 'pr_input_relation';
     final_ml_features		text[] = '{}';
     final_ts_features		text[] = '{}';
	k			int = 10;
	kCrossTestViews 	text[] := '{}';
	kCrossTrainingViews 	text[] := '{}';
	ts_training_view	text := 'pr_ts_training';
	ts_test_view		text := 'pr_ts_test';
	tsSplitQuery		text;
	input_length		int;
	ts_features		text[] := '{}';
	ml_features		text[] := '{}';
	timeFrequency		int;
	ml_target_view		text;
	ts_target_view		text;
     
BEGIN       

	raise notice 'this is the default method';   
	PERFORM sl_create_view(sl_build_out(arg), input_table_tmp_name); 


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
		ts_methods_to_test := enum_range(null::sl_supported_ts_forecasting_methods)::text[];
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

	-- separates columns in target, time columns and feature columns
	for input_clmn in select att_name, att_type from  sl_get_attributes_from_sql('select * from pr_input_relation limit 1')
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

	-- check time arguments (if time columns are present in the table)
	 if (attStartTime IS NOT NULL OR attEndTime IS NOT NULL) AND array_length(input_time_col_names,1) = 0 THEN
		RAISE EXCEPTION 'No time columns present in the given Table. Impossible to process arguments.';
	 END IF;

	IF attStartTime IS NOT NULL THEN
		attStartTime = convert_date_string(attStartTime);
		IF attStartTime IS NULL THEN
			RAISE EXCEPTION 'Given START TIME is not a recognizable time format, or the date is incorrect.';
		END IF;
		raise notice 'time %', attStartTime;
	END IF;
	IF attEndTime IS NOT NULL THEN
		attEndTime = convert_date_string(attEndTime);
		IF attEndTime IS NULL THEN
			RAISE EXCEPTION 'Given END TIME is not a recognizable time format, or the date is incorrect.';
		END IF;
	END IF;
	IF attFrequency IS NOT NULL THEN
		timeFrequency = attFrequency::int; 
	END IF;

	IF (attStartTime IS NOT NULL AND attEndTime IS NULL) OR (attStartTime IS NULL AND attEndTime IS NOT NULL) THEN
		RAISE EXCEPTION 'Time interval needs to be defined with <start,end> as 
			start_time:="your_start_time", end_time:="your_end_time"';
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
		if array_length(ts_methods_to_test,1) > 1 AND array_length(final_ts_features, 1) > 1 then
			raise notice 'Multiple time variables in input schema. Column % will be used. To select a specific column for the time series, add argument "time_column := name_of_time_column"', final_ts_features[1];
		end if;
	END IF;
	RAISE NOTICE '%, %', final_ml_features, final_ts_features[1];


	 -- split into training data (with filled target column) and target data (with empty target column)
	 -- if time range is given, and a time column is present, prepare the time series table with additional rows with for given range
	 -- if time range is not given AND no empty rows are found
		-->test on the training set and give the results of the prediction to the user


	

	ml_target_view := separate_input_relation_on_empty_rows(target_column_name, final_ml_features, input_table_tmp_name);
	raise notice 'table is % of rows mooom', ml_target_view;

	-- ts_target_view := separate_input_relation_on_time_range(target_column_name, final_ts_features[1], 
-- 		attStartTime, attEndTime, timeFrequency, input_table_tmp_name)
	-->RESULT: TRAINING_VIEW, TEST_VIEW


	-- create K views for k cross folding on the training data
	if array_length(input_feature_col_names, 1) > 0 THEN
		execute 'SELECT COUNT(*) FROM $1' into input_length using pr_input_relation;
		for i in 0..(k-1) loop
			EXECUTE format('CREATE OR REPLACE TEMP VIEW pr_cross_test_%s (%s,%s) AS SELECT %s,%s FROM %s LIMIT (%s) OFFSET (%s)', 
				i,
				(SELECT string_agg(format('%s',quote_ident(input_feature_col_names[j])), ',')
				FROM generate_subscripts(input_feature_col_names, 1) AS j),
				target_column_name,
				(SELECT string_agg(format('%s',quote_ident(input_feature_col_names[j])), ',')
				FROM generate_subscripts(input_feature_col_names, 1) AS j),
				target_column_name,
				input_table_tmp_name,
				input_length/k,
				i * (input_length/k));
			kCrossTestViews := kCrossTestViews || format('pr_cross_test_%s',i);
			EXECUTE format('CREATE OR REPLACE TEMP VIEW pr_cross_training_%s (%s, %s) AS SELECT %s, %s from %s EXCEPT SELECT * FROM %s',
				i,
				(SELECT string_agg(format('%s',quote_ident(input_feature_col_names[j])), ',')
				FROM generate_subscripts(input_feature_col_names, 1) AS j),
				target_column_name,
				(SELECT string_agg(format('%s',quote_ident(input_feature_col_names[j])), ',')
				FROM generate_subscripts(input_feature_col_names, 1) AS j),
				target_column_name,
				input_table_tmp_name,
				kCrossTestViews[i+1]);
			 kCrossTrainingViews := kCrossTrainingViews|| format('pr_cross_training_%s', i);
		end loop;
	END IF;

	-- Create 70%-30% split for time series forecasting
	IF array_length(input_time_col_names,1) > 0 THEN
		EXECUTE format('CREATE OR REPLACE TEMP VIEW %s AS SELECT %s,%s FROM %s LIMIT %s',
			ts_training_view,
			input_time_col_names[0],
			target_column_name,
			input_table_tmp_name,
			((input_length/100) * 70)::int);
		EXECUTE format('CREATE OR REPLACE TEMP VIEW %s AS SELECT %s,%s FROM %s OFFSET %s',
			ts_test_view,
			input_time_col_names[0],
			target_column_name,
			input_table_tmp_name,
			((input_length/100) * 70)::int);
	END IF;

	


	-- set the features for the models, if given by the user
	

	
	--raise notice 'start the feature selection';
	-- find the feature set
	--input_feature_col_names := feature_selection(input_feature_col_names, target_column_name, 'input_relation');
	--raise notice 'back from python';


	
        --PERFORM f_selector(arg, target_column_name, );
        --return query execute sl_return(arg, sl_build_out(arg), 'input_relation');
	
	
-- 	-- create temporary view input_schema containing the time column and the target value, and the rows to predcit
--  	execute 'create or replace view input_schema as select ' || input_time_col_names[0] || ', ' || target_column_name || ' from input_relation';
-- 	tmp_forecasting_table_name := create_temporary_forecasting_table(target_column_name, input_time_col_names[0], sl_param_get_as_text(arg, 'start_time'), sl_param_get_as_text(arg, 'end_time'), 'input_schema');
-- -- 	fill rows with prediction, and join with original table
--  	perform arima_prediction(target_column_name, input_time_col_names[0], 'input_schema', tmp_forecasting_table_name, sl_param_get_as_text(arg, 'start_time'), sl_param_get_as_text(arg, 'end_time'));
-- 
-- 	-- create array of columns to join (in the default case only time feature and target feature)
-- 	test_joining_columns := input_time_col_names || target_column_name;
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


	EXCEPTION
		-- conversion of the method's arguments to integer failed 
		WHEN SQLSTATE '22P02' THEN
			RAISE EXCEPTION 'Impossible to parse given argument/s';

END;
$$ LANGUAGE plpgsql STRICT;


-- 
solveselect watt in (select * from Test) 
using predictive_solver();



