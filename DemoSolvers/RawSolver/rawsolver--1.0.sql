-- complain if script is sourced in psql, rather than via CREATE EXTENSION
-- \echo Use "CREATE EXTENSION rawsolver" to load this file. \quit

-- Install all the required data types

-- Registers the solver and 1 method.
DELETE FROM sl_solver WHERE (name = 'rawsolver');
WITH 
     -- Registers the solver and its parameters.
     solver AS   (INSERT INTO sl_solver(name, version, author_name, author_url, description)
                  values ('rawsolver', 1.0, '', '', 'Solves LP/MIP problems, given (raw) tables of unknown variables and constraints (by Laurynas)') 
                  returning sid),   
      spar1 AS   (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('log_level' , 'int', 'Logging level of the solver: 20 - ERROR, 19 - WARNING, 18 - NOTICE, 17 - INFO, 15 - LOG, 14 - DEBUG', 17, 0, 20) 
                  RETURNING pid),
     sspar1 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar1
                  RETURNING sid),                  

     -- Registers the BASIC method. It has no parameters.
     method1 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'default', 'Default rawsolver method', 'rawsolver_solve_default', 'LP/MIP problems', 
                  'Uses the variable table (vid, is_int, obj_value, value) as input relation; and two constraint tables (gid, low, high), (gid, vid, fact) as constraints.'
		  FROM solver RETURNING mid)
     -- Perform the actual insert
     SELECT count(*) FROM solver, spar1, sspar1, method1;

-- Set the default method
UPDATE sl_solver s
SET default_method_id = mid
FROM sl_solver_method m
WHERE (s.sid = m.sid) AND (s.name = 'rawsolver') AND (m.name='default');
                          
-- Install the solver method
CREATE OR REPLACE FUNCTION rawsolver_solve_default(arg sl_solver_arg) RETURNS setof record AS $$
  DECLARE
     foundAttVid	boolean = false;-- Was the "vid" attribute found?
     foundAttIs_int	boolean = false;-- Was the "is_int" attribute found?
     foundAttObj_value	boolean = false;-- Was the "obj_value" attribute found?
     foundAttMin_value	boolean = false;-- Was the "min_value" attribute found?
     foundAttMax_value	boolean = false;-- Was the "max_value" attribute found?
     foundAttValue	boolean = false;-- Was the "value" attribute found?
     foundRelCtrM       boolean = false;-- Was the constraint relation specified?
     foundRelCtrD       boolean = false;-- Was the constraint relation 2 specified?
     i		        int;		-- Index  
     newAttr		text [][];   
     t       sl_attribute_desc;
     v_o     sl_viewsql_out;
     v_d     sl_viewsql_dst;     
  BEGIN       
     -- Check if this is a propriate variable table
     foundAttVid       = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'known'::sl_attribute_kind AND att_name = 'vid'), false);
     foundAttIs_int    = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'known'::sl_attribute_kind AND att_name = 'is_int'), false);
     foundAttObj_value = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'known'::sl_attribute_kind AND att_name = 'obj_value'), false);
     foundAttMin_value = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'known'::sl_attribute_kind AND att_name = 'min_value'), false);
     foundAttMax_value = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'known'::sl_attribute_kind AND att_name = 'max_value'), false);
     foundAttValue     = COALESCE((SELECT count(*)=1 FROM sl_get_attributes(arg) WHERE att_kind = 'unknown'::sl_attribute_kind AND att_name = 'value'), false);

     -- Report and error, if schema mismatch
     IF NOT (foundAttVid AND foundAttValue) THEN
	 RAISE EXCEPTION 'The input relation must comply to the following schema: (vid, value, [is_int, obj_value]).';
     END IF;

     IF NOT foundAttObj_value THEN
	RAISE NOTICE 'No objective values ("obj_value" attribute) specified.';
     END IF;

     -- Create an input relation view
     newAttr = ARRAY[]::text[][];
     IF NOT foundAttIs_int THEN
        newAttr = newAttr || ARRAY[['is_int',    'false']];
     END IF;
     IF NOT foundAttObj_value THEN
        newAttr = newAttr || ARRAY[['obj_value', '0.0::float8']];
     END IF;
     IF NOT foundAttMin_value THEN
        newAttr = newAttr || ARRAY[['min_value', 'NULL::float8']];
     END IF;
     IF NOT foundAttMax_value THEN
        newAttr = newAttr || ARRAY[['max_value', 'NULL::float8']];
     END IF;     
     newAttr = newAttr || ARRAY[['raw_solver_value_i', 'NULL::int4']];
     newAttr = newAttr || ARRAY[['raw_solver_value_f', 'NULL::float8']];
     PERFORM sl_create_view(sl_build_out_defcols(arg, newAttr), 'raw_solver_input');

     /* Create solver parameter view */
     PERFORM sl_create_paramview(arg, 'tmp_param_view');
   
     FOR i IN SELECT generate_subscripts((arg.problem).ctr_sql, 1)   -- Run for every constrint query
     LOOP
          -- Prepares the destination view over the constraint "i"
          IF (SELECT count(*) FROM sl_get_attributes_from_sql(sl_build_dst_ctr(arg, sl_build_out(arg), i)) as tt WHERE tt.att_name='gid' OR tt.att_name='low' OR tt.att_name = 'high') = 3 THEN
	     PERFORM sl_create_view(sl_build_dst_ctr(arg, sl_build_out(arg), i), 'raw_solver_rel_ctr_m');   	     
	     foundRelCtrM = true;
          END IF;

          IF (SELECT count(*) FROM sl_get_attributes_from_sql(sl_build_dst_ctr(arg, sl_build_out(arg), i)) as tt WHERE tt.att_name='gid' OR tt.att_name='vid' OR tt.att_name = 'fact') = 3 THEN
	     PERFORM sl_create_view(sl_build_dst_ctr(arg, sl_build_out(arg), i), 'raw_solver_rel_ctr_d');   
	     foundRelCtrD = true;
          END IF;
          
     END LOOP;
     -- Check the constraint query 
     IF NOT (foundRelCtrM AND foundRelCtrD) THEN
         RAISE EXCEPTION 'There must be exactly 2 SUBJECTTO queries specifying relations in the schemas: (gid, low, high) and (gid, vid, fact).';
     END IF;

     -- Formulate the problem
     CREATE TEMP VIEW raw_solver_solution AS 
	SOLVESELECT raw_solver_value_i, raw_solver_value_f IN (SELECT * FROM raw_solver_input) AS t
	MINIMIZE  (SELECT sum(obj_value * CASE WHEN is_int THEN raw_solver_value_i ELSE raw_solver_value_f END) FROM t)
	SUBJECTTO -- MIN value case
		  (SELECT CASE WHEN is_int THEN raw_solver_value_i ELSE raw_solver_value_f END >= min_value
		   FROM t
		   WHERE min_value IS NOT NULL),
		   -- MAX value case
		  (SELECT CASE WHEN is_int THEN raw_solver_value_i ELSE raw_solver_value_f END <= max_value
		   FROM t
		   WHERE max_value IS NOT NULL),
	          -- Upper bound case
		  (SELECT sum(fact * CASE WHEN is_int THEN raw_solver_value_i ELSE raw_solver_value_f END) <= (SELECT high FROM raw_solver_rel_ctr_m WHERE gid = d.gid)
	           FROM raw_solver_rel_ctr_d AS d INNER JOIN t ON t.vid = d.vid
	           WHERE (SELECT high FROM raw_solver_rel_ctr_m WHERE gid = d.gid) IS NOT NULL
	           GROUP BY d.gid),
	           -- Lower bound case, TODO: Let solverlp ignore NULLs
		  (SELECT sum(fact * CASE WHEN is_int THEN raw_solver_value_i ELSE raw_solver_value_f END) >= (SELECT low FROM raw_solver_rel_ctr_m WHERE gid = d.gid)
	           FROM raw_solver_rel_ctr_d AS d INNER JOIN t ON t.vid = d.vid
	           WHERE (SELECT low FROM raw_solver_rel_ctr_m WHERE gid = d.gid) IS NOT NULL
	           GROUP BY d.gid)
	WITH solverlp(log_level:=(SELECT value_i FROM tmp_param_view WHERE param='log_level'));

--    Output the solver result
      RETURN QUERY EXECUTE sl_return(arg, 
                                     sl_build_out_defcols(arg, ARRAY[['value','(CASE WHEN is_int THEN raw_solver_value_i ELSE raw_solver_value_f END)']], 
			             ROW('SELECT * FROM raw_solver_solution')::sl_viewsql_out));

      DROP VIEW raw_solver_solution;
      DROP VIEW tmp_param_view;
      PERFORM sl_drop_view('raw_solver_input');
      PERFORM sl_drop_view('raw_solver_rel_ctr_m');
      PERFORM sl_drop_view('raw_solver_rel_ctr_d');
   END
$$ LANGUAGE plpgsql VOLATILE STRICT;

/* Testing the solver */

/*

SOLVESELECT value IN (SELECT 1 AS vid, false AS is_int, 1::float8 AS obj_value, -1::float8 AS min_value, NULL::float8 AS max_value, NULL::float8 AS value) AS t
SUBJECTTO (SELECT 1 AS gid, -100.8::float8 AS low, 100.5::float8 AS high),
          (SELECT 1 AS gid, 1 AS vid, 1 AS fact)
WITH rawsolver;

*/