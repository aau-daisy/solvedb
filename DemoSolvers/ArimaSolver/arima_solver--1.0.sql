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

       

     -- Check if the arguments and table format are correct
     --foundTargetValue  = 
     --COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_name = sl_param_get_as_text(arg, 'target')), false); 
	--TODO

        PERFORM sl_create_view(sl_build_out(arg), 'input_relation');
        PERFORM f_selector(arg, 'select * from input_relation limit 1');
        return query execute sl_return(arg, sl_build_out(arg), 'input_relation');
	
	
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
--         -- raise notice '---- %', input_clmns;
--         perform sl_drop_view_cascade('input_relation');
     
  END;
$$ LANGUAGE plpgsql VOLATILE STRICT;

solveselect * in (select * from Test) 
using arima_solver(target:='watt',start_time:='2015-11-11 23:00:00', end_time:='2015-11-13 23:00:00');
