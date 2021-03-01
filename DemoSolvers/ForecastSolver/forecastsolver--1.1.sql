-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION forecastsolver" to load this file. \quit

-- Install all the required data types

-- Registers the solver and 1 method.
WITH 
     -- Registers the solver and its parameters.
     solver AS   (INSERT INTO sl_solver(name, version, author_name, author_url, description)
                  values ('forecastingsolver', 1.1, '', '', 'A solver for energy demand time series forecasting by Laurynas Siksnys') 
                  returning sid),     

     -- Registers the BASIC method. It has no parameters.
     method1 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'default', 'The ERGV based technique for energy demand time series forecasting', 'forecasting_solve_default', 'Time series forecasting problem', 'Solves the forecasting problem utilizing the LP solver'
		  FROM solver RETURNING mid)
     -- Perform the actual insert
     SELECT count(*) FROM solver, method1;

-- Set the default method
UPDATE sl_solver s
SET default_method_id = mid
FROM sl_solver_method m
WHERE (s.sid = m.sid) AND (s.name = 'forecastingsolver') AND (m.name='default');
                          
-- Install the solver method
CREATE OR REPLACE FUNCTION forecasting_solve_default(arg sl_solver_arg) RETURNS setof record AS $$
  DECLARE
     foundAttTime	boolean;	-- Was the time attribute found?
     foundAttLoad	boolean;	-- Was the electricity load attribute found?
     foundRelTemp	boolean;	-- Was the temperature relations supplied in SUBJECTTO?
     i		        int;		-- Index
     t       sl_attribute_desc;
     v_o     sl_viewsql_out;
     v_d     sl_viewsql_dst;     
  BEGIN       

     -- Check the type on unknown-variable columns   
     IF (SELECT count(*) FROM sl_get_attributes(arg)) <> 3 /* One for ordering (ID) column */ THEN 
      RAISE EXCEPTION 'The input relation must have two columns "time" and "load"!';
     END IF;
  
     -- Check the type on unknown-variable columns   
     foundAttTime = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'unknown'::sl_attribute_kind AND att_name = 'time'), false);
     foundAttLoad = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'unknown'::sl_attribute_kind AND att_name = 'load'), false);

      IF NOT (foundAttLoad AND foundAttTime) THEN
	 RAISE EXCEPTION 'The columns "time" and "load" were not found in the unknown attribute list!';
     END IF;
          
     -- Check contextual data, e.g., temperature time-series
     foundRelTemp:= False;
     FOR i IN SELECT generate_subscripts((arg.problem).ctr_sql, 1)   -- Run for every constrint query
     LOOP
          -- Prepares the destination view over the constraint "i"
          IF (SELECT count(*) FROM sl_get_attributes_from_sql(sl_build_dst_ctr(arg, sl_build_out(arg), i)) as tt WHERE tt.att_name='time' OR tt.att_name='temp') = 2 THEN
	     PERFORM sl_create_view(sl_build_dst_ctr(arg, sl_build_out(arg), i), 'temperature_view');   	     
	     foundRelTemp = true;
          END IF;
     END LOOP;
     
     -- Create a dummy temperature view, if not specified
     IF (NOT foundRelTemp) THEN 
	     CREATE TEMP VIEW temperature_view AS SELECT (NULL::timestamp) AS time, NULL::float8 as temp;
     END IF;

     -- Create a view on the input relation
     PERFORM sl_create_view(sl_build_out(arg),'raw_data_view');

     -- Create a predictor variable view
     CREATE TEMP VIEW raw_data_predictors AS
	WITH  extendedTS AS (SELECT (d.time::date) as date, EXTRACT(hour FROM d.time) as hour, d.load, t.temp 
			     FROM
			     (SELECT time::timestamp, load FROM raw_data_view
			      UNION 
			      SELECT (SELECT max(time)::date + 1 FROM raw_data_view)::timestamp + hour * (INTERVAL '1 hour'), NULL 
			      FROM generate_series(0,23) as hour
			     ) AS d LEFT OUTER JOIN temperature_view t ON (d.time=t.time)),
	   maxTemps AS (SELECT date, max(temp) as maxtemp FROM extendedTS GROUP BY date),
           loads8am AS (SELECT date, load as load8am      FROM extendedTS WHERE hour = 8)	   
           SELECT (date::timestamp::date) as date, hour, load::float8, 
		  COALESCE(temp, 20)			AS temp,
		  COALESCE(temp, 20)^2			AS temp2,
		  COALESCE((SELECT maxtemp FROM maxTemps WHERE date=d.date-1), 20) as tempymax,
		  COALESCE((SELECT load8am FROM loads8am WHERE date=d.date-1), 0)  as load8am,
		  EXTRACT(YEAR  FROM date)		AS year,
		  (EXTRACT(MONTH FROM date)=1)::int	AS jan,
		  (EXTRACT(MONTH FROM date)=2)::int	AS feb,
		  (EXTRACT(MONTH FROM date)=3)::int	AS mar,
		  (EXTRACT(MONTH FROM date)=4)::int	AS apr,
		  (EXTRACT(MONTH FROM date)=5)::int	AS may,
		  (EXTRACT(MONTH FROM date)=6)::int	AS jun,
		  (EXTRACT(MONTH FROM date)=7)::int	AS jul,
		  (EXTRACT(MONTH FROM date)=8)::int	AS aug,
		  (EXTRACT(MONTH FROM date)=9)::int	AS sep,
		  (EXTRACT(MONTH FROM date)=10)::int	AS oct,
		  (EXTRACT(MONTH FROM date)=11)::int	AS nov,		
		  (EXTRACT(DOW FROM date)=1)::int	AS mon,
		  (EXTRACT(DOW FROM date)=2)::int	AS tue,
		  (EXTRACT(DOW FROM date)=3)::int	AS wed,
		  (EXTRACT(DOW FROM date)=4)::int	AS thu,
		  (EXTRACT(DOW FROM date)=5)::int	AS fri,
		  (EXTRACT(DOW FROM date)=6)::int	AS sat  
		FROM extendedTS AS d;

     --COPY (SELECT * FROM raw_data_predictors) TO '/home/laurynas/Projects/pg_out1' (DELIMITER '|');
     --COPY (SELECT * FROM raw_loadtemps) TO '/home/laurynas/Projects/pg_out2' (DELIMITER '|');     
     -- We're now estimating model parameters with the LP solver
     CREATE TEMP TABLE forecast_params AS 	
	-- Find model parameters
	SOLVESELECT  p(peps, pyear, pjan, pfeb, pmar, papr, pmay, pjun, pjul, paug, psep, poct, pnov, pmon, ptue, pwed, pthu, pfri, psat, ptemp, ptemp2, ptempymax, pload8am) AS
		(SELECT  phour, 0.0 AS peps, 0.0 AS pyear, 0.0 AS pjan,  0.0 AS pfeb, 0.0 AS pmar, 0.0 AS papr, 
					 0.0 AS pmay,  0.0 AS pjun, 0.0 AS pjul,  0.0 AS paug,  0.0 AS psep, 0.0 AS poct, 0.0 AS pnov, 
					 0.0 AS pmon,  0.0 AS ptue, 0.0 AS pwed,  0.0 AS pthu,  0.0 AS pfri, 0.0 AS psat, 0.0 AS ptemp,
					 0.0 AS ptemp2,0.0 AS ptempymax,	   0.0 AS pload8am FROM generate_series(0,23) phour)
	  WITH u(xp, xn) AS (SELECT *, 0.0 AS xp, 0.0 AS xn FROM raw_data_predictors WHERE load IS NOT NULL)
	MINIMIZE  (SELECT sum(xp + xn) FROM u) /* The LP trick to be able to minimize sum of absolute values */ 
	SUBJECTTO (SELECT xp>=0, xn>=0 FROM u),
		  (SELECT u.xp - u.xn =  /* Data value - Model value */ u.load - (
			       p.peps + p.pyear*u.year + p.pjan*u.jan::int4 + p.pfeb*u.feb::int4 + p.pmar*u.mar::int4 + p.papr*u.apr::int4 + 
				    p.pmay*u.may::int4 + p.pjun*u.jun::int4 + p.pjul*u.jul::int4 + p.paug*u.aug::int4 + p.psep*u.sep::int4 + 
				    p.poct*u.oct::int4 + p.pnov*u.nov::int4 + p.pmon*u.mon::int4 + p.ptue*u.tue::int4 + p.pwed*u.wed::int4 + 
				    p.pthu*u.thu::int4 + p.pfri*u.fri::int4 + p.psat*u.sat::int4 + p.ptemp*u.temp + p.ptemp2*u.temp2 + 
				    p.ptempymax*u.tempymax + p.pload8am*u.load8am)
		   FROM p INNER JOIN u ON p.phour = u.hour)
	USING solverlp.auto(use_nulls := 0 /* Increases performance, as PostgreSQL does not have to de-index NULL arrays*/);
		
     -- We're now applying the model parameters and create the output view
     CREATE TEMP VIEW forecast_result AS
	SELECT time, load FROM raw_data_view
	UNION
	SELECT (d.date::timestamp + (d.hour * (INTERVAL '1 hour'))) as time, 
	       ( /* Model value */     p.peps + p.pyear*d.year + p.pjan*d.jan::int4 + p.pfeb*d.feb::int4 + p.pmar*d.mar::int4 + p.papr*d.apr::int4 + 
					    p.pmay*d.may::int4 + p.pjun*d.jun::int4 + p.pjul*d.jul::int4 + p.paug*d.aug::int4 + p.psep*d.sep::int4 + 
					    p.poct*d.oct::int4 + p.pnov*d.nov::int4 + p.pmon*d.mon::int4 + p.ptue*d.tue::int4 + p.pwed*d.wed::int4 + 
					    p.pthu*d.thu::int4 + p.pfri*d.fri::int4 + p.psat*d.sat::int4 + p.ptemp*d.temp     + p.ptemp2*d.temp2 + 
					    p.ptempymax*d.tempymax + p.pload8am*d.load8am) as load 
	FROM raw_data_predictors AS d INNER JOIN forecast_params AS p ON d.hour = p.phour
	WHERE d.load IS NULL;
     -- Output the forecasting result. As only two columns (time and load) are supported, no additional join is needed
     RETURN QUERY EXECUTE sl_return(arg, ROW('SELECT time, load FROM forecast_result')::sl_viewsql_out);     
     -- Clean-up     
     DROP VIEW forecast_result;
     DROP TABLE forecast_params;
     DROP VIEW raw_data_predictors;
     DROP VIEW temperature_view;
     PERFORM sl_drop_view('raw_data_view');
   END
$$ LANGUAGE plpgsql VOLATILE STRICT;

/* Testing the solver */
/*


SELECT time, load FROM (
 SOLVESELECT * IN (SELECT time, load FROM hist_load) AS s
 USING forecastingsolver) AS s
ORDER BY time DESC

SELECT time, load FROM (
 SOLVESELECT * IN (SELECT ('2012-01-01'::timestamp + hour * (INTERVAL '1 hour')) AS time, 123+hour/10 AS load FROM generate_series(0, 99) as hour) AS t
 SUBJECTTO(SELECT ('2012-01-01'::timestamp + hour * (INTERVAL '1 hour')) AS time,   (hour/20) AS temp FROM generate_series(0, 150) as hour)
 USING forecastingsolver) AS s
ORDER BY time DESC

SELECT time, load FROM (
 SOLVESELECT  load IN (SELECT (date::timestamp + hour * (INTERVAL '1 hour')) as time, load FROM loaddata) AS s
 SUBJECTTO            (SELECT (date::timestamp + hour * (INTERVAL '1 hour')) as time, temp FROM loadtemps)
 USING forecastingsolver) AS s 
ORDER BY time DESC;


 RAISE NOTICE 'Fitting MSE(%)', (SELECT sum((d.load - 
				       p.peps + p.pyear*d.year + p.pjan*d.jan::int4 + p.pfeb*d.feb::int4 + p.pmar*d.mar::int4 + p.papr*d.apr::int4 + 
					    p.pmay*d.may::int4 + p.pjun*d.jun::int4 + p.pjul*d.jul::int4 + p.paug*d.aug::int4 + p.psep*d.sep::int4 + 
					    p.poct*d.oct::int4 + p.pnov*d.nov::int4 + p.pmon*d.mon::int4 + p.ptue*d.tue::int4 + p.pwed*d.wed::int4 + 
					    p.pthu*d.thu::int4 + p.pfri*d.fri::int4 + p.psat*d.sat::int4 + p.ptemp*d.temp     + p.ptemp2*d.temp2 + 
					    p.ptempymax*d.tempymax + p.pload8am*d.load8am))^2)
				     FROM raw_data_predictors AS d INNER JOIN forecast_params AS p ON d.hour = p.phour
				     WHERE (d.load IS NOT NULL));

*/
