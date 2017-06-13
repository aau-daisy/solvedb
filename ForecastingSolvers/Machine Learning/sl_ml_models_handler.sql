drop function if exists sl_ml_models_handler(sl_solver_arg, 
		 name,  text,
		 name,  text,  text[]);
CREATE OR REPLACE FUNCTION sl_ml_models_handler(arg sl_solver_arg, 
		target_column_name name, target_column_type text, final_ml_features text[],
		input_table_tmp_name name, results_table text, ml_methods_to_test text[],
		k int)
RETURNS text AS $$

DECLARE
	tmp_string_array	text[] := '{}';
	ml_target_table		name;
	ml_training_table	name;
	i		        int;		-- tmp index   
	tmp_string		text;
	input_length		int;		-- temporary int value
	kCrossTestViews 	text[] := '{}';
	kCrossTrainingViews 	text[] := '{}';

BEGIN

	-- split into training data (with filled target column) and target data 
	-- (with empty target column/given time range)
	-- separate traning data from target data (for ml methods)
	tmp_string_array := final_ml_features;
	tmp_string_array := tmp_string_array ||  arg.tmp_id::text;
	ml_target_table := separate_input_relation_on_empty_rows(target_column_name, tmp_string_array, 
					input_table_tmp_name);
	IF ml_target_table is null THEN 
		RAISE EXCEPTION 'No rows to fill in the given Table. 
					Model training/saving not yet implemented.';
	END IF;
	tmp_string_array := tmp_string_array || target_column_name::text;
	ml_training_table := sl_build_view_except_from_sql(input_table_tmp_name, ml_target_table, 
						arg.tmp_id, tmp_string_array);
	IF ml_training_table is null THEN
		RAISE EXCEPTION 'No rows for training in the given Table. 
			All rows have null values for the specified target.';
	END IF;

	-- ML METHODS: create K views for k cross folding on the training data 
	-- TO DO: PUSH IT INSIDE THE METHOD, AS THE FEATURE SELECTION WILL PROJECT SOME OF THE COLUMNS
	execute 'SELECT COUNT(*) FROM ' || ml_training_table into input_length;
	for i in 0..(k-1) loop
		tmp_string := sl_get_unique_tblname() || 'ml_cross_test_' || i;
		EXECUTE format('CREATE OR REPLACE TEMP VIEW %s (%s,%s) AS SELECT %s,%s 
				FROM %s LIMIT (%s) OFFSET (%s)', 
			tmp_string,
			(SELECT string_agg(format('%s',quote_ident(final_ml_features[j])), ',')
			FROM generate_subscripts(final_ml_features, 1) AS j),
			target_column_name,
			(SELECT string_agg(format('%s',quote_ident(final_ml_features[j])), ',')
			FROM generate_subscripts(final_ml_features, 1) AS j),
			target_column_name,
			ml_training_table,
			input_length/k,
			i * (input_length/k));
		kCrossTestViews := kCrossTestViews || tmp_string;
		tmp_string := sl_get_unique_tblname() || 'ml_cross_training_' || i;
		EXECUTE format('CREATE OR REPLACE TEMP VIEW %s (%s, %s) AS SELECT %s, %s from %s EXCEPT SELECT * FROM %s',
			tmp_string,
			(SELECT string_agg(format('%s',quote_ident(final_ml_features[j])), ',')
			FROM generate_subscripts(final_ml_features, 1) AS j),
			target_column_name,
			(SELECT string_agg(format('%s',quote_ident(final_ml_features[j])), ',')
			FROM generate_subscripts(final_ml_features, 1) AS j),
			target_column_name,
			ml_training_table,
			kCrossTestViews[i+1]);
		 kCrossTrainingViews := kCrossTrainingViews || tmp_string;
	end loop;

	-- TODO handle ml methods


	return format('{"training" : "%s", "test" : "%s"}',
		ml_training_table, ml_target_table);

END;
$$ language plpgsql;
-----------------------------------------------------------------------------------------------