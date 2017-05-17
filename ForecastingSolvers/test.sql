drop function test_extraction(text, text);
CREATE OR REPLACE FUNCTION test_extraction (target_column_name text, time_column_name text)
  RETURNS integer
AS $$
	import pandas as pd
	import statsmodels.api as sm
	import numpy as np
	from datetime import datetime
	import sys
	from sklearn.metrics import mean_squared_error
	from math import sqrt

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
			target_colum_to_fill.append(target_value)
	
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
	best_parameters_set_rmse = None
	final_prediction = None

	#find model by cross validation

	for time_window in time_window_parameters:
		series = pd.Series(y_train[int(len(y_train) - (len(y_train) / float(100) * time_window)):len(y_train)],
                           x_train[int(len(x_train) - (len(x_train) / float(100) * time_window)):len(x_train)])
                print series
		for p in p_parameters:
			for d in d_parameters:
				for q in q_parameters:
					arima_mod = sm.tsa.ARIMA(series.astype(float), order=(p,d,q))
					try:
						arima_res = arima_mod.fit()
						predictions = arima_res.forecast(len(y_test))[0]
					except Exception as ex:
						predictions = np.array(y_train[len(y_train) - len(y_test):len(y_train)])
					#Evaluate the predictions with RMSE
					rmse = 0
					print "start evaluation of " + str(p) + str(d) + str(q)
					for i in range(len(predictions)):
						rmse += sqrt(mean_squared_error([predictions[i]], [y_test[i]]))
						if rmse < lowest_RMSE:
							lowest_RMSE = rmse
							best_parameters_set_rmse = [time_window, p, d, q]
							best_model = arima_res


	# print the final prediction and the parameters of the model
	print "-------rmse--------------------------------------------------------------------------------------"
	print(best_parameters_set_rmse)
	print(lowest_RMSE)
	print "target column length"
	print len(target_column_to_fill)
	return 0

$$ LANGUAGE plpythonu;

select * from test_extraction('watt','time_t');



select * from Test


