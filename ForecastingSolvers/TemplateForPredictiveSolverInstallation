-- Prediction solver installation template

-- CLEANUP
delete from sl_solver where name = 'solver_name';



WITH

-- REGISTER THE SOLVER
  solver AS   (INSERT INTO sl_solver(name, version, author_name, author_url, description)
                 values ('solver_name', 1.0, 'author', 'link', 'description') 
              returning sid),     

-- Registers the BASIC method. It has no parameters.
 method1 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'any name', 'any name', 'solver_method_name', 'any description', 'description' 
		  FROM solver RETURNING mid),

-- Register the non-solver method associated to this solver (the method that peforms the the prediction)
pr_method AS (INSERT INTO sl_pr_method(name, version, funct_name, description, type)
		VALUES ('descriptive name', '1.0', 'your_method_name','description','type: [ts, ml, custom]')
		returning mid),

sl_pr_sol_method AS (INSERT INTO sl_pr_solver_method(sid, mid)
		SELECT sid, mid from solver, pr_method
		returning sid),


-- Register the standard parameters: possible parameters: start_time (text), end_time(text), frequency(text), features(text)

     sparX AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('name' , 'type', 'description', null, null, null) 
                  RETURNING pid),
     ssparX AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar2
                  RETURNING sid),

     -- add more standard parameters here
  


     -- PARAMETERS THAT NEED TO BE FIT BY CROSS VALIDATION, only numerical types
     sparY AS   (INSERT INTO sl_pr_parameter(name, type, description, value_default, value_min, value_max)
			values ('name', 'type', 'description', null, null, null)
			returning pid),
     ssparY AS (INSERT INTO sl_pr_method_param(mid, pid)
		SELECT mid, pid FROM pr_method, spar9
		returning mid),

		-- add more cross validation parameters here
     

-- Perform the actual insert
SELECT count(*) FROM solver, method1, pr_method, sl_pr_sol_method, sparX, ssparX, sparY, ssparY;

-- Set the default method
UPDATE sl_solver s
SET default_method_id = mid
FROM sl_solver_method m
WHERE (s.sid = m.sid) AND (s.name = 'solver_name') AND (m.name='name');