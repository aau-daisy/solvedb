-- wrapper for the fit/predict functions
-- training_data/test_data: 	sql views
-- returns an array with the predicted values
DROP FUNCTION IF EXISTS arima_predict(int,  int,  int,  int, text, text, text, text);
CREATE OR REPLACE FUNCTION arima_predict(time_window int, p int, d int, q int, time_column_name text, target_column_name text, training_data text, test_data text)
RETURNS NUMERIC[]
AS $$
	print "---------------------you are inside arima_predict"
	import pandas as pd
	import statsmodels.api as sm
	import numpy as np
	from datetime import datetime
	import sys
	from sklearn.metrics import mean_squared_error
	from math import sqrt
	import math

	
	training_time	= []
	training_target	= []
	test_time	= []
	test_target	= []

	print training_data
	
	rv = plpy.execute(training_data)
	for x in rv:
		print x
		training_target.append(x[target_column_name])
		training_time.append(datetime.strptime(x[time_column_name], '%Y-%m-%d %H:%M:%S'));

	print test_data
	rv = plpy.execute(test_data)
	for x in rv:
		test_time.append(datetime.strptime(x[time_column_name], '%Y-%m-%d %H:%M:%S'))
		test_target.append(x[target_column_name])
		

	
	x_train = np.array(training_time)
	x_test = np.array(test_time)
	y_train = np.array(training_target)
	y_test = np.array(test_target)

	print "--------------------------------------xtrain"
	print x_train
	print "--------------------------------------ytrain"
	print y_train

	series = pd.Series(y_train[int(len(y_train) - (len(y_train) / float(100) * time_window)):len(y_train)],
                           x_train[int(len(x_train) - (len(x_train) / float(100) * time_window)):len(x_train)])
                      
	print "setup complete, starting prediction"
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

	return predictions.tolist();

$$ LANGUAGE plpythonu;