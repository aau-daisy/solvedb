------ Table TO STORE PREDICTIVE MODELS
drop table if exists sl_pr_models CASCADE;
CREATE TABLE sl_pr_models
(
	sid		serial PRIMARY KEY,		-- the id of the predictive model
	model		name not null unique,		-- name
	predict		varchar(255) UNIQUE not null,		-- name of the predict method
	description 	text				-- description of the model
);


drop table if exists sl_pr_model_parameters CASCADE;
create table sl_pr_model_parameters 
(
	sid 		serial primary key,
	model_id	int,
	parameter	text not null,
	type		text not null,
	value		numeric,
	low_range	numeric,
	high_range	numeric,
	foreign key(model_id) references sl_pr_models(sid)
);

drop table if exists sl_pr_model_instances;
create table sl_pr_model_instances 
(
	sid 		serial primary key,
	model_id	int,
	parameter_id 	int,
	value		numeric,
	foreign key(model_id) references sl_pr_models(sid),
	foreign key(parameter_id) references sl_pr_model_parameters(sid)
);


insert into sl_pr_models(model, predict) values
('arima_statsmodels', 'arima_predict')

insert into sl_pr_model_parameters(model_id, parameter_id, type, low_range, high_range) values 
(1, 'time_window', 'integer', 5, 15),
(1, 'p', 'integer', 0, 3),
(1, 'd', 'integer', 0, 2),
(1, 'q', 'integer', 0, 3);



------------------------------- TEMPORARY TYPES FOR FORECASTING METHODS (MOVE TO TABLE IN INSTALLATION
-- This defines alternative attribute kinds in a relation with unknown variables
DROP TYPE IF EXISTS sl_supported_ml_forecasting_methods CASCADE;
CREATE TYPE sl_supported_ml_forecasting_methods AS ENUM (); 	


DROP TYPE IF EXISTS sl_supported_ts_forecasting_methods CASCADE;
CREATE TYPE sl_supported_ts_forecasting_methods AS ENUM ('arima'); 



-- *********UTILITY FUNCTIONS FOR FORECASTING SOLVERS *********--
-- Converts a data string from an unknown date format to date of format YYYY-MM-DD HH:MM:SS
drop function if exists convert_date_string(text);
CREATE OR REPLACE FUNCTION convert_date_string(date_string text) RETURNS text
AS $$
	import dateutil.parser as parser
	try:
		return parser.parse(date_string)
	except Exception:
		return None
$$ LANGUAGE plpythonu;


drop function if exists separate_input_relation_on_time_range(name, name, text, int, text, text, text);
CREATE FUNCTION separate_input_relation_on_time_range(target name, id name, time_column_name text, frequency int, table_name text, starting_time text, ending_time text) RETURNS text
AS $$

	from datetime import datetime
	from datetime import timedelta

	starting_datetime = datetime.strptime(starting_time, '%Y-%m-%d %H:%M:%S')
	ending_datetime = datetime.strptime(ending_time, '%Y-%m-%d %H:%M:%S')
	# if the user has not specified a frequency find most probable interval between samples in time series
	if frequency < 0:
		query = "select " + time_column_name + " from " + table_name + " order by " + time_column_name + " desc"
		rv = plpy.execute(query)
		time_intervals = {}
		for i in range(len(rv)-1):
			time_object_a = datetime.strptime(rv[i][time_column_name], '%Y-%m-%d %H:%M:%S')
			time_object_b = datetime.strptime(rv[i+1][time_column_name], '%Y-%m-%d %H:%M:%S')
			time_intervals[(time_object_a - time_object_b).total_seconds()] = time_intervals.get((time_object_a - time_object_b).total_seconds(),0) + 1
		probability = 0
		for key, value in time_intervals.iteritems():
			if value > probability:
				probability = value
				most_probable_frequency = key
	else:
		most_probable_frequency = frequency

	# create temporary table with rows to fill
	query = "select " + id + ", " +  time_column_name + ", " + target + " from " + table_name + " where " + time_column_name + " >= \'" + str(starting_datetime) + "\' and " + time_column_name + " <= \'" + str(ending_datetime) + "\'"
	rv = plpy.execute(query)
	lines_for_view = []
	last_existing_line = starting_datetime
	print "-----------------------" + query
	for line in rv:
		last_existing_line = datetime.strptime(line[time_column_name], '%Y-%m-%d %H:%M:%S')
		last_existing_id = line[id];
		# if the value column is empty, mark as to_be_filled
		if not line[target]:
			lines_for_view.append({'id':line[id], 'time':line[time_column_name], 'value':'null','fill':True})
		else:
			lines_for_view.append({'id':line[id], 'time':line[time_column_name], 'value':line[target], 'fill':False})


	number_of_rows_to_fill = int((ending_datetime - last_existing_line).total_seconds() / float(most_probable_frequency))
	for i in range(1, number_of_rows_to_fill+1):
		lines_for_view.append({'id': (last_existing_id + i),'time':str(last_existing_line + timedelta(seconds=i * 3600)), 'value':'null', 'fill':True})

	# write the table on the db
	tmp_table_name = str(plpy.execute('select * from sl_get_unique_tblname()')[0]['sl_get_unique_tblname']) + "_ts_target_view"
	query = "CREATE TEMP TABLE " + tmp_table_name + " (" + id + " int, " + time_column_name  + " TIMESTAMP, " + target +   " NUMERIC, fill BOOLEAN)"
	plpy.execute(query)

	query = "INSERT INTO " + tmp_table_name + " VALUES "
	for data in lines_for_view:
		query += "({id},'{time}', {value}, {fill}),\n".format(**data)
	plpy.execute(query[:-2])

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
DROP FUNCTION IF EXISTS sl_build_view_except_from_sql(text, text, name, text[]);
CREATE OR REPLACE FUNCTION sl_build_view_except_from_sql(input_table text, sql text, id name, columns_to_project text[])
   RETURNS NAME AS $$
	DECLARE 
		table_name 	name;
		query	text := 'SELECT COUNT(*) FROM ';
		c 	int;
		i	text;
	BEGIN
		table_name := sl_get_unique_tblname();
		query := format('CREATE VIEW %s(%s) AS SELECT %s from %s except (select %s from %s where %s in (select %s from %s))',
		table_name,
		(SELECT string_agg(format('%s',quote_ident(columns_to_project[j])), ',')
				FROM generate_subscripts(columns_to_project, 1) AS j),
		(SELECT string_agg(format('%s',quote_ident(columns_to_project[j])), ',')
				FROM generate_subscripts(columns_to_project, 1) AS j),
		input_table,
		(SELECT string_agg(format('%s',quote_ident(columns_to_project[j])), ',')
				FROM generate_subscripts(columns_to_project, 1) AS j),
		input_table,
		id,
		id,
		sql);
		raise notice '---- %', query;
		EXECUTE query;
	query := 'SELECT COUNT(*) FROM ' || table_name;     
	execute query into c ;
	-- check that the table contains data to fill
	raise notice 'the number of rows in exclude is %', c;
	IF c = 0 THEN
		RETURN null;
	ELSE
		RETURN table_name;
	END IF;
END;
$$ LANGUAGE plpgsql STRICT;
---------EVALUATION MODELS


-- RMSE of two columns of values
DROP FUNCTION IF EXISTS sl_evaluation_rmse(numeric[], numeric[]);
CREATE OR REPLACE FUNCTION sl_evaluation_rmse(x numeric[],y numeric[]) 
RETURNS NUMERIC AS $$

	from sklearn.metrics import mean_squared_error
	from math import sqrt
	if len(x) != len(y):
		print "RMSE cannot be calculated on arrays of differnt size"
		return null

	try:
		rmse = sqrt(mean_squared_error(x, y))
	except Exception as ex:
		return null
		
	return rmse

$$ LANGUAGE plpythonu;

--------------------------------------------------------------------------------


select count(*) from (SELECT id,watt,sl_col_111 from sl_tbl_1931_pr_input_relation 
except ())



select id,watt,sl_col_111 from sl_tbl_1931_pr_input_relation 
where sl_col_111 in (select sl_col_111 from sl_tbl_1935_ml_target_view)