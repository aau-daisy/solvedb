-- Installation script for ARIMA solver
delete from sl_solver where name = 'arima_solver';


WITH
-- Registers the solver
  solver AS   (INSERT INTO sl_solver(name, version, author_name, author_url, description)
                 values ('arima_solver', 1.0, 'Davide Frazzetto', 'http://vbn.aau.dk/en/persons/davide-frazzetto(448b0269-416f-4a18-80b8-ec6b6f0bdb71).html', 'solver for ARIMA time series prediction') 
              returning sid),     

-- Registers the BASIC method. It has no parameters.
 method1 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'arima', 'default predictive solver', 'arima_solver', 'predictive problem', 'ARIMA predictive model' 
		  FROM solver RETURNING mid),

-- Register the non-solver method associated to this solver (the method that peforms the the prediction)
pr_method AS (INSERT INTO sl_pr_method(name, version, funct_name, description, type)
		VALUES ('arima_method', '1.0', 'arima_predict','function that performs arima prediction','ts')
		returning mid),

sl_pr_sol_method AS (INSERT INTO sl_pr_solver_method(sid, mid)
		SELECT sid, mid from solver, pr_method
		returning sid),


-- Register the parameters

     spar2 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('start_time' , 'text', 'starting_time', null, null, null) 
                  RETURNING pid),
     sspar2 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar2
                  RETURNING sid),
     spar3 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('end_time' , 'text', 'ending_time', null, null, null) 
                  RETURNING pid),
     sspar3 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar3
                  RETURNING sid),
     spar5 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('frequency' , 'text', 'prediction frequency', null, null, null) 
                  RETURNING pid),
     sspar5 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar5
                  RETURNING sid),
     spar7 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('features' , 'text', 'feature columns to use', null, null, null) 
                  RETURNING pid),
     sspar7 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar7
                  RETURNING sid),     


     -- parameters that need to be fit by cross validation
     spar9 AS   (INSERT INTO sl_pr_parameter(name, type, description, value_default, value_min, value_max)
			values ('time_window', 'int', 'percentage of data to use for prediction', null, 5, 100)
			returning pid),
     sspar9 AS (INSERT INTO sl_pr_method_param(mid, pid)
		SELECT mid, pid FROM pr_method, spar9
		returning mid),
     spar10 AS   (INSERT INTO sl_pr_parameter(name, type, description, value_default, value_min, value_max)
			values ('p', 'int', 'AR component', null, 0, 5)
			returning pid),
     sspar10 AS (INSERT INTO sl_pr_method_param(mid, pid)
		SELECT mid, pid FROM pr_method, spar10
		returning mid),
    spar11 AS   (INSERT INTO sl_pr_parameter(name, type, description, value_default, value_min, value_max)
			values ('d', 'int', 'I component', null, 0, 2)
			returning pid),
     sspar11 AS (INSERT INTO sl_pr_method_param(mid, pid)
		SELECT mid, pid FROM pr_method, spar11
		returning mid),
    spar12 AS   (INSERT INTO sl_pr_parameter(name, type, description, value_default, value_min, value_max)
			values ('q', 'int', 'MA component', null, 0, 5)
			returning pid),
     sspar12 AS (INSERT INTO sl_pr_method_param(mid, pid)
		SELECT mid, pid FROM pr_method, spar12
		returning mid)

-- Perform the actual insert
SELECT count(*) FROM solver, method1, pr_method, sl_pr_sol_method, spar2, sspar2, spar3, sspar3, spar5, sspar5, spar7, sspar7, spar9, sspar9, spar10, sspar10, spar11, sspar11, spar12, sspar12;

-- Set the default method
UPDATE sl_solver s
SET default_method_id = mid
FROM sl_solver_method m
WHERE (s.sid = m.sid) AND (s.name = 'arima_solver') AND (m.name='arima');
