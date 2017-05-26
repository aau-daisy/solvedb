-- Install the solver method
CREATE OR REPLACE FUNCTION forecasting_test_solve_default(arg sl_solver_arg) RETURNS setof record AS $$
DECLARE
     foundAttVid	boolean = false;-- Was the "vid" attribute found?
     foundAttIs_int	boolean = false;-- Was the "is_int" attribute found?
     foundAttObj_value	boolean = false;-- Was the "obj_value" attribute found?
     foundAttMin_value	boolean = false;-- Was the "min_value" attribute found?
     foundAttMax_value	boolean = false;-- Was the "max_value" attribute found?
     foundAttValue	boolean = false;-- Was the "value" attribute found?
     foundRelCtrM       boolean = false;-- Was the constraint relation specified?
     foundRelCtrD       boolean = false;-- Was the constraint relation 2 specified?
     foundTargetValue   boolean = false;-- Was the prediction target specified?
     i		        int;		-- Index   
     input_clmns  record;
     input_feature_col_names  name[] :=  '{}';
     input_feature_col_types  text[] :=  '{}';
     input_time_col_names  name[] :=  '{}';
     input_time_col_types  text[] :=  '{}';
     -- currently handles a single target column
     target_column_name name;
     target_column_type text;
     test_joining_columns name[] := '{}';
     test_not_joining_columns name[] := '{}';
     t       sl_attribute_desc;
     v_o     sl_viewsql_out;
     v_d     sl_viewsql_dst;     
     tmp_forecasting_table_name text;
  BEGIN       
     -- Check if this is a propriate variable table
     --foundAttVid       = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'known'::sl_attribute_kind AND att_name = 'vid'), false);
     --foundAttIs_int    = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'known'::sl_attribute_kind AND att_name = 'is_int'), false);
     --foundAttObj_value = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'known'::sl_attribute_kind AND att_name = 'obj_value'), false);
     --foundAttMin_value = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'known'::sl_attribute_kind AND att_name = 'min_value'), false);
     --foundAttMax_value = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'known'::sl_attribute_kind AND att_name = 'max_value'), false);
     --foundAttValue     = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'unknown'::sl_attribute_kind AND att_name = 'value'), false);
       foundTargetValue  = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_name = sl_param_get_as_text(arg, 'target')), false); 

     -- Check if the arguments are correct
	--TODO

        PERFORM sl_create_view(sl_build_out(arg), 'arima_input');
	-- find the columns in the input schema: features, time feature, prediction target
	for input_clmns in select att_name, att_type from  sl_get_attributes_from_sql('select * from arima_input limit 1')
	loop
		if input_clmns.att_name = sl_param_get_as_text(arg, 'target') then
			target_column_name = input_clmns.att_name;
			target_column_type  = input_clmns.att_type;
		else
			if coalesce((select input_clmns.att_type = any (enum_range(null::sl_supported_time_types)::text[])), false) then
				input_time_col_names[coalesce(array_length(input_time_col_names, 1), 0)] := input_clmns.att_name;
				input_time_col_types[coalesce(array_length(input_time_col_types, 1), 0)] := input_clmns.att_type;
			else
				input_feature_col_names[coalesce(array_length(input_feature_col_names, 1), 0)] := input_clmns.att_name;
				input_feature_col_types[coalesce(array_length(input_feature_col_types, 1), 0)] := input_clmns.att_type;
			end if;
		end if;		
	 end loop;

	-- check if multiple time columns are present, for which method 2 has to be used (TODO)
	if array_length(input_time_col_names, 1) != 1 then
		raise exception 'Multiple time variables in input schema. Specify time feature with "time_column := name_of_time_column"';
	end if;
	
	-- create temporary view input_schema containing the time column and the target value, and the rows to predcit
 	execute 'create or replace view input_schema as select ' || input_time_col_names[0] || ', ' || target_column_name || ' from arima_input';
	tmp_forecasting_table_name := create_temporary_forecasting_table(target_column_name, input_time_col_names[0], sl_param_get_as_text(arg, 'start_time'), sl_param_get_as_text(arg, 'end_time'), 'input_schema');
-- 	fill rows with prediction, and join with original table
 	perform arima_prediction(target_column_name, input_time_col_names[0], 'input_schema', tmp_forecasting_table_name, sl_param_get_as_text(arg, 'start_time'), sl_param_get_as_text(arg, 'end_time'));

	-- create array of columns to join (in the default case only time feature and target feature)
	test_joining_columns := input_time_col_names || target_column_name;
	for input_clmns in select att_name from  sl_get_attributes(arg) LOOP
		IF (SELECT input_clmns.att_name = ANY (test_joining_columns)) THEN
			null;
		else
			test_not_joining_columns := test_not_joining_columns || input_clmns.att_name;
		END IF;
	end loop;

	
        RAISE NOTICE 'Sudoku solver completes.';
        -- TODO: return the data in tmp_forecasting_table_name
	-- return query execute sl_return(arg, test_table);
         RETURN QUERY EXECUTE sl_return(arg, sl_build_union_right_join_debug(arg, test_not_joining_columns, test_joining_columns, tmp_forecasting_table_name));
        -- raise notice '---- %', input_clmns;
        perform sl_drop_view_cascade('arima_input');
     
  END;
$$ LANGUAGE plpgsql VOLATILE STRICT;

solveselect * in (select * from Test) 
using arima_solver(target:='watt',start_time:='2015-11-11 23:00:00', end_time:='2015-11-13 23:00:00');
