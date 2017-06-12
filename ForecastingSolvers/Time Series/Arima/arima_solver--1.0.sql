-- wrapper for the fit/predict functions
-- training_data/test_data: 	sql views
-- returns an array with the predicted values
DROP FUNCTION IF EXISTS arima_predict(int,  int,  int,  int, text, text, text, text);
CREATE OR REPLACE FUNCTION arima_predict(time_window int, p int, d int, q int, time_column_name text,
 target_column_name text, training_data text, number_of_predictions int)
RETURNS NUMERIC[]
AS $$
	print "---------------------arima_predict"
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

	print training_data
	
	rv = plpy.execute(training_data)
	for x in rv:
		print x
		training_target.append(x[target_column_name])
		training_time.append(datetime.strptime(x[time_column_name], '%Y-%m-%d %H:%M:%S'));

	
	x_train = np.array(training_time)
	y_train = np.array(training_target)

	series = pd.Series(y_train[int(len(y_train) - (len(y_train) / float(100) * time_window)):len(y_train)],
                           x_train[int(len(x_train) - (len(x_train) / float(100) * time_window)):len(x_train)])
                      
	arima_mod = sm.tsa.ARIMA(series.astype(float), order=(p,d,q))
	try:
		arima_res = arima_mod.fit()
		predictions = arima_res.forecast(number_of_predictions)[0]
	except Exception as ex:
		predictions = np.array(y_train[len(y_train) - number_of_predictions:len(y_train)])
	#--check for predictions that are nan
	for pr in range(len(predictions)):
		if math.isnan(predictions[pr]):
			predictions[pr] = np.mean(np.array(y_train[len(y_train) - number_of_predictions:len(y_train)]))

	return predictions.tolist();

$$ LANGUAGE plpythonu;