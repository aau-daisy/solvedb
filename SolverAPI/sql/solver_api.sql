DROP EXTENSION solverapi CASCADE;
CREATE EXTENSION solverapi;


/*
DROP TYPE sl_attribute_kind CASCADE;
DROP TYPE sl_parameter_type CASCADE;
DROP TABLE sl_parameter CASCADE;
DROP TABLE sl_solver CASCADE;
DROP TABLE sl_solver_param CASCADE;
DROP TABLE sl_solver_method CASCADE;
DROP TABLE sl_solver_method_param CASCADE;
DROP TYPE sl_obj_dir CASCADE;
DROP TYPE sl_problem CASCADE;
DROP TYPE sl_parameter_value CASCADE;
DROP TYPE sl_solver_arg CASCADE;
DROP TYPE sl_solve_query CASCADE;
DROP TYPE sl_attribute_desc CASCADE;
DROP TYPE sl_viewsql_src CASCADE;
DROP TYPE sl_viewsql_dst CASCADE;
*/


SELECT * FROM sl_get_attributes('SELECT 1 as aaa');

SELECT generate_subscripts(ARRAY[]::sl_attribute_desc[], 1);

-- Test call to solve
WITH solver AS (insert into sl_solver(name)
                values ('test_solver') 
                returning sid),
     method AS (insert into sl_solver_method(sid,name, func_name)
                select sid, 'test_method','test_solver_method1' from solver 
                returning mid),
     par    AS (insert into sl_parameter(name, type, description)
                values ('par1' , 'int', 'bla bla bla') 
                RETURNING pid),
     mpar   AS (insert into sl_solver_method_param(mid, pid)
                select mid, pid FROM method, par 
                RETURNING mid)
                SELECT * FROM mpar;

                -- Test call to solve in C
WITH solver AS (insert into sl_solver(name)
                values ('test_solverC') 
                returning sid),
     method AS (insert into sl_solver_method(sid,name, func_name)
                select sid, 'test_methodC','sl_dummy_solve' from solver 
                returning mid),
     par    AS (insert into sl_parameter(name, type, descr)
                values ('par1' , 'int', 'bla bla bla') 
                RETURNING pid),
     mpar   AS (insert into sl_solver_method_param(mid, pid)
                select mid, pid FROM method, par 
                RETURNING mid)
                SELECT * FROM mpar;


-- It is expensive as it parses a SQL query internally 
CREATE OR REPLACE FUNCTION swarmops_solve(sl_solver_arg) RETURNS SETOF record
AS '/home/laurynas/Projects/pgSolver/SwarmSolver/solversw.so' 
LANGUAGE C STABLE STRICT;

-- Test call to solve in C
delete from sl_solver cascade;
WITH solver AS (insert into sl_solver(name, description)
                values ('swarmops','asdfjgh asdjkgh asdjkghjkasdfgh jkasdhj asdgf asdfasdgfgasdj gfasdf gdjkasfhasdjk hgjk asdhgasdhgjkasdhgjk hasdkgj') 
                returning sid),
     method AS (insert into sl_solver_method(sid,name, func_name, description)
                select sid, 'rnd','swarmops_solve', 'asjdfghsdfgh asdfgjkasdf ghasdjk ghasdjk jk hsdfgasdfggjfdgh dfjkghsdfk fkg sdfjkghsdfkgh jksfhdgjksdfhjkgh sdf' from solver 
                returning mid),
     par1    AS (insert into sl_parameter(name, type, description)
                values ('n' , 'int', 'Number of iterations to run') 
                RETURNING pid),
     par2    AS (insert into sl_parameter(name, type, description, value_default)
                values ('rndseed' , 'int', 'A number to seed the random number generator', '12') 
                RETURNING pid),                
     mpar1   AS (insert into sl_solver_param(sid, pid)
                select mid, pid FROM method, par1 
                RETURNING sid),
     mpar2   AS (insert into sl_solver_param(sid, pid)
                select mid, pid FROM method, par2
                RETURNING sid)
                SELECT * FROM solver, method, par1, par2, mpar1, mpar2;

select sl_get_paramhelp(1, false);

select sl_get_solverhelp('swarmops');

select 5<=sl_ctr_make(50, 'eq', 'test'::text);


select sl_get_wordwrap('sdfg jasdjgfsd sdhfsdgh fhsdghf sdhf hsdfhg asdg sd', 5);



SELECT sl_get_attributes('SELECT 1');
SELECT 'undefined'::sl_attribute_kind;

SHOW client_min_messages;

SELECT * FROM sl_solve(ROW(
           ROW('SELECT * FROM (VALUES (10,20,30),(30,40,50),(50,60,70),(60,70,80)) AS V(a,b,c)', 
               'name', 
               ARRAY['a', 'c']::text, 
               'undefined', 
               '', 
               ARRAY[]::text[])::sl_problem, 
           'test_solver', 
           'test_method')::sl_solve_query,
            ARRAY[ARRAY['par1', '1']::text[]]::text[][]
           ) AS (aaa int4, bbb int4, ccc int4);


           SOLVESELECT bla IN (SELECT NULL AS bla) AS T
           WITH test_solver.test_method(par1:=(SELECT 1));

SET log_statement='all'
SET log_min_messages='DEBUG5'


select generate_series(1,4), generate_series(2,10)

SOLVE val IN (SELECT i, val, cost, c1, c2, c3 FROM tbl LIMIT 10000000) AS t
MINIMIZE  (SELECT sum(val*c1) FROM t)
SUBJECTTO (SELECT 0<=val<=100 FROM t)
WITH solverlp;

SOLVE b, c IN (SELECT a::int, b::int4, c::int4
	       FROM (VALUES (10,20,30),(30,40,50),(10,20,30),(30,40,50),(10,20,30),(30,40,50),(10,20,30),(30,40,50)) AS V(a,b,c)
	      ) AS name
MINIMIZE  (SELECT sum(b+c) FROM name)
SUBJECTTO (SELECT 10<=b<=100, 10<=c<=100 FROM name)
WITH solverlp;

SOLVE x in (select a,x::float8 from (values (1,NULL),(2,NULL),(4,NULL)) as t(a,x)) AS t  
MINIMIZE (select -sum(x)+100000 from t) 
SUBJECTTO (select 0<=x<=100 from t)
WITH swarmops.pso;

SELECT * FROM (
   SOLVE fval IN (SELECT * FROM sudoku_tmp) as sudoku
   SUBJECTTO (SELECT fval = giv FROM sudoku WHERE giv),
	  (SELECT sum(fval)=1 FROM sudoku GROUP BY col, row),
	  (SELECT sum(fval)=1 FROM sudoku GROUP BY val, row),
	  (SELECT sum(fval)=1 FROM sudoku GROUP BY val, col),
	  (SELECT sum(fval)=1 FROM sudoku GROUP BY val, ((col-1) / 3), ((row-1) / 3))
   WITH solverlp) s
WHERE fval
ORDER BY col, row;

DROP EXTENSION SOLVERAPI CASCADE;

SOLVE b, c IN (SELECT * 
	       FROM (VALUES (10,20,30),(30,40,50),(50,60,70),(60,70,80)) AS V(a,b,c)
	      ) AS name
MAXIMIZE  (SELECT sqrt(b/c) FROM name)
SUBJECTTO (select 1),
	  (select 1)
WITH "test_solver"."test_method"
-- (n := 150);


SOLVE b, c IN (SELECT * 
	       FROM (VALUES (10,20,30),(30,40,50),(50,60,70),(60,70,80)) AS V(a,b,c)
	      ) AS name
MAXIMIZE  (SELECT sqrt(b/c) FROM name)
SUBJECTTO (select 1),
	  (select 1)
WITH "test_solverC"."test_methodC"(par1 := (SELECT 1::int4));



select 1 FROM name (SELECT * FROM aaa) AS name;

-- PREPARE aaa(anyarray) AS SELECT ($1[sl_id_0 + (0 * 4)])::integer AS b,($1[sl_id_0 + (1 * 4)])::integer AS c,a FROM sl_input_0;


SELECT ARRAY[ARRAY[]::text[], ARRAY[]::int[]];


SELECT ((id - 1) * 1 + 1) AS a,basa FROM (SELECT (row_number() OVER ()) AS id, * FROM (SELECT * FROM (SELECT 1::int4 AS a, 2 AS basa) AS S ORDER BY a) AS input) AS sub

SELECT * FROM fos WHERE fid = $1;

SELECT * FROM aaa;
DROP TABLE aaa CASCADE;


DROP FUNCTION test_solver_method1(sl_solver_arg);

CREATE OR REPLACE FUNCTION test_solver_method1(arg sl_solver_arg) RETURNS setof record AS $$
  BEGIN
     RAISE NOTICE '%', (sl_build_dst_values(arg, sl_build_out(arg))).sql;
     PERFORM sl_create_view(sl_build_out(arg), 'myview');
     CREATE TEMP TABLE aaa AS SELECT * FROM myview;
     --RAISE NOTICE '%', (SELECT (sl_id_0 * 1)::int AS var_nr, (b)::text AS value FROM (SELECT * FROM sl_input_0) AS S UNION SELECT (sl_id_0 * 2)::int AS var_nr, (c)::text AS value FROM (SELECT * FROM sl_input_0) AS S);
     -- PERFORM sl_create_view_on_input(arg, 'solver_input');
     -- RETURN QUERY EXECUTE sl_return_sql(arg, sl_build_src_func1subst(arg,'100+abs'));
     RETURN QUERY EXECUTE sl_return(arg, sl_build_out(arg));
     -- RETURN QUERY EXECUTE sl_return_table(arg, arg.tmp_name);  -- SELECT * FROM solver_input;
     -- PERFORM sl_drop_view(arg, 'solver_input');
     PERFORM sl_drop_view('myview');
  END;
$$ LANGUAGE plpgsql VOLATILE STRICT;

select * from aaa;



WITH asas AS (SELECT 1::int AS A, 2::float, 3::text AS B)
SELECT A FROM asas
UNION 
SELECT B FROM asas;



-- SELECT * FROM test_solver_method1(NULL::sl_solver_arg) AS (aaa sl_solver_arg);

SELECT * FROM test_solver_method1(ROW(
           'call',
            ROW('VALUES (1), (2)', 
               'name', 
               ARRAY['c1']::text, 
               'undefined', 
               '', 
               ARRAY[]::text[])::sl_problem,            
               NULL::sl_parameter_value[])::sl_solver_arg) AS (a int4);

/* Functions to be used in solver bootstrapping */ 

/* Functions to be used by the solver */ 
/* CREATE FUNCTION sl_is_param_set(sl_solver_param, name) RETURNS boolean
AS ''
LANGUAGE SQL IMMUTABLE STRICT;

CREATE FUNCTION sl_get_param_textvalue(sl_solver_param, name) RETURNS text
AS ''
LANGUAGE SQL IMMUTABLE STRICT;

CREATE FUNCTION sl_get_param_intvalue(sl_solver_param, name) RETURNS int
AS ''
LANGUAGE SQL IMMUTABLE STRICT;

CREATE FUNCTION sl_get_param_floatvalue(sl_solver_param, name) RETURNS float
AS ''
LANGUAGE SQL IMMUTABLE STRICT;


DROP FUNCTION test(int[], float[]);
CREATE FUNCTION test(ind int[], val float[]) 
RETURNS setof record as
$$
 select ind,
 
$$ LANGUAGE SQL;


select * from (select (row_number() over ())-1 AS id, * from (values(10),(20),(30),(40),(50), (60)) as subquery(V)) AS q
	      INNER JOIN (select (ARRAY[1,3,5])[s] AS unr, s as aind from generate_series(1,3) as s) as i 
	      ON q.id = (i.unr);





DROP FUNCTION fff(text);
CREATE FUNCTION fff(text) RETURNS  setof record as
$$
values(1),(2);
$$ LANGUAGE SQL;

DO $$
BEGIN
EXECUTE 'SELECT count(*) FROM (values(1),(2)) as s';
END;
$$ LANGUAGE plpgsql;




MODIFY aaa AS (WITH aaa AS (Select 1 a) SELECT * FROM aaa)
(
);
/*
-- Objective/constraint function class
CREATE TABLE sl_problem_func_class
(
    id		  int PRIMARY KEY		-- ID, there's no order of problems on this attribute
    name	  varchar(127) NOT NULL, 	-- Name of the function class
)

INSERT INTO sl_problem_func_class(id, name)	
VALUES (-1, "undefined"),			-- A function is undefined
       ( 0, "any"),				-- A function is of any type, e.g., non-linear
       ( 1, "linear"),				-- A function is linear
       ( 2, "quadratic"),			-- A function is quadratic
       ( 3, "convex")				-- A function is convex
   

-- A sequence and a table defining a problem class, e.g. Linear programming
CREATE SEQUENCE sl_problem_class_id_seq START 100;
CREATE TABLE sl_problem_class
(
    id		  INT DEFAULT nextval('sl_problem_class_id_seq') PRIMARY KEY,  -- ID of the problem class    
    name	  varchar(255) NOT NULL, 	   		-- A name of the problem class    
    obj_fn_class  int NOT NULL references sl_function_class(id),-- A class of the objective function in the general case
    obj_multi_opt boolean NOT NULL DEFAULT true,		-- Does the objective function can contain multiple maxima or minima
    obj_cont      boolean NOT NULL DEFAULT false,		-- Is the objective function continuous
    obj_different boolean NOT NULL DEFAULT false,		-- Can derivatives be found for the objective function at each point 
    ctr_fn_class  int NOT NULL references sl_function_class(id),-- A class of the constraint functions in the general case
    ctr_cont      boolean NOT NULL DEFAULT false,		-- Is the constraint function continuous?
    ctr_different boolean NOT NULL DEFAULT false,		-- Can derivatives be found for the constraint function at each point
    ctr_bound	  boolean NOT NULL DEFAULT false,		-- Does constraints defines lower and upper bounds of variable
)

INSERT INTO sl_problem_class(id, name, obj_fn_class, obj_multi_opt, obj_cont, obj_different, ctr_fn_class, ctr_cont, ctr_different, ctr_bound)
VALUES (1, "Linear Programming",		     1, false, true,   true, 1, true,  true,  false),		
       (2, "Mixed Integer Linear Programming",       1, false, false, false, 1, true,  true,  false),
       (3, "Quadratic Programming",                  2, false, false, false, 1, true,  true,  false),
       (3, "Global Optimization",                    0, true,  false, false, 0, false, false, false),
       

-- unk_att_type  varchar(127) NOT NULL, 		   	-- Name of a Postgres type of an unknown attribute, e.g., int4, float8.
								-- The actual type must be coercible to "unk_att_type".    
-- TODO: make automatic detection of the problem type */
*/