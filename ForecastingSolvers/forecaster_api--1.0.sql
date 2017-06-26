------ Table TO STORE PREDICTIVE MODELS
drop type if exists sl_pr_solver_type cascade;
create type sl_pr_solver_type as enum(
			'ml',
			'ts',
			'custom'
);

drop table if exists sl_pr_parameter cascade;
create table sl_pr_parameter (
	pid		serial primary key,
	name		name not null unique,
	type		text,
	description	text,
	value_default	numeric,
	value_min	numeric,
	value_max	numeric
);





-- Type to contain the information of the predictive solver parameter
DROP TYPE  IF EXISTS sl_method_parameter_type cascade;
CREATE TYPE sl_method_parameter_type AS (
	name		text,
	type		text,
	value_default	numeric,
	value_min	numeric,
	value_max	numeric
);

drop table if exists sl_pr_method CASCADE;
CREATE TABLE sl_pr_method
(
	mid		serial PRIMARY KEY,		-- the id of the method
	name		name not null unique,		-- name
	version		real,
	funct_name	text,
	description 	text,				-- description of the model
	type		sl_pr_solver_type		-- type of model: ML, or TS
);

drop table if exists sl_pr_method_param cascade;
create table sl_pr_method_param (
	mid int,
	pid int,
	foreign key (mid) references sl_pr_method(mid),
	foreign key (pid) references sl_pr_parameter(pid)
);

drop table if exists sl_pr_solver_method cascade;
create table sl_pr_solver_method
(

	sid	int,
	mid 	int,
	foreign key (sid) references sl_solver(sid),
	foreign key (mid) references sl_pr_method(mid)
);







-- *********UTILITY FUNCTIONS FOR FORECASTING SOLVERS *********


-- This function dynamically generates a solve query for predictive solvers (used when calling a specific predictive solver
-- to generate a call to the predictive advisor with the correct predictive method

-- Dynamically generates a solve select query
CREATE OR REPLACE FUNCTION sl_pr_generate_predictive_solve_query(query sl_solve_query, par_val_pairs text[][] DEFAULT NULL::text[][])
 RETURNS text AS $$
  SELECT format('SOLVESELECT %s IN (%s) USING %s(%s)', 
	    ((query.problem).cols_unknown)[1], 						 -- target column
	    (query.problem).input_sql, 						         -- Input relation
	    format('%s%s', query.solver_name, CASE WHEN query.method_name = '' THEN ''   -- Solver/method clause
			           ELSE format('.%s', query.method_name)
			      END), 				     
	    (SELECT string_agg(CASE WHEN (par_val_pairs[i][2] IS NULL) OR (par_val_pairs[i][2] = '') 
			THEN par_val_pairs[i][1]
			ELSE format('%s:=%L', par_val_pairs[i][1], par_val_pairs[i][2]) END, ',') 
	     FROM generate_subscripts(par_val_pairs, 1) AS i)	     -- Solver parameter clause
	)		
$$ LANGUAGE sql IMMUTABLE;












-- This function rewrites the optimization problem of a TIME SERIES 
--forecasting model into a SOLVESELECT,
-- using the swarm solver to find the solution
DROP FUNCTION IF EXISTS sl_convert_ts_fit_to_solveselect(text, name, text, numeric[], text, sl_method_parameter_type[]);
CREATE FUNCTION sl_convert_ts_fit_to_solveselect(time_feature text, target name, training_data text, 
						test_values numeric[], method text, 
						parameters sl_method_parameter_type[])
RETURNS text AS $$
declare
	tmp_record record;
	tmp_string	text;
	n_iterations	int:=100;
begin
	execute format('SELECT * FROM (SOLVESELECT %s IN (SELECT %s) as sl_fts 
			MINIMIZE (SELECT sl_evaluation_rmse(%L, %s(%s, time_column_name := %L, target_column_name := %L, 
			training_data := %L, number_of_predictions := %s))::int) 
			SUBJECTTO (SELECT %s FROM sl_fts) USING swarmops.pso(n:=%s)) AS sl_tmp_tmp',
		(SELECT string_agg(format('%s',(parameters[j]).name), ',')
			FROM generate_subscripts(parameters, 1) AS j),
		(SELECT string_agg(format('NULL::%s AS %s',
				(parameters[j]).type, 
				(parameters[j]).name), ',')
			FROM generate_subscripts(parameters, 1) AS j),
		test_values,
		method,
		(SELECT string_agg(format('%s := (SELECT %s from sl_fts)',
			(parameters[j]).name,
			(parameters[j]).name), ',')
			FROM generate_subscripts(parameters, 1) AS j),
		time_feature,
		target,
		('SELECT * FROM ' || training_data),
		array_length(test_values,1),
		(SELECT string_agg(format(' %s <= %s <= %s',
			(parameters[j]).value_min,
			(parameters[j]).name,
			(parameters[j]).value_max), ',')
			FROM generate_subscripts(parameters, 1) AS j),
			n_iterations) into tmp_record;
	tmp_string := replace(tmp_record::text, '(','');
	tmp_string := replace(tmp_string, ')', '');
	return tmp_string;
end;
$$ language plpgsql;




-- Converts a data string from an unknown date format to date of format YYYY-MM-DD HH:MM:SS
drop function if exists convert_date_string(text);
CREATE OR REPLACE FUNCTION convert_date_string(date_string text) RETURNS text
AS $$
	import dateutil.parser as parser
	try:
		return parser.parse(date_string)s
	except Exception:
		return None
$$ LANGUAGE plpythonu;


create or replace function sl_extract_column_to_array(query text, col name)
returns numeric[] as $$

	result = []
	rv = plpy.execute(query);
	for data_row in rv:
		result.append(data_row[str(col)])
	return result
$$ language plpythonu;


CREATE OR REPLACE FUNCTION sl_extract_parameters(parameters text[], query text) 
returns  text[] as $$
	resulting_parameters_lines = []
	rv = plpy.execute(query)
	for data_row in rv:
		line = ""
		for parameter in parameters:
			line += str(parameter) + " := " + str(data_row[str(parameter)]) + ", "
		resulting_parameters_lines.append(line[:-2])
	return resulting_parameters_lines

$$ language plpythonu;


drop function if exists separate_input_relation_on_time_range(name, name, text, int, text, text, text);
CREATE FUNCTION separate_input_relation_on_time_range(target name, id name, time_column_name text, frequency int, 
			table_name text, starting_time text, ending_time text) RETURNS text
AS $$

	import dateutil.parser as parser
	from datetime import timedelta

	starting_datetime = parser.parse(starting_time)
	ending_datetime = parser.parse(ending_time)
	# if the user has not specified a frequency find most probable interval between samples in time series
	if frequency < 0:
		query = "select " + time_column_name + " from " + table_name + " order by " + time_column_name + " desc"
		rv = plpy.execute(query)
		time_intervals = {}
		for i in range(len(rv)-1):
			time_object_a = parser.parse(rv[i][time_column_name])
			time_object_b = parser.parse(rv[i+1][time_column_name])
			time_intervals[(time_object_a - time_object_b).total_seconds()] = time_intervals.get((time_object_a - time_object_b).total_seconds(),0) + 1
		probability = 0
		for key, value in time_intervals.iteritems():
			if value > probability:
				probability = value
				most_probable_frequency = key
	else:
		most_probable_frequency = frequency

	number_of_rows_to_fill = int((ending_datetime - starting_datetime).total_seconds() / float(most_probable_frequency))

	if number_of_rows_to_fill < 1:
		plpy.exception("Wrong time interval for prediction");
	rv = plpy.execute("select count(*) as the_count from (select " + time_column_name + " from "  + table_name + " where " + time_column_name + " >= \'" + str(starting_datetime) + "\' and " + time_column_name + " <= \'" + str(ending_datetime) + "\' order by " + time_column_name + " asc) as b")
	number_of_rows_to_fill_already_in_table = int(rv[0]['the_count'])
	
	
	# create temporary table with rows to fill
	rv = plpy.execute("select max(" + id + ") as id from " + table_name)
	last_existing_id = rv[0]['id']
	
	query = "select " + id + ", " +  time_column_name + ", " + target + " from " + table_name + " where " + time_column_name + " >= \'" + str(starting_datetime) + "\' and " + time_column_name + " <= \'" + str(ending_datetime) + "\' order by " + time_column_name + " asc"
	rv = plpy.execute(query)
	times_already_in = []

	for line in rv:
		times_already_in.append(parser.parse(line[time_column_name]))

	lines_for_view = []
	last_existing_line = starting_datetime


	for i in range(number_of_rows_to_fill):
		curr_time = (starting_datetime + timedelta(seconds=i * most_probable_frequency))
		last_existing_id += i + 1
		lines_for_view.append({'id': (last_existing_id),'time':str(curr_time), 'value':'null', 'fill':True})
		if curr_time in times_already_in:
			times_already_in.remove(curr_time)
	
	# add the already existing rows
	for line in times_already_in:
		last_existing_id += i + 1
		lines_for_view.append({'id': (last_existing_id),'time':str(line), 'value':'null', 'fill':True})

	# write the table on the db
	tmp_table_name = str(plpy.execute('select * from sl_get_unique_tblname()')[0]['sl_get_unique_tblname']) + "_ts_target_view"

	## temporary table to store the rows, not sorted
	plpy.execute('DROP TABLE IF EXISTS sl_temporary_table_for_splitting_data')
	query = "CREATE TEMP TABLE sl_temporary_table_for_splitting_data(" + id + " int, " + time_column_name  + " TIMESTAMP, " + target +   " NUMERIC, fill BOOLEAN)"
	plpy.execute(query)
	query = "INSERT INTO sl_temporary_table_for_splitting_data VALUES "
	for data in lines_for_view:
		query += "({id},'{time}', {value}, {fill}),\n".format(**data)
	plpy.execute(query[:-2])

	## create the real table, with sorted rows
	query = "CREATE TEMP TABLE " + tmp_table_name + " AS SELECT * FROM sl_temporary_table_for_splitting_data ORDER BY " + time_column_name + " ASC"
	plpy.execute(query)


	if plpy.execute('SELECT COUNT(*) AS the_count FROM ' + tmp_table_name)[0]['the_count'] == 0:
		return None
	else:
		return tmp_table_name;

$$ LANGUAGE plpythonu;





drop function if exists separate_input_relation_on_empty_rows(text, text[], text);
CREATE OR REPLACE FUNCTION separate_input_relation_on_empty_rows(target_column_name text, 
		feature_column_names text[], table_name text)
  RETURNS name
AS $$
DECLARE
	target_table_name text := sl_get_unique_tblname() || '_ml_target_view';
	query	text := 'SELECT COUNT(*) FROM ';
	c 	int;
BEGIN
	EXECUTE format('CREATE TEMP TABLE %s (%s, %s) AS SELECT %s, %s FROM %s WHERE %s is null',
			target_table_name,
			(SELECT string_agg(format('%s',quote_ident(feature_column_names[j])), ',')
				FROM generate_subscripts(feature_column_names, 1) AS j),
			target_column_name,
			(SELECT string_agg(format('%s',quote_ident(feature_column_names[j])), ',')
				FROM generate_subscripts(feature_column_names, 1) AS j),
			target_column_name,
			table_name,
			target_column_name);
	query := query || target_table_name;     
	execute query into c ;
	-- check that the table contains data to fill
	IF c = 0 THEN
		RETURN null;
	ELSE
		RETURN target_table_name;
	END IF;
END

$$ LANGUAGE plpgsql STRICT;



-- Returns null if no rows are present in the resulting table
-- id is the id of the table in sql on which to remove the rows from
--
DROP FUNCTION IF EXISTS sl_build_view_except_from_sql(text, text, name, text[], text);
CREATE OR REPLACE FUNCTION sl_build_view_except_from_sql(input_table text, sql text, id name, 
		columns_to_project text[], column_for_order_exclude text)
   RETURNS NAME AS $$
	DECLARE 
		table_name 	name;
		query	text := 'SELECT COUNT(*) FROM ';
		c 	int;
		i	text;
	BEGIN
		table_name := sl_get_unique_tblname();
		query := format('CREATE VIEW %s(%s) AS SELECT %s from %s except 
				(select %s from %s where %s in (select %s from %s)) order by %s' ,
		table_name,
		(SELECT string_agg(format('%s',quote_ident(columns_to_project[j])), ',')
				FROM generate_subscripts(columns_to_project, 1) AS j),
		(SELECT string_agg(format('%s',quote_ident(columns_to_project[j])), ',')
				FROM generate_subscripts(columns_to_project, 1) AS j),
		input_table,
		(SELECT string_agg(format('%s',quote_ident(columns_to_project[j])), ',')
				FROM generate_subscripts(columns_to_project, 1) AS j),
		input_table,
		column_for_order_exclude,
		column_for_order_exclude,
		sql,
		column_for_order_exclude);
		EXECUTE query;
	query := 'SELECT COUNT(*) FROM ' || table_name;     
	execute query into c ;
	-- check that the table contains data to fill
	IF c = 0 THEN
		RETURN null;
	ELSE
		RETURN table_name;
	END IF;
END;
$$ LANGUAGE plpgsql STRICT;

-- create the temporary table to store the intermidiate results of the prediction models
DROP FUNCTION IF EXISTS sl_build_pr_results_table();
CREATE OR REPLACE FUNCTION sl_build_pr_results_table() returns text
as $$
	declare 
		table_name text := sl_get_unique_tblname() || '_pr_results';
	begin
		EXECUTE format('CREATE TEMP TABLE %s (sid SERIAL PRIMARY KEY,
			method text, parameters text, result numeric)', table_name);
		RETURN table_name; 
	END;
$$ language plpgsql;


-----FUNCTIONS FOR GLOBAL VARIABLES

CREATE OR REPLACE FUNCTION sl_set_print_model_summary_on() returns void as $$
	GD["print_model_summary"] = True
$$ language plpythonu;

CREATE OR REPLACE FUNCTION sl_set_print_model_summary_off() returns void as $$
	GD["print_model_summary"] = False
$$ language plpythonu;

CREATE OR REPLACE FUNCTION sl_check_print_model_summary() returns boolean as $$
	return GD["print_model_summary"]
$$ language plpythonu;


---------EVALUATION MODELS

-- RMSE of two columns of values
DROP FUNCTION IF EXISTS sl_evaluation_rmse(numeric[], numeric[]);
CREATE OR REPLACE FUNCTION sl_evaluation_rmse(x numeric[],y numeric[]) 
RETURNS NUMERIC AS $$
	import sys


	from sklearn.metrics import mean_squared_error
	from math import sqrt
	if len(x) != len(y):
		plpy.warning("RMSE cannot be calculated on arrays of differnt size")
		return None

	try:
		rmse = sqrt(mean_squared_error(x, y))
	except Exception as ex:
		return sys.float_info.max
	return rmse

$$ LANGUAGE plpythonu;
--------------------------------------------------------------------------------


