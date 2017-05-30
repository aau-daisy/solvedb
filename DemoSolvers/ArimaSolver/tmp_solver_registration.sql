-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION arima_solver" to load this file. \quit

-- Registers the solver and 1 method.
delete from sl_solver where name = 'arima_solver';


WITH 
     -- Registers the solver and its parameters.
  solver AS   (INSERT INTO sl_solver(name, version, author_name, author_url, description)
                 values ('arima_solver', 1.0, '', '', 'Test arima solvers') 
              returning sid),     
     spar1 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('table_name' , 'text', 'starting_time', null, null, null) 
                  RETURNING pid),
     sspar1 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar1
                  RETURNING sid),	

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
     spar4 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('target' , 'text', 'prediction target', null, null, null) 
                  RETURNING pid),
     sspar4 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar4
                  RETURNING sid),
     spar5 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('frequency' , 'text', 'prediction frequency', null, null, null) 
                  RETURNING pid),
     sspar5 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar5
                  RETURNING sid),
     spar6 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('time_column' , 'text', 'column of time variable', null, null, null) 
                  RETURNING pid),
     sspar6 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar6
                  RETURNING sid),
                  
                  

-- Registers the BASIC method. It has no parameters.
method1 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'default', 'default arima test', 'forecasting_test_solve_default', 'arima problem', 'test arima stuff' 
		  FROM solver RETURNING mid)


-- Perform the actual insert
SELECT count(*) FROM solver, method1, spar1, sspar1, spar2, sspar2, spar3, sspar3, spar4, sspar4, spar5, sspar5, spar6, sspar6;


-- Set the default method
UPDATE sl_solver s
SET default_method_id = mid
FROM sl_solver_method m
WHERE (s.sid = m.sid) AND (s.name = 'arima_solver') AND (m.name='default');