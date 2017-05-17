--drop function create_temporary_forecasting_table(text, text, text, text, text);
CREATE OR REPLACE FUNCTION create_temporary_forecasting_table(target_column_name text, 
		time_column_name text, starting_time text, ending_time text, table_name text)
  RETURNS integer
AS $$
	from datetime import datetime
	from datetime import timedelta
	 
	starting_datetime = datetime.strptime(starting_time, '%Y-%m-%d %H:%M:%S')
	ending_datetime = datetime.strptime(ending_time, '%Y-%m-%d %H:%M:%S')

	#TODO check if time range is correct: end > start


	# find most probable interval between samples in time series
	query = "select " + time_column_name + " - lag("+time_column_name+") over(order by " + time_column_name + ") as increase from Test order by " + time_column_name + " desc limit 1000"
	rv = plpy.execute(query)
	time_intervals = {}
	for line in rv:
		time_object = datetime.strptime(line['increase'], '%H:%M:%S')
		time_intervals[time_object.total_seconds()] = time_intervals.get(time_object.total_seconds(),0) + 1
	most_probable_interval = None
	probability = 0
	for key, value in time_intervals.iteritems():
		if value > probability:
			probability = value
			most_probable_interval = key

	# create temporary table with rows to fill
	query = "select " + time_column_name + ", " + value_column_name + " from Test where time_t > \'" + str(starting_datetime) + "\' and time_t < \'" + str(ending_datetime) + "\'"
	rv = plpy.execute(query)
	lines_for_view = []
	last_existing_line = starting_datetime
	for line in rv:
		last_existing_line = datetime.strptime(line[time_column_name], '%Y-%m-%d %H:%M:%S')
		# if the value column is empty, mark as to_be_filled
		if not line[1]:
			lines_for_view.append([line[time_column_name], None, True])
		else:
			lines_for_view.append([line[time_column_name], line[1], False])


	number_of_rows_to_fill = int((ending_datetime - last_existing_line).total_seconds() / float(most_probable_interval))
	for i in range(1, number_of_rows_to_fill+1):
		lines_for_view.append([str(last_existing_line + timedelta(seconds=i * 3600)), None, True])


	# write the temporary table on the db
	tmp_table_name = "tmp_forecasting_table_" + table_name
	query = "drop table if exists " + tmp_table_name
	cur.execute(query)
	query = "create table " + tmp_table_name + " (time_t TIMESTAMP, target NUMERIC, fill BOOLEAN)"
	cur.execute(query)


	args_str = ','.join(cur.mogrify("(%s, %s, %s)", x) for x in lines_for_view)
	query = "INSERT INTO " + tmp_table_name + " VALUES " + args_str
	cur.execute(query)

	conn.commit()

	cur.close()
	conn.close()

	return 0

$$ LANGUAGE plpythonu;


select * from create_temporary_forecasting_table('watt', 'time_t', '2015-11-12 14:00:00', '2015-11-13 14:00:00', 'Test');
