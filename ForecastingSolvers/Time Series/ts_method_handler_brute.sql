-- function that handles the TS method, brute forcing the parameters
-- VS SolveDB inner parameter solving functionalities
DROP FUNCTION if exists ts_method_handler_brute(text,text,name,text,numeric[],text,sl_model_parameter_type[]);
CREATE or replace FUNCTION ts_method_handler_brute(results_table text, time_column_name text, 
	target_column_name name, training_data text, test_values numeric[],	
	method_name text, method_parameters sl_model_parameter_type[])
returns void as $$

DECLARE
	lowest_RMSE numeric := 99999999999;
	parameter_string	text := '';
	best_parameter_line	text;
	parameter 		sl_model_parameter_type;
	parameter_table 	name[] := '{}';
	parameter_columns	name[] := '{}';
	tmp_name		name;
	tmp_numeric		numeric;
	tmp_record		record;
	query			text := '';	
	i 			integer;
	j			integer;
	tmp_string		text;
	parameter_settings_lines	text[];
	predictions		numeric[];
	rmse 			numeric;



BEGIN
	-- setup the parameter combinations
	for i in 1..array_length(method_parameters, 1) LOOP
		tmp_name := sl_get_unique_tblname();
		EXECUTE format('CREATE TEMP TABLE %s (%s numeric)',
				tmp_name,
				(method_parameters[i]).name);
		parameter_table := parameter_table || tmp_name::name;
		parameter_columns := parameter_columns || (method_parameters[i]).name::name;
		for j in 1..array_length((method_parameters[i]).accepted_values, 1) LOOP
			EXECUTE format('INSERT INTO %s VALUES (%s)',
				tmp_name,
				((method_parameters[i]).accepted_values)[j]);
		END LOOP;
	END LOOP;
	
	query := format('SELECT * FROM %s', 
		(SELECT string_agg(format('%s',parameter_table[k]::text), ' NATURAL JOIN ')
		FROM generate_subscripts(parameter_table, 1) AS k));
	parameter_settings_lines := sl_extract_parameters(parameter_columns, query);

	raise notice 'parameterlines -- %', parameter_settings_lines;

	for i in 1..array_length(parameter_settings_lines,1) loop
		query := format('SELECT %s(%s, time_column_name := %L, target_column_name := %L, 
			training_data := %L, number_of_predictions := %s)',
			method_name,
			parameter_settings_lines[i],
			time_column_name,
			 target_column_name,
			  'SELECT * FROM ' || training_data,
			   array_length(test_values, 1));
		EXECUTE query into predictions;
		raise notice 'predictions: %', predictions;
		SELECT sl_evaluation_rmse(test_values, predictions) into rmse;
		-- optimize the parameters
		if rmse is not null and rmse < lowest_RMSE then
			lowest_RMSE = rmse;
			best_parameter_line = parameter_settings_lines[i];
		end if;
	end loop;


	if best_parameter_line is null THEN
		return;
	end if;

	raise notice 'bst_parameter_line: %', best_parameter_line;
	-- save the best result of this model in the result table
	EXECUTE format('INSERT INTO %s(method, parameters, result) VALUES (%L, %L, %s)',
			results_table,
			method_name,
			best_parameter_line,
			lowest_RMSE);		

END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------------------------------------