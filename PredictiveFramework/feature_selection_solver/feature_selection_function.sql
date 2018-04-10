drop function feature_selection(text[], text, text);
CREATE OR REPLACE FUNCTION feature_selection(features text[], target text, table_name text) returns name[] as $$

	print "this is the python method"
	
	import numpy as np
	from sklearn.feature_selection import RFE
	from sklearn.feature_selction import LinearRegression
	import scipy
	# load the data, create numpy data and target array X, y
	X = []
	y = []


	source = "select * from " + table_name
	rv = plpy.execute(source)
	for row in rv:
		a = []
		for feature in features:
			a.append(row[feature])
		X.append(a)
		y.append(row[target])

	X = np.array(X)
	y = np.array(y)

	model = LinearRegression()
	model.fit(X, y)
	print model.feature_importances_

	return features

$$ LANGUAGE plpythonu;

-- create extreme random models


--select features up to 80% of relevance
-- cross validate that score is better with new feature than without new feature

--return the names of the features