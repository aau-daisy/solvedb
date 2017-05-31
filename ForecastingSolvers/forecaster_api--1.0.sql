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

-- CREATE FUNCTION separate_input_relation_on_time_range(target_column_name text,
-- 	final_ts_features text[], timeFrequency int, input_table_tmp_name text) RETURNS text
-- AS $$
-- 
-- 	from datetime import datetime
-- 	from datetime import timedelta
-- 	 
-- 	starting_datetime = datetime.strptime(starting_time, '%Y-%m-%d %H:%M:%S')
-- 	ending_datetime = datetime.strptime(ending_time, '%Y-%m-%d %H:%M:%S')
-- 
-- 	# TODO check if time range is correct: end > start
-- 	# find most probable interval between samples in time series
-- 	query = "select " + time_column_name + " from " + table_name + " order by " + time_column_name + " desc limit 1000"
-- 	rv = plpy.execute(query)
-- 	time_intervals = {}
-- 	for i in range(len(rv)-1):
-- 		time_object_a = datetime.strptime(rv[i][time_column_name], '%Y-%m-%d %H:%M:%S')
-- 		time_object_b = datetime.strptime(rv[i+1][time_column_name], '%Y-%m-%d %H:%M:%S')
-- 		print (time_object_a - time_object_b).total_seconds()
-- 		time_intervals[(time_object_a - time_object_b).total_seconds()] = time_intervals.get((time_object_a - time_object_b).total_seconds(),0) + 1
-- 	most_probable_interval = None
-- 	probability = 0
-- 	for key, value in time_intervals.iteritems():
-- 		if value > probability:
-- 			probability = value
-- 			most_probable_interval = key
-- 
-- 	# create temporary table with rows to fill
-- 	query = "select " + time_column_name + ", " + target_column_name + " from " + table_name + " where " + time_column_name + " > \'" + str(starting_datetime) + "\' and " + time_column_name + " < \'" + str(ending_datetime) + "\'"
-- 	rv = plpy.execute(query)
-- 	lines_for_view = []
-- 	last_existing_line = starting_datetime
-- 	for line in rv:
-- 		last_existing_line = datetime.strptime(line[time_column_name], '%Y-%m-%d %H:%M:%S')
-- 		# if the value column is empty, mark as to_be_filled
-- 		if not line[target_column_name]:
-- 			lines_for_view.append({'time':line[time_column_name], 'value':'null','fill':True})
-- 		else:
-- 			lines_for_view.append({'time':line[time_column_name], 'value':line[target_column_name], 'fill':False})
-- 
-- 
-- 	number_of_rows_to_fill = int((ending_datetime - last_existing_line).total_seconds() / float(most_probable_interval))
-- 	for i in range(1, number_of_rows_to_fill+1):
-- 		lines_for_view.append({'time':str(last_existing_line + timedelta(seconds=i * 3600)), 'value':'null', 'fill':True})
-- 
-- 	# write the temporary table on the db
-- 	tmp_table_name = "tmp_forecasting_table_" + table_name
-- 	query = "drop table if exists " + tmp_table_name + " cascade"
-- 	plpy.execute(query)
-- 	query = "create table " + tmp_table_name + " (" + time_column_name  + " TIMESTAMP, " + target_column_name +   " NUMERIC, fill BOOLEAN)"
-- 	plpy.execute(query)
-- 
-- 	query = "INSERT INTO " + tmp_table_name + " VALUES "
-- 	for data in lines_for_view:
-- 		query += "('{time}', {value}, {fill}),\n".format(**data)
-- 	print query
-- 	plpy.execute(query[:-2])
-- 
-- 	return tmp_table_name;
-- 
-- 
-- 
-- 
-- 
-- 
-- $$ LANGUAGE plpythonu;



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
	EXECUTE format('CREATE TEMP VIEW %s (%s, %s) AS SELECT %s, %s FROM %s WHERE %s is null',
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
------------------------------------------------------------------------------------------------------------------------------------------