
CREATE OR REPLACE FUNCTION arima_predict(time_window int, p int, d int, q int, time_column_name text,
 target_column_name text, training_data text, number_of_predictions int)
RETURNS NUMERIC[]
AS $$
	import pandas as pd
	# import statsmodels.api as sm
	import numpy as np
	from datetime import datetime
	# import sys
	from sklearn.metrics import mean_squared_error
	from math import sqrt
	import math
	from pandas import DataFrame
	import dateutil.parser as parser

	print("Running ARIMA")
	training_time	= []
	training_target	= []

	rv = plpy.execute(training_data)
	for x in rv:
		training_target.append(x[target_column_name])
		training_time.append(parser.parse(x[time_column_name]));

	
	x_train = np.array(training_time)
	y_train = np.array(training_target)

	series = pd.Series(y_train[int(len(y_train) - (len(y_train) / float(100) * time_window)):len(y_train)],
                            x_train[int(len(x_train) - (len(x_train) / float(100) * time_window)):len(x_train)])

                    
	try:
		arima_mod = sm.tsa.ARIMA(series.astype(float), order=(p,d,q))
		arima_res = arima_mod.fit()
		predictions = arima_res.forecast(number_of_predictions)[0]

		#if needed print information about the model to the client
		if GD["print_model_summary"]:
			plpy.notice(arima_res.summary())
			residuals = DataFrame(arima_res.resid)
			plpy.notice('-------ARIMA Residuals Description-------')
			plpy.notice(residuals.describe())
		
	except Exception as ex:
		plpy.notice('------ARIMA model cannot be fit with parameters')
		plpy.warning(format(ex))
		#predictions = np.array(y_train[len(y_train) - number_of_predictions:len(y_train)])
		predictions = np.zeros(number_of_predictions)
	except ValueError as err:
		plpy.notice('------ARIMA model cannot be fit with parameters')
		plpy.warning(format(err))
		#predictions = np.zeros(number_of_predictions)
		predictions = np.array(y_train[len(y_train) - number_of_predictions:len(y_train)])
	#--check for predictions that are nan
	for pr in range(len(predictions)):
		if math.isnan(predictions[pr]):
			plpy.warning('prediction is nan')
			predictions[pr] = np.mean(np.array(y_train[len(y_train) - number_of_predictions:len(y_train)]))
	
	return predictions.tolist();

$$ LANGUAGE plpythonu; 
---------------------------------
