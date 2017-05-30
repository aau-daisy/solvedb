
-- This function selects the most relevant features for prediction from the dataset, that account to [80%] of the importance (Default percentage)
-- It also removes irrelevant features
-- For time series forecasting: if a time_column is not given, select a random time column (TODO: update this function to analyse the dataset for the best time column)
CREATE OR REPLACE FUNCTION f_selector(arg sl_solver_arg, target_column_name name, source text) returns void AS $$
DECLARE
	input_clmn record;
	input_feature_col_names  name[] :=  '{}';
	input_feature_col_types  text[] :=  '{}';
	input_time_col_names  name[] :=  '{}';
	input_time_col_types  text[] :=  '{}';
	-- currently handles a single target column
	target_column_type text;
	test text;
	
BEGIN
	raise notice 'this is the f_selector method';
	-- find the columns in the input schema: features, time feature, prediction target
	for input_clmn in select att_name, att_type from  sl_get_attributes_from_sql(source)
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

	-- check if multiple time columns are present, for which method 2 has to be used (TODO)
	if array_length(input_time_col_names, 1) != 1 then
		raise notice 'Multiple time variables in input schema. Time column %d will be used. To select another time column, add argument "time_column := name_of_time_column" to method', input_time_col_names[0];
	end if;

	raise notice 'start the feature selection';
	-- find the feature set
	input_feature_col_names := feature_selection(input_feature_col_names, target_column_name, 'input_relation');
	raise notice 'back from python';
END;

$$ LANGUAGE plpgsql volatile strict;
