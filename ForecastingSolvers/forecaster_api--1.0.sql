------ Table TO STORE PREDICTIVE MODELS
drop table if exists sl_pr_models;
CREATE TABLE sl_pr_models
(
	sid		serial PRIMARY KEY,		-- the id of the predictive model
	name		name not null unique,		-- name
	fit 		varchar(255) not null,		-- name of the fit method
	predict		varchar(255) not null,		-- name of the predict method
	description 	text				-- description of the model
);


drop table if exists sl_pr_model_instances;
create table sl_pr_model_instances 
(
	sid 		serial primary key,
	model_id	int,
	name		text not null,
	type		text not null,
	value		numeric,
	low_range	numeric,
	high_range	numeric,
	foreign key(model_id) references sl_pr_models(sid)
);


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


drop function if exists separate_input_relation_on_time_range(name, text, int, text, text, text);
CREATE FUNCTION separate_input_relation_on_time_range(target name, time_column_name text, frequency int, table_name text, starting_time text, ending_time text) RETURNS text
AS $$

	from datetime import datetime
	from datetime import timedelta

	print time_column_name + "-------------------------------------------------"
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
			print (time_object_a - time_object_b).total_seconds()
			time_intervals[(time_object_a - time_object_b).total_seconds()] = time_intervals.get((time_object_a - time_object_b).total_seconds(),0) + 1
		probability = 0
		for key, value in time_intervals.iteritems():
			if value > probability:
				probability = value
				most_probable_frequency = key
	else:
		most_probable_frequency = frequency

	# create temporary table with rows to fill
	query = "select " + time_column_name + ", " + target + " from " + table_name + " where " + time_column_name + " > \'" + str(starting_datetime) + "\' and " + time_column_name + " < \'" + str(ending_datetime) + "\'"
	rv = plpy.execute(query)
	lines_for_view = []
	last_existing_line = starting_datetime
	for line in rv:
		last_existing_line = datetime.strptime(line[time_column_name], '%Y-%m-%d %H:%M:%S')
		# if the value column is empty, mark as to_be_filled
		if not line[target_column_name]:
			lines_for_view.append({'time':line[time_column_name], 'value':'null','fill':True})
		else:
			lines_for_view.append({'time':line[time_column_name], 'value':line[target], 'fill':False})


	number_of_rows_to_fill = int((ending_datetime - last_existing_line).total_seconds() / float(most_probable_frequency))
	for i in range(1, number_of_rows_to_fill+1):
		lines_for_view.append({'time':str(last_existing_line + timedelta(seconds=i * 3600)), 'value':'null', 'fill':True})

	# write the table on the db
	tmp_table_name = str(plpy.execute('select * from sl_get_unique_tblname()')[0]['sl_get_unique_tblname']) + "_ts_target_view"
	plpy.execute(query)
	query = "CREATE TEMP TABLE " + tmp_table_name + " (" + time_column_name  + " TIMESTAMP, " + target +   " NUMERIC, fill BOOLEAN)"
	plpy.execute(query)

	query = "INSERT INTO " + tmp_table_name + " VALUES "
	for data in lines_for_view:
		query += "('{time}', {value}, {fill}),\n".format(**data)
	print query
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
DROP FUNCTION IF EXISTS sl_build_view_except_from_sql(text);
CREATE OR REPLACE FUNCTION sl_build_view_except_from_sql(sql text)   RETURNS NAME
AS $$
	DECLARE 
		table_name 	name;
		query	text := 'SELECT COUNT(*) FROM ';
		c 	int;
	BEGIN
		table_name := sl_get_unique_tblname();
	EXECUTE format('CREATE VIEW %s AS %s',
		table_name,
		sql);
	query := query || table_name;     
	execute query into c ;
	-- check that the table contains data to fill
	IF c = 0 THEN
		RETURN null;
	ELSE
		RETURN table_name;
	END IF;
END;
$$ LANGUAGE plpgsql STRICT;

------------------------------------------------------------------------------------------------------------------------------------------