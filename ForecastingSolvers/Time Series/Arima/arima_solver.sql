-- arima solver default method
drop function if exists arima_solver(arg sl_solver_arg);
CREATE OR REPLACE FUNCTION arima_solver(arg sl_solver_arg ) RETURNS SETOF record as $$

DECLARE
	-- todo make this dynamic, check solver id in arg?
	method 			name := 'arima_predict'::name;
	target_column_name 	name := ((arg).problem).cols_unknown[1];
	attFeatures       	text := sl_param_get_as_text(arg, 'features');
	attStartTime       	text := sl_param_get_as_text(arg, 'start_time');
	attEndTime       	text := sl_param_get_as_text(arg, 'end_time');
	attFrequency       	text := sl_param_get_as_text(arg, 'frequency');
	par_val_pairs		text[][];
	i			int;
	query			sl_solve_query;

BEGIN

	-- get arg information
	query := ((arg).problem, 'predictive_solver'::name, '');

	for i in 1..array_length((arg).params, 1) loop
		par_val_pairs := par_val_pairs || array[[((arg).params)[i].param::text, ((arg).params)[i].value_t::text]];
	end loop;
	par_val_pairs := par_val_pairs || array[['methods'::text, method::text]];

-- CALL THE PREDICTIVE ADVISOR SOLVER WITH METHODS:= 'arima_predict'
RETURN QUERY EXECUTE sl_pr_generate_predictive_solve_query(query, par_val_pairs);
END;
$$ LANGUAGE plpgsql strict;
------------------------------------------------------------------------------------------


