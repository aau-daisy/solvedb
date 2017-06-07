-- temporary function for testing brute force parameter testing on ARIMA 
-- VS SolveDB inner parameter solving functionalities
DROP FUNCTION IF EXISTS arima_handler(text, name, name, text, text);
CREATE FUNCTION arima_handler(results_table text, time_column_name name, target_column_name name, training_data text, test_data text)
returns numeric[] as $$

	import sys

	print "----------------------arima handler"

	time_window_parameters = [5,10,20]
	p_parameters = [0,1,2,3]
	d_parameters = [0,1,2]
	q_parameters = [0,1,2,3]
	trained_parameters = []

	test_values = []
	lowest_RMSE = sys.float_info.max
	best_parameters_set = {}
	final_prediction = None


	# retrieve the original values
	rv = plpy.execute(test_data)
	for row_data in rv:
		test_values.append(row_data[str(target_column_name)])
	

	for time_window in time_window_parameters:
		for p in p_parameters:
			for d in d_parameters:	
				for q in q_parameters:
					# get an array with the predictions, with the given parameters
					#query = "SELECT arima_predict(" + str() + ", " + str(p) + ", " + str(d) + ", " + str(q) + ", '" + str() + "', '" + str() + "', '" +  + "', '"  +  + "') as prediction"
					plan = plpy.prepare("SELECT arima_predict($1, $2, $3, $4, $5, $6, $7, $8) as prediction", ["int", "int", "int", "int", "text","text","text", "text",])
					rv = plpy.execute(plan, [time_window, p, d, q, time_column_name, target_column_name, training_data, test_data])
					predictions = rv[0]['prediction']

					plan = plpy.prepare("SELECT sl_evaluation_rmse($1, $2) as rmse", ["numeric[]","numeric[]"])
					rv = plpy.execute(plan, [test_values, predictions])
					rmse = rv[0]['rmse']
					# optimize the parameters
					plpy.notice("RMSE IS: ", rmse)
					if rmse is not None and rmse < lowest_RMSE:
						lowest_RMSE = rmse
						best_parameters_set = {"time_window":time_window, "p":p, "d":d, "q":q}
						trained_parameters = [time_window, p,d,q]


	# check if the predictions have been generated
	if not best_parameters_set:
		return
	# print the parameters of the model
	# save the model on the model table
	query = "insert into " + results_table + " values ('arima_predict','{"
	query += "\"time_window\":\"{time_window}\",\"p\":\"{p}\",\"d\":\"{d}\", \"q\":\"{q}\"".format(**best_parameters_set)
	query += "}', " + str(lowest_RMSE)   + ")"

	plpy.execute(query)

	query = "insert into sl_pr_model_instances values ('arima_predict()', {"
	query += "\"time_window\":\"{time_window}\",\"p\":\"{p}\",\"d\":\"{d}\", \"q\":\"{q}\"".format(**best_parameters_set)
	query += "}')"
	plpy.execute(query)
	return trained_parameters
	
	
$$ LANGUAGE plpythonu;


-- drop function test1(int[], int[]);
-- create or replace function test1(a int[], b int[]) returns int[] as $$
-- 
-- 	return a
-- 
-- $$ language plpythonu;
-- 
-- create or replace function test2() returns void as $$
-- 	a = [1,2,3]
-- 	plan = plpy.prepare("select test1($1, $2)", ["int[]", "int[]"])
-- 	rv = plpy.execute(plan, [a, a])
-- 	for line in rv:
-- 		plpy.notice("line is ", line, "\n")
-- $$ language plpythonu;
-- 
-- select * from test2()

