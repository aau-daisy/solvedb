drop function arima_prediction(text, text, text, text, text, text);
CREATE OR REPLACE FUNCTION arima_prediction (target_column_name text, time_column_name text, table_name text, forecasting_table_name text, starting_time text, end_time text)
  RETURNS boolean
AS $$
	import pandas as pd
	import statsmodels.api as sm
	import numpy as np
	from datetime import datetime
	import sys
	from sklearn.metrics import mean_squared_error
	from math import sqrt
	import math


	#startup operations
	#query = "select * from create_temporary_forecasting_table('" + target_column_name+"', '"+time_column_name+"', '" + starting_time+ "', '"+end_time+"', '"+table_name+"')"
	#plpy.execute(query)
	rv = plpy.execute("SELECT * from Test");
	training_time_column = [];
	training_target_column = [];
	time_column_to_fill = []
	target_column_to_fill = []
	for x in rv:
		datetime_object = datetime.strptime(x[time_column_name], '%Y-%m-%d %H:%M:%S')
		target_value = x[target_column_name];
		if target_value:
			training_target_column.append(target_value)
			training_time_column.append(datetime_object);
		else:
			time_column_to_fill.append(datetime_object)
			target_column_to_fill.append(target_value)
	
	#split for cross validation
	x_train = np.array(training_time_column[0:int(len(training_time_column) / float(100) * 90)])
	x_test = np.array(training_time_column[int(len(training_time_column) / float(100) * 90): len(training_time_column)])
	y_train = np.array(training_target_column[0:int(len(training_target_column) / float(100) * 90)])
	y_test = np.array(training_target_column[int(len(training_target_column) / float(100) * 90): len(training_target_column)])




	#parameters to evaluate
	time_window_parameters = [5,10,20]
	p_parameters = range(0,3)
	d_parameters = range(0,2)
	q_parameters = range(0,3)

	lowest_RMSE = sys.float_info.max
	best_parameters_set = {}
	final_prediction = None

	#find model by cross validation

	for time_window in time_window_parameters:
		series = pd.Series(y_train[int(len(y_train) - (len(y_train) / float(100) * time_window)):len(y_train)],
                           x_train[int(len(x_train) - (len(x_train) / float(100) * time_window)):len(x_train)])
		for p in p_parameters:
			for d in d_parameters:
				for q in q_parameters:
					arima_mod = sm.tsa.ARIMA(series.astype(float), order=(p,d,q))
					try:
						arima_res = arima_mod.fit()
						predictions = arima_res.forecast(len(y_test))[0]
					except Exception as ex:
						predictions = np.array(y_train[len(y_train) - len(y_test):len(y_train)])
					#--check for predictions that are nan
					for pr in range(len(predictions)):
						if math.isnan(predictions[pr]):
							predictions[pr] = np.mean(np.array(y_train[len(y_train) - len(y_test):len(y_train)]))
					print "PREDICTIONS:-----"
					print predictions
					#Evaluate the predictions with RMSE
					rmse = 0
					print "start evaluation of " + str(p) + str(d) + str(q)
					for i in range(len(predictions)):
						rmse += sqrt(mean_squared_error([predictions[i]], [y_test[i]]))
						if rmse < lowest_RMSE:
							lowest_RMSE = rmse
							best_parameters_set = {"time_window":time_window, "p":p, "d":d, "q":q}
							best_model = arima_res


	# print the parameters of the model
	print "-------rmse--------------------------------------------------------------------------------------"
	print(best_parameters_set)
	print(lowest_RMSE)

	# save the model on the model table
	query = "create table if not exists predictive_solvers (id serial not null primary key, solver_type text not null, parameters json )"
	plpy.execute(query)
	query = "insert into predictive_solvers(solver_type, parameters) values ('ARIMA','{"
	query += "\"time_window\":\"{time_window}\",\"p\":\"{p}\",\"d\":\"{d}\", \"q\":\"{q}\"".format(**best_parameters_set)
	query += "}')"
	print query
	plpy.execute(query)


	# write the prediction on the temporary table
	
	query = "select * from " + forecasting_table_name
	rv = plpy.execute(query)
	number_of_predictions = len(rv)
	predictions = best_model.forecast(number_of_predictions)[0] 
	for i in range(len(rv)):
		query = "UPDATE " + forecasting_table_name + " SET " + target_column_name + "='{target}' WHERE "+ time_column_name + " = '{time_t}' and fill = True"
		data = {"time_t":rv[i]['time_t'], "fill":rv[i]['fill'], "target":predictions[i]}
		query = query.format(**data)
		print query
		plpy.execute(query)

	# join original table with forecasting
	return True

$$ LANGUAGE plpythonu;

-- TESTING
-- 
-- select * from test_extraction('watt','time_t', 'Test', '2015-11-12 23:00:00', '2015-11-13 23:00:00');
-- 
-- select * from join_prediction_and_original_table('Test', 'tmp_forecasting_table_Test')
-- 
-- select * from final_data order by time_t
-- 
-- 
-- select * from Test
-- drop table final_data cascade