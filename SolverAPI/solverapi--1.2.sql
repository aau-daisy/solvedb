-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION solverapi" to load this file. \quit

-- Adjust this setting to control where the objects get created. SET LOCAL search_path TO @extschema@;

-- Basic utility functions to work with dynamic queries

-- This defines alternative attribute kinds in a relation with unknown variables
DROP TYPE IF EXISTS sl_attribute_kind CASCADE;
CREATE TYPE sl_attribute_kind AS ENUM ('undefined',	-- An attribute kind is not detected yet
				       'id', 		-- This is an ID of an input relation
				       'unknown', 	-- An attribute defines unknown variables
				       'known'); 	-- An attribute defines known variables


-- This defines the supported types for time series features
CREATE TYPE sl_supported_time_types AS ENUM ('timestamp', 
					'timestamp without time zone',
					'timestamp with time zone',
					'date',
					'time',
					'time with time zone',
					'time without time zone');


-- This type describes target attributes of a dynamic query
DROP TYPE IF EXISTS sl_attribute_desc CASCADE;
CREATE TYPE sl_attribute_desc AS
(
	att_name	name,             -- Name of an attribute
	att_type	name,             -- Type of an atrribute
	att_kind	sl_attribute_kind -- Defines a kind of an attribute
);

-- A type defining a parameter type
DROP TYPE IF EXISTS sl_parameter_type CASCADE;
CREATE TYPE sl_parameter_type AS ENUM ('int', 'float', 'text');

-- A parameter-value type
DROP TYPE IF EXISTS sl_parameter_value CASCADE;
CREATE TYPE sl_parameter_value AS (
    param		name,		-- Parameter name
    value_i		int,		-- A parameter value as int
    value_f		float,		-- A parameter value as float, i.e., double precision
    value_t		text		-- A parameter value as text
);


-- A type defining an objective direction, if any
DROP TYPE IF EXISTS sl_obj_dir CASCADE;
CREATE TYPE sl_obj_dir AS ENUM ('undefined', 'maximize', 'minimize');

-- A Common Table Expression (CTE) relations used in SOLVESELECT
DROP TYPE IF EXISTS sl_CTE_relation CASCADE;
CREATE TYPE sl_CTE_relation AS 
(
	 input_sql  	text,    -- An SQL query defining a relation with unknown variables (input)
	 input_alias	name, 	 -- An alias for SQL query to be used in objective and constraints SQLs
	 cols_unknown	name[] 	 -- Columns defining unknowns in the table, a list of "name"
);


-- A type defining an optimization problem to solve
DROP TYPE IF EXISTS sl_problem CASCADE;
CREATE TYPE sl_problem AS 
(
	input_sql	text,  		-- An SQL query defining a relation with unknown variables (input)
	input_alias	name, 		-- An alias for SQL query to be used in objective and constraints SQLs
	cols_unknown	name[], 	-- Columns defining unknowns in the table, a list of "name"
	obj_dir 	sl_obj_dir,	-- The direction of objective function
	obj_sql		text,		-- The SQL statement defining objective function
	ctr_sql		text[],		-- A list of SQL statements defining constraints/inequalities
	ctes		sl_CTE_relation[] -- Common Table Expressions used, if any
);

-- A type to define a solve query. To be used when invoking SOLVE statement
DROP TYPE IF EXISTS sl_solve_query CASCADE;
CREATE TYPE sl_solve_query AS
(
	problem 	sl_problem, 				-- Problem to solve
	solver_name	name,					-- A name of a solver
	method_name	name 					-- A name of the method (optional)
);


-- Types to be used when calling a specific solver

-- An object of such type to be passed to every solver-method on SOLVE call
DROP TYPE IF EXISTS sl_solver_arg CASCADE;
CREATE TYPE sl_solver_arg AS
(
	api_version	int,					-- A version number of API that calls a solver. 
								--  MAJOR =  floot(api_version / 100) - changes when existing API changes
								--  MINOR =  api_version % 100        - changes when new functionality added

	solver_name	name,					-- A name of a solver
	method_name	name,					-- An (auto detected) name of solver method
	params		sl_parameter_value[],			-- A postprocessed array of solver and method parameter-value pairs
	problem		sl_problem, 				-- An initial query
	prb_colcount	int,					-- A number of columns with unknown variables
	prb_rowcount	bigint,					-- A number of rows in an input relation
	prb_varcount	bigint,					-- A number of unknown variables count
	tmp_name	name,					-- A name of a temporal table storing an input
	tmp_id		name,					-- A name of an primary column of a temporal table
	tmp_attrs	sl_attribute_desc[]			-- An array of all attributes in temporal table
);

-- ********************************* SolverAPI's catalog tables *************************************************
-- Define all parameters of a solver and a solver method
CREATE TABLE sl_parameter
(
    pid			serial PRIMARY KEY,
    name		name NOT NULL,		      -- A parameter name
    type		sl_parameter_type NOT NULL,   -- A type of the variable, e.g., varchar
    description		text NOT NULL, 		      -- Description    
    value_default	text, 	 		      -- Default value represented as text
    value_min		numeric, 		      -- Minimum numeric value
    value_max		numeric,  		      -- Maximum numeric value
    push_default	boolean NOT NULL DEFAULT true,-- If true, the default value will be pushed to solver/method (if not NULL)
    -- Constraint on the default value
    CONSTRAINT default_valid_min CHECK (CASE WHEN type!='text' THEN value_default::numeric >= value_min END), 
    -- Constraint on the default value
    CONSTRAINT default_valid_max CHECK (CASE WHEN type!='text' THEN value_default::numeric <= value_max END)
);

CREATE TABLE sl_solver
(
    sid               serial PRIMARY KEY,  	    -- ID of the solver
    name	      name NOT NULL UNIQUE, 	    -- A name of the solver
    version	      real NOT NULL DEFAULT 1.0,
    default_method_id int DEFAULT NULL,
    author_name       varchar(255),
    author_email      varchar(255),
    author_url        varchar(1025), 		    -- An URL to download the solver
    description	      text  		  	    -- The description of the solver
);

-- Define all parameters of the solver
CREATE TABLE sl_solver_param
(
    sid		int,
    pid		int, 

    PRIMARY KEY (sid, pid),
    FOREIGN KEY (sid) 	   REFERENCES sl_solver (sid) ON UPDATE CASCADE ON DELETE CASCADE, 
    FOREIGN KEY (pid) 	   REFERENCES sl_parameter (pid) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE sl_solver_method
(
    mid		  	serial PRIMARY KEY, 		 -- solver method ID of the solver method
    sid		  	int REFERENCES sl_solver (sid) ON UPDATE CASCADE ON DELETE CASCADE,-- Solver's ID
    name	  	name NOT NULL,			 -- A name of the method
    name_full	  	text,				 -- A full name of the method
    func_name	  	name NOT NULL, 	 	 	 -- A name of PG function implementing the method
    prob_name	  	varchar(127),			 -- A name of the problem the method solves, e.g., LP problem
    description	  	text,		 	 	 -- The description of the method
    auto_rewrite_ctes	boolean NOT NULL DEFAULT true,		 -- Should SolveAPI automatically rewrite CTEs with decision variables to CTEs without variables
    
    UNIQUE (sid, name)			-- To enable fast string look-ups and ensure uniqeness
);

-- TODO: Alter the solver DEFAULT NULL REFERENCES sl_solver_method(mid), -- An ID of the default solver method

-- Define all parameters of the solver
CREATE TABLE sl_solver_method_param
(
    mid		int,
    pid		int, 

    PRIMARY KEY (mid, pid),
    FOREIGN KEY (mid) REFERENCES sl_solver_method (mid) ON UPDATE CASCADE ON DELETE CASCADE, 
    FOREIGN KEY (pid) REFERENCES sl_parameter (pid) ON UPDATE CASCADE ON DELETE CASCADE
);

-- A sequence for generating unique solver-related column names
DROP SEQUENCE IF EXISTS sl_colname_seq;
CREATE SEQUENCE sl_colname_seq CYCLE;
DROP SEQUENCE IF EXISTS sl_tblname_seq;
CREATE SEQUENCE sl_tblname_seq CYCLE;

-- This gets a unique column name 
CREATE OR REPLACE FUNCTION sl_get_unique_colname() RETURNS name AS $$
 SELECT ('sl_col_' || nextval('sl_colname_seq')::name)::name;
$$ LANGUAGE SQL VOLATILE;

-- Get unique table name
CREATE OR REPLACE FUNCTION sl_get_unique_tblname() RETURNS name AS $$
 SELECT ('sl_tbl_' || nextval('sl_tblname_seq')::name)::name;
$$ LANGUAGE SQL VOLATILE;


-- ***************************** FUNCTIONS ************************************************************

-- Gets the version of SolverAPI, current release is 1.20
CREATE OR REPLACE FUNCTION sl_get_apiversion() RETURNS int AS 'SELECT 120' LANGUAGE SQL STABLE STRICT;

-- Gets a set of attributes provided an SQL query.
-- It is expensive as it parses a SQL query internally 
CREATE OR REPLACE FUNCTION sl_get_attributes_from_sql(text) RETURNS SETOF sl_attribute_desc
AS 'MODULE_PATHNAME'
LANGUAGE C STABLE STRICT;

-- A dummy "non-solving" solver written in C to test the SolverAPI routines
CREATE OR REPLACE FUNCTION sl_dummy_solve(sl_solver_arg) RETURNS SETOF record
AS 'MODULE_PATHNAME'
LANGUAGE C STABLE STRICT;

-- A function to create a temporal table in security-restricted environment (of PostgreSQL 9.3.1)
CREATE OR REPLACE FUNCTION sl_createtmptable_unrestricted(text, text) RETURNS int8
AS 'MODULE_PATHNAME'
LANGUAGE C STABLE STRICT;

-- Checks if a table exists
CREATE OR REPLACE FUNCTION sl_is_table_created(tbl_name name) RETURNS boolean AS $$
 SELECT count(*)>0
 FROM information_schema.columns
 WHERE table_name = tbl_name;
$$ LANGUAGE SQL STABLE STRICT;

-- Gets a set of attributes provided a table name
CREATE OR REPLACE FUNCTION sl_get_attributes_from_table(tbl_name name) RETURNS SETOF sl_attribute_desc AS $$
 SELECT ROW(column_name, udt_name || COALESCE('(' || character_maximum_length || ')',''), 'undefined'::sl_attribute_kind)::sl_attribute_desc
 FROM information_schema.columns
 WHERE table_name = tbl_name;
$$ LANGUAGE SQL STABLE STRICT;

-- Gets a set of attributes provided a solver argument
CREATE OR REPLACE FUNCTION sl_get_attributes(arg sl_solver_arg) RETURNS SETOF sl_attribute_desc AS $$
   SELECT arg.tmp_attrs[i] AS p FROM generate_subscripts(arg.tmp_attrs, 1) AS i	ORDER BY i ASC
$$ LANGUAGE SQL IMMUTABLE STRICT;



-- ******************** Utility functions to be used in custom solvers ****************************

-- ******************** Geters to simplify formulation of sub-sequent queries *********************
-- Parameter utils. To get solver parameter values
CREATE OR REPLACE FUNCTION sl_param_get_as_int(arg sl_solver_arg, parname name) RETURNS INT AS $$
        SELECT (s.p).value_i 
        FROM (SELECT arg.params[i] AS p FROM generate_subscripts(arg.params, 1) AS i) AS s
	WHERE (s.p).param = parname;
$$ LANGUAGE SQL STABLE STRICT;

CREATE OR REPLACE FUNCTION sl_param_get_as_float(arg sl_solver_arg, parname name) RETURNS float AS $$
        SELECT (s.p).value_f
        FROM (SELECT arg.params[i] AS p FROM generate_subscripts(arg.params, 1) AS i) AS s
	WHERE (s.p).param = parname;
$$ LANGUAGE SQL STABLE STRICT;

CREATE OR REPLACE FUNCTION sl_param_get_as_text(arg sl_solver_arg, parname name) RETURNS text AS $$
        SELECT (s.p).value_t
        FROM (SELECT arg.params[i] AS p FROM generate_subscripts(arg.params, 1) AS i) AS s
	WHERE (s.p).param = parname;
$$ LANGUAGE SQL STABLE STRICT;

-- Dynamically generates a solve select query
CREATE OR REPLACE FUNCTION sl_generate_solve_query(query sl_solve_query, par_val_pairs text[][] DEFAULT NULL::text[][]) RETURNS text AS $$
  SELECT format('SOLVESELECT %s IN (%s) AS %s %s %s %s USING %s(%s)', 
	    (SELECT string_agg(c, ',') FROM unnest((query.problem).cols_unknown) AS c),  -- Unknown attribute list
	    (query.problem).input_sql, 						     -- Input relation
	    (query.problem).input_alias,						     -- Input relation alias
	    CASE WHEN array_length((query.problem).ctes, 1) > 0 			     -- CTE clause
	         THEN format('WITH %s', 
		  (SELECT string_agg(format('%s (%s) AS %s',
		    (CASE WHEN array_length(c.cols_unknown, 1) > 0
		          THEN format('%s IN', (SELECT string_agg(u, ',') FROM unnest(c.cols_unknown) AS u))
		          ELSE ''
		     END),
		     c.input_sql,
		     c.input_alias), ',') 
		   FROM unnest((query.problem).ctes) AS c))
	         ELSE ''
	    END,
	    CASE WHEN (query.problem).obj_dir = 'undefined' THEN '' 		     -- MAXIMIZE/MINIMIZE clause			           		     
	         WHEN (query.problem).obj_dir = 'maximize' 
		 THEN format('MAXIMIZE (%s)', (query.problem).obj_sql)
	         WHEN (query.problem).obj_dir = 'minimize' 
		 THEN format('MINIMIZE (%s)', (query.problem).obj_sql)
	    END,			            
	    CASE WHEN array_length((query.problem).ctr_sql, 1) > 0			     -- SUBJECTTO clause	
	         THEN format('SUBJECTTO %s', 
		  (SELECT string_agg(format('(%s)', c), ',')
		   FROM unnest((query.problem).ctr_sql) AS c))
	         ELSE ''
	    END,
	    format('%s%s', query.solver_name, CASE WHEN query.method_name = '' THEN ''   -- Solver/method clause
			           ELSE format('.%s', query.method_name)
			      END), 				     
	    (SELECT string_agg(CASE WHEN (par_val_pairs[i][2] IS NULL) OR (par_val_pairs[i][2] = '') 
			THEN par_val_pairs[i][1]
			ELSE format('%s:=''%s''', par_val_pairs[i][1], par_val_pairs[i][2]) END, ',') 
	     FROM generate_subscripts(par_val_pairs, 1) AS i)									     -- Solver parameter clause
                )
$$ LANGUAGE sql IMMUTABLE;

-- Create a fixed view or solver parameters
CREATE OR REPLACE FUNCTION sl_create_paramview(arg sl_solver_arg, viewname name) RETURNS boolean AS $$
 BEGIN
   EXECUTE format('CREATE TEMP VIEW %s AS SELECT * FROM (VALUES %s) AS v(pid, param, value_i, value_f, value_t)', quote_ident(viewname), 
   (SELECT string_agg(format('(%s, %s, %s, %s, %s)', 
                        pid, quote_nullable((arg.params[pid]).param), quote_nullable((arg.params[pid]).value_i), 
                        quote_nullable((arg.params[pid]).value_f), quote_nullable((arg.params[pid]).value_t)), ',')
    FROM generate_subscripts(arg.params, 1) AS pid));
   RETURN TRUE;
 END   
$$ LANGUAGE plpgsql VOLATILE STRICT;


-- **************** All sorts of dynamic query (ViewSQL) generating/manipulation functions ********************************

-- INFO: 
-- To ease the development of a solver for a specific optimization problem, we build a 2 level view system on top of the input relation:
--
-- DESTINATION (MODEL) LEVEL  :             	         [Value] [Objective] [Constraint][Constraint Union]
--                                                                            ||
-- OUTPUT (SUBSTITUTION) LEVEL: 	[] [User-defined] [Variable] [Function Map] [Function Substitution] [Array Substitution] [Rename] [Join] [Join Value]
--          		                                                      ||          
-- INPUT LEVEL                :                                      [INPUT (TMP table)] 
--

-- These types represent sql commands to build source and destination level views. 
-- They are typedef's of "text" to ensure strong typing in subsequent functions
CREATE TYPE sl_viewsql_out AS (sql text); -- Source view is required to have the same set of columns as the input relation
CREATE TYPE sl_viewsql_dst AS (sql text);

CREATE FUNCTION sl_viewsql_to_text(s sl_viewsql_out) RETURNS text AS $$ SELECT s.sql; $$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE FUNCTION sl_viewsql_to_text(s sl_viewsql_dst) RETURNS text AS $$ SELECT s.sql; $$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE CAST (sl_viewsql_out AS text) WITH FUNCTION sl_viewsql_to_text(sl_viewsql_out) AS IMPLICIT;
CREATE CAST (sl_viewsql_dst AS text) WITH FUNCTION sl_viewsql_to_text(sl_viewsql_dst) AS IMPLICIT;


-- Constructor functions that allows builing source and destination views

-- ************************************ Output LEVEL views *********************************

-- []
-- Builds a view sql on the input relation (original temp. table). 
CREATE OR REPLACE FUNCTION sl_build_out(arg sl_solver_arg) RETURNS sl_viewsql_out AS $$
	SELECT ROW(format('SELECT * FROM %s', arg.tmp_name))::sl_viewsql_out;
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- [Default value columns] 
-- Builds a view sql on the input relation (original temp. table), additionally adding (or overriding) specified columns with their default values. 
-- E.g., when colvalues=[['col1','val1'], ['col2', 'val2']], the
-- the returned SQL builds the relation:
--       SL_ID, U1, U2, U3, col1, col2, 
--           1,  1,  1,  1, val1, val2,
--           2,  2,  2,  2, val1, val2,
--           3,  3,  3,  3, val1, val2,
--          ..........................
--           n,  n,  n,  n, val1, val2
CREATE OR REPLACE FUNCTION sl_build_out_defcols(arg sl_solver_arg, colvalues text[][], base sl_viewsql_out DEFAULT NULL) RETURNS sl_viewsql_out AS $$
	SELECT ROW(format('SELECT %s FROM %s', 	        
	        array_to_string(
	        ARRAY[   -- All other columns
		        (SELECT string_agg(quote_ident(a.att_name), ',')
			 FROM unnest(arg.tmp_attrs) AS a
			 WHERE a.att_name NOT IN (SELECT colvalues[i][1] FROM generate_subscripts(colvalues, 1) AS i)),
			 
                         -- Default-value columns
			(SELECT string_agg(format('%s AS %s', colvalues[i][2], quote_ident(colvalues[i][1])), ',')
 			 FROM generate_subscripts(colvalues, 1) AS i)
			 
			], ','),
		        -- Input relation (tmp. table)
		        CASE WHEN base IS NULL THEN arg.tmp_name ELSE format('(%s) AS s', base.sql) END
	          ))::sl_viewsql_out;	         
$$ LANGUAGE SQL IMMUTABLE;

-- [User-defined] 
-- Builds a view sql on the input relation (original temp. table). 
-- The user sql must yield a relation with the same columns as the input relation (including id column).
CREATE OR REPLACE FUNCTION sl_build_out_userdefined(arg sl_solver_arg, user_sql text) RETURNS sl_viewsql_out AS $$
	SELECT ROW(format('SELECT %s FROM (%s) AS s', 
		(SELECT string_agg(quote_ident(arg.tmp_attrs[i].att_name), ',')
	         FROM generate_subscripts(arg.tmp_attrs, 1) AS i), 
	         user_sql))::sl_viewsql_out;
$$ LANGUAGE SQL IMMUTABLE STRICT;


-- [Variable]
-- Build and SQL statement to generate unknown variables table.
-- E.g., when U1, U2, U3 are attributes of unknown variables, A1, A2 are regular attributes, the
-- the returned SQL builds the relation:
--       SL_ID, U1,  U2,  U3,   A1,  A2, 
--           1,  1,  n+1, 2n+1, a11, a21,
--           2,  2,  n+2, 2n+2, a12, a22,
--           3,  3,  n+3, 2n+3, a13, a23,
--        ........................
--        n,   2n, 3n,   a1n, a2n
CREATE OR REPLACE FUNCTION sl_build_out_vars(arg sl_solver_arg) RETURNS sl_viewsql_out AS $$
	SELECT ROW(format('SELECT %s, %s FROM %s',
		  arg.tmp_id,
		  array_to_string(
		  ARRAY[
		     -- Build substitution for unknown variables
	             (SELECT string_agg(format('(%s + (%s * %s)) AS %s', 
			                      arg.tmp_id, 
					     (att_nr - 1)::text, 
					      arg.prb_rowcount::text,
					      att_name), ',')
	              FROM (SELECT (row_number() OVER ()) AS att_nr, att_name, att_type 
	                    FROM sl_get_attributes(arg) AS A
	                    WHERE A.att_kind = 'unknown') AS S),
	              -- Simply list all rest attributes
	             (SELECT string_agg(att_name, ',') 
	              FROM sl_get_attributes(arg) AS A
	              WHERE A.att_kind = 'known')
	                ], ','),
		      arg.tmp_name))::sl_viewsql_out;
$$ LANGUAGE SQL IMMUTABLE STRICT;


-- [Function Map] Build a view SQL on where values of unknown-variable columns are computed by applying user-suplied 
-- functions f1, f2, ..., fN on a source relation serving as a base. Here, N is a number of unknown-variable columns. 
-- Each function takes a single argument as input and returns a value of an arbitrary type. 
-- Array parameter "funcs" specifies names of the functions f1, f2, ..., fN. 
-- 
-- E.g., when U1, U2 are attributes of unknown variables, A1, A2 are regular attributes, a_ij are values of a based ralation,
-- and funcs=["f1", "f5", "f9"], then the returned SQL builds the relation:
--       SL_ID, A1,       U1,       U2,       A2,   A3, 
--           1, f1(a_11), f5(a_21), f9(a_31), a_41, a_51,
--           2, f1(a_12), f5(a_22), f9(a_32), a_42, a_52,
--           3, f1(a_13), f5(a_23), f9(a_33), a_43, a_53,
--           ...........................................
--           n, f1(a_1n), f5(a_2n), f9(a_3n), a_4n, a_5n
CREATE OR REPLACE FUNCTION sl_build_out_funcNmap(arg sl_solver_arg, base sl_viewsql_out, funcs text[]) RETURNS sl_viewsql_out AS $$
	SELECT ROW(format('SELECT %s, %s FROM (%s) AS s',
		  arg.tmp_id,
		  array_to_string(
		  ARRAY[
		     -- Build substitution for unknown variables
	             (SELECT string_agg(format('%s(%s) AS %2$s', 
					      funcs[att_nr]::text,
					      att_name), ','
				       )
	              FROM (SELECT (row_number() OVER ()) AS att_nr, att_name, att_type 
	                    FROM sl_get_attributes(arg) AS A
	                    WHERE A.att_kind = 'unknown') AS S),
	              -- Simply list all rest attributes
	             (SELECT string_agg(att_name, ',') 
	              FROM sl_get_attributes(arg) AS A
	              WHERE A.att_kind = 'known')
	                ], ','),
		      base.sql))::sl_viewsql_out;
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- [Function Substitution] Build a view SQL where values of unknown-variable columns are computed using user-suplied 
-- functions f1, f2, ..., fN, where N is a number of unknown-variable columns. Each function takes a variable 
-- number as input and returns a value of an arbitrary type. Array parameter "funcs" specifies names of the
-- functions f1, f2, ..., fN. 
-- 
-- E.g., when U1, U2, U3 are attributes of unknown variables, A1, A2 are regular attributes, and funcs=["f1", "f5", "f9"], 
-- then the returned SQL builds the relation:
--       SL_ID, U1,    U2,      U3,       A1,  A2, 
--           1, f1(1), f5(n+1), f9(2n+1), a11, a21,
--           2, f1(2), f5(n+2), f9(2n+2), a12, a22,
--           3, f1(3), f5(n+3), f9(2n+3), a13, a23,
--           .....................................
--           n, f1(n), f5(2n),  f9(3n),   a1n, a2n
CREATE OR REPLACE FUNCTION sl_build_out_funcNsubst(arg sl_solver_arg, funcs text[]) RETURNS sl_viewsql_out AS $$
	SELECT sl_build_out_funcNmap(arg, sl_build_out_vars(arg),funcs)
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- [Function Substitution] Build a view SQL where values of unknown-variable columns are computed using a user-suplied 
-- function "func". The function takes a variable number as input and returns a value of an arbitrary type.
-- 
-- E.g., when U1, U2, U3 are attributes of unknown variables, A1, A2 are regular attributes, and func="f1", then
-- the returned SQL builds the relation:
--       SL_ID, U1,    U2,      U3,       A1,  A2, 
--           1, f1(1), f1(n+1), f1(2n+1), a11, a21,
--           2, f1(2), f1(n+2), f1(2n+2), a12, a22,
--           3, f1(3), f1(n+3), f1(2n+3), a13, a23,
--           ......................................
--           n, f1(n), f1(2n),  f1(3n),   a1n, a2n
CREATE OR REPLACE FUNCTION sl_build_out_func1subst(arg sl_solver_arg, func text) RETURNS sl_viewsql_out AS $$
	SELECT sl_build_out_funcNsubst(arg, array_fill(func, ARRAY[arg.prb_colcount]));
$$ LANGUAGE SQL IMMUTABLE STRICT;


-- [Array Substitution] Build a parametrized view SQL where values in unknown-variable columns are substituted with values from
-- N user defined arrays (of different types). The parameter "par_pos" is an array of size M, where a value V specifies a
-- number of an array parameter to use for a particular unknown column. Here, M is a number of unknown columns. 
-- 
-- E.g., when U1, U2, U3 are attributes of unknown variables, A1, A2 are regular attributes, and par_pos=[3,6,8], the 
-- returned SQL builds the relation:
--       SL_ID,  U1,    U2,      U3,       A1,  A2, 
--           1, $3[1], $6[n+1], $8[2n+1], a11, a21,
--           2, $3[2], $6[n+2], $8[2n+2], a12, a22,
--           3, $3[3], $6[n+3], $8[2n+3], a13, a23,
--           .....................................
--           n, $3[n], $6[2n],  $8[3n],   a1n, a2n
CREATE OR REPLACE FUNCTION sl_build_out_arrayNsubst(arg sl_solver_arg, par_pos int[]) RETURNS sl_viewsql_out AS $$
	SELECT ROW(format('SELECT %s, %s FROM %s',
		  arg.tmp_id,
		  array_to_string(
		  ARRAY[
		     -- Build substitution for unknown variables
	             (SELECT string_agg(format('($%s[%s + (%s * %s)])::%s AS %s', 
					      par_pos[att_nr]::text,
			                      arg.tmp_id, 
					     (att_nr - 1)::text, 
					      arg.prb_rowcount::text,
					      att_type,
					      att_name), ','
				       )
	              FROM (SELECT (row_number() OVER ()) AS att_nr, att_name, att_type 
	                    FROM sl_get_attributes(arg) AS A
	                    WHERE A.att_kind = 'unknown') AS S),
	              -- Simply list all rest attributes
	             (SELECT string_agg(att_name, ',') 
	              FROM sl_get_attributes(arg) AS A
	              WHERE A.att_kind = 'known')
	                ], ','),
		      arg.tmp_name))::sl_viewsql_out;
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- [Array Substitution] Build a parametrized view SQL where values in unknown-variable columns are substituted with values from a 
-- user defined array. The array must be suplied as the "par_nr"-th parameter during the execution.
-- 
-- E.g., when $<par_nr> is an array parameter, par_nr=1, U1, U2, U3 are attributes of unknown variables, A1, A2 are regular attributes, 
-- the returned SQL builds the relation:
--       SL_ID,  U1,    U2,      U3,       A1,  A2, 
--           1,  $1[1], $1[n+1], $1[2n+1], a11, a21,
--           2,  $1[2], $1[n+2], $1[2n+2], a12, a22,
--           3,  $1[3], $1[n+3], $1[2n+3], a13, a23,
--           ......................................
--           n,  $1[n], $1[2n],  $1[3n],   a1n, a2n
CREATE OR REPLACE FUNCTION sl_build_out_array1subst(arg sl_solver_arg, par_nr int DEFAULT 1) RETURNS sl_viewsql_out AS $$
	SELECT sl_build_out_arrayNsubst(arg, array_fill(par_nr, ARRAY[arg.prb_colcount]));
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- [Rename] Build a view SQL where names of id, unknown-variable, and remaining attribute columns are renamed.
-- 
CREATE OR REPLACE FUNCTION sl_build_out_rename(arg sl_solver_arg, base sl_viewsql_out, col_type sl_attribute_kind, col_alias text) RETURNS sl_viewsql_out AS $$
	SELECT format('SELECT %s, %s, %s FROM (%s) AS s',
		       CASE col_type 
			       WHEN 'id'::sl_attribute_kind THEN format('%s AS %s', quote_ident(arg.tmp_id), quote_ident(col_alias))
			       ELSE arg.tmp_id 
		       END,		       
		       (SELECT string_agg(att_name, ',')
	                FROM (SELECT att_name FROM sl_get_attributes(arg) WHERE att_kind = 'unknown') AS A),
		       (SELECT string_agg(att_name, ',')
	                FROM (SELECT att_name FROM sl_get_attributes(arg) WHERE att_kind = 'known') AS A),
		        base.sql
		     );
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- [Join] Build a view SQL where values in unknown-variable colums are substituted with values from a user defined query.
-- The query must be suplied as the parameter along with the id column name to join on and column mappings
--
-- E.g., when "base" represents relation S with columns SL_ID, U1, U2, A1, A2, and 
--            "sql" represents relation Q with columns "join_id_col", U1, U2, and
--  S:   SL_ID,  U1,   U2,   A1,   A2          Q:  join_id_col,  U1, U2
--           1,  u11, u21,  a11,  a21                        1, q11, q21
--           2,  u12, u22,  a12,  a22                        2, q12, q22
--           3,  u13, u23,  a13,  a23                        3, q13, q23
--           ........................                        ...............
--           n,  u1n, u2n,  a14,  a2n                        n, q1n, q2n
-- the resulting relation R represents the left outer join on ID fiels and values in unknown-variable columns overriden:
-- R:    SL_ID,  U1,   U2,   A1,   A2
--           1, q11,   q21, a11,  a21
--           2, q12,   q22, a12,  a22
--           3, q13,   q23, a13,  a23
--           ........................
--           n, q1n,   q2n, a1n,  a2n
CREATE OR REPLACE FUNCTION sl_build_out_join(arg sl_solver_arg, base sl_viewsql_out, sql text, join_id_col text) RETURNS sl_viewsql_out AS $$
	SELECT format('SELECT %s, %s FROM (%s) AS s LEFT OUTER JOIN (%s) AS q ON s.%s=q.%s',
	    arg.tmp_id,
	    (SELECT string_agg(format('%s.%s',	CASE (arg.tmp_attrs[i]).att_kind
							WHEN 'unknown'::sl_attribute_kind THEN 'q'
							ELSE 's'
						END,
						quote_ident((arg.tmp_attrs[i]).att_name)), ',')
	     FROM generate_subscripts(arg.tmp_attrs, 1) AS i), 
	    base.sql, sql,
	    quote_ident(arg.tmp_id), quote_ident(join_id_col));
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- TODO: debug version, documentation not complete
-- [Join] Performs the generic version of the following function (used for prediction solvers)
-- select * from (select * from table1) as r
-- union all 
-- select null as id, t2.time_t, t2.watt
-- from tmp_forecasting_table_input_schema as t2
-- left join Test as t1
-- on
-- t2.time_t = t1.time_t and
-- t2.watt = t1.watt
-- where t1.time_t is Null and t1.watt is Null;
drop function sl_build_union_right_join(sl_solver_arg, name[], name[], text);
CREATE OR REPLACE FUNCTION sl_build_out_union_right_join(arg sl_solver_arg, not_joining_clmns name[], 
	joining_clmns name[], sql text) RETURNS sl_viewsql_out 
AS $$ 
SELECT format('SELECT * FROM %s AS r UNION ALL SELECT %s, %s FROM %s AS q LEFT JOIN %s AS s ON %s WHERE %s',
		arg.tmp_name,
		(SELECT string_agg(format('null as %s',quote_ident(not_joining_clmns[i])), ',')
 		FROM generate_subscripts(not_joining_clmns, 1) AS i),
 		(SELECT string_agg(format('q.%s',quote_ident(joining_clmns[i])), ',')
 		FROM generate_subscripts(joining_clmns, 1) AS i),
 		sql,
 		arg.tmp_name,
 		(SELECT string_agg(format('q.%s = s.%s',quote_ident(joining_clmns[i]), 
 		quote_ident(joining_clmns[i])), ' AND ')
 		FROM generate_subscripts(joining_clmns, 1) AS i),
 		(SELECT string_agg(format('s.%s IS null',quote_ident(joining_clmns[i])), ' AND ')
 		FROM generate_subscripts(joining_clmns, 1) AS i));
$$ LANGUAGE SQL IMMUTABLE STRICT;


-- [Join Value] Build a view SQL where values in unknown-variable colums are substituted with values from a user defined query.
-- The user defined query must have a variable number and value columns. 
-- E.g., when "sql" represents relation Q with columns "var_nr", "values":
--  S:   SL_ID,  U1,   U2,   A1,   A2          Q:  var_nr, values
--           1,  u11, u21,  a11,  a21                   1, v1
--           2,  u12, u22,  a12,  a22                   2, v2
--           3,  u13, u23,  a13,  a23                   3, v3
--           ........................                   .....
--           n,  u1n, u2n,  a14,  a2n                   n, v2n
-- then, the output is the left-outer join:
-- R:    SL_ID,  U1,   U2,   A1,   A2
--           1,  v1,  vn+1, a11,  a21
--           2,  v2,  vn+2, a12,  a22
--           3,  v3,  vn+3, a13,  a23
--           ........................
--           n,  vn,   v2n, a1n,  a2n
CREATE OR REPLACE FUNCTION sl_build_out_joinvalues(arg sl_solver_arg, sql text, col_varnr text, col_value text) RETURNS sl_viewsql_out AS $$
	WITH unk_attr AS (SELECT (row_number() OVER ()) AS att_nr, att_name, att_type 
	                  FROM sl_get_attributes(arg) AS A
	                  WHERE A.att_kind = 'unknown'
	                  ORDER BY att_nr ASC)	
	SELECT ROW(format('WITH Q AS (%s) SELECT %s, %s FROM (%s) AS O%s',
		  sql,
		  arg.tmp_id,
		  array_to_string(ARRAY[
			   -- Simply list all rest attributes
			  (SELECT string_agg(att_name, ',') 
			   FROM sl_get_attributes(arg) AS A
			   WHERE A.att_kind = 'known'),	              
			   -- Build substitution for unknown variables
			  (SELECT string_agg(
					format('UNK%s.%s AS %s',
					att_nr::text, quote_ident(col_value), quote_ident(att_name)), ',') 
			   FROM unk_attr)], ','),
	          -- The base relation
	          (sl_build_out_vars(arg)).sql,
		  -- Build the join clause			   
		  (SELECT string_agg(
					format(' LEFT OUTER JOIN Q AS UNK%s ON UNK%1$s.%s=O.%s',
					att_nr::text, 
					quote_ident(col_varnr),
					quote_ident(att_name)), ' ')
		  FROM unk_attr)))::sl_viewsql_out;
$$ LANGUAGE SQL IMMUTABLE STRICT;


-- ************************************ Destination LEVEL views *********************************

-- [Value] Build an unknown variable table with values
-- E.g., when cast_to is 'text', then
-- 	 var_nr(int), value(text)
--       1,	      10
--	 2, 	      10.1
--	 3,	      'val3'
--	 4,	      '12.3' 
--       .................
CREATE OR REPLACE FUNCTION sl_build_dst_values(arg sl_solver_arg, vsout sl_viewsql_out, cast_to text DEFAULT 'text') RETURNS sl_viewsql_dst AS $$
	SELECT ROW((SELECT string_agg(
			      format('SELECT %s + (%s * %s)::int AS var_nr, (%s)::%s AS value FROM (%s) AS S',
				     (arg).tmp_id, (att_nr-1)::text, arg.prb_rowcount,att_name, quote_ident(cast_to), vsout.sql), ' UNION ALL ')
			     FROM (SELECT (row_number() OVER ()) AS att_nr, att_name
	                           FROM sl_get_attributes(arg) AS A
	                           WHERE A.att_kind = 'unknown') AS S)
		  )::sl_viewsql_dst;
$$ LANGUAGE SQL IMMUTABLE STRICT;



-- Generate the WITH clause for the destination (model) views. If present, fuses all CTE expressions and return the "WITH" expression. If no CTEs, then returns a WITH for the input relation
CREATE OR REPLACE FUNCTION sl_get_dst_prequery(problem sl_problem, vsout sl_viewsql_out) RETURNS text AS $$
 SELECT format('WITH %s AS (%s)%s', quote_ident(problem.input_alias), vsout.sql,
		(SELECT string_agg(format(', %s AS (%s)', quote_ident(c.input_alias), c.input_sql), '') FROM unnest(problem.ctes) as c ) )::text
$$ LANGUAGE sql;


-- [Objective] Build a view SQL to represent objective function aplied on a source view
CREATE OR REPLACE FUNCTION sl_build_dst_obj(arg sl_solver_arg, vsout sl_viewsql_out) RETURNS sl_viewsql_dst AS $$
	SELECT ROW(format('%s SELECT * FROM (%s) AS S', sl_get_dst_prequery(arg.problem, vsout), (arg.problem).obj_sql))::sl_viewsql_dst;
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- [Constraint] Build a view SQL to represent objective function aplied on a source view
-- "ctr_nr" - defines a constraint number
CREATE OR REPLACE FUNCTION sl_build_dst_ctr(arg sl_solver_arg, vsout sl_viewsql_out, ctr_nr int) RETURNS sl_viewsql_dst AS $$
	SELECT ROW(format('%s SELECT * FROM (%s) AS S', sl_get_dst_prequery(arg.problem, vsout), (arg.problem).ctr_sql[ctr_nr]))::sl_viewsql_dst;
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- [Constraint Union] Build a view SQL as a union of the same-type constraints aplied on a source view
CREATE OR REPLACE FUNCTION sl_build_dst_ctr_union(arg sl_solver_arg, vsout sl_viewsql_out, ctr_type text) RETURNS sl_viewsql_dst AS $$
        SELECT ROW(format('%s (SELECT ctr FROM (SELECT NULL::%s AS ctr) AS s WHERE s.ctr IS NOT NULL) %s', 
                                  sl_get_dst_prequery(arg.problem, vsout),
		  ctr_type,		
		  (SELECT string_agg(format('UNION ALL (SELECT * FROM (%s) AS S)', (arg.problem).ctr_sql[ctr_nr]), ' ')
		   FROM generate_subscripts((arg.problem).ctr_sql, 1) as ctr_nr)))::sl_viewsql_dst
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- ************************************* UTILITY FUNCTIONS *******************************************************


-- Get attributes of a CTE expression
CREATE OR REPLACE FUNCTION sl_get_CTEattributes(problem sl_problem, cte_alias text) RETURNS SETOF sl_attribute_desc AS $$
SELECT sl_get_attributes_from_sql(format('%s SELECT * FROM %s', sl_get_dst_prequery(problem, ROW(problem.input_sql)::sl_viewsql_out), cte_alias))
$$ LANGUAGE SQL STABLE STRICT;

-- This is the main solver output routine. It uses output-level view SQL and it generates an 
-- SQL statement to provide a correct output when returning data from a solver
CREATE OR REPLACE FUNCTION sl_return(arg sl_solver_arg, vsout sl_viewsql_out) RETURNS text AS $$
	SELECT format('SELECT %s FROM (%s) AS s',
	    (SELECT string_agg(format('%s::%s',quote_ident((arg.tmp_attrs[i]).att_name),
							   (arg.tmp_attrs[i]).att_type), ',')
	     FROM generate_subscripts(arg.tmp_attrs, 1) AS i
	     WHERE (arg.tmp_attrs[i]).att_kind != 'id'::sl_attribute_kind), vsout.sql);
$$ LANGUAGE SQL IMMUTABLE STRICT;


-- Create a fixed view using a destination view SQL. It works only if the view SQL does not require any parameters
CREATE OR REPLACE FUNCTION sl_create_view(dst sl_viewsql_dst, viewname name) RETURNS boolean AS $$
BEGIN
   EXECUTE format('CREATE TEMP VIEW %s AS %s', quote_ident(viewname), dst.sql);
   RETURN TRUE;
END;
$$ LANGUAGE plpgsql VOLATILE STRICT;

-- Create a fixed view using a source view SQL. It works only if the view SQL does not require any parameters
CREATE OR REPLACE FUNCTION sl_create_view(vsout sl_viewsql_out, viewname name) RETURNS boolean AS $$
BEGIN
   EXECUTE format('CREATE TEMP VIEW %s AS %s', quote_ident(viewname), vsout.sql);
   RETURN TRUE;
END;
$$ LANGUAGE plpgsql VOLATILE STRICT;

-- Drop a view, defined by viewname
-- For consistency with other methods, the method takes arg, but does not use it.
CREATE OR REPLACE FUNCTION sl_drop_view(viewname name) RETURNS boolean AS $$   
 BEGIN
   EXECUTE format('DROP VIEW %s', quote_ident(viewname));
   RETURN TRUE;    
 END;
$$ LANGUAGE plpgsql VOLATILE STRICT;

-- Drop a view with cascade, defined by viewname
CREATE OR REPLACE FUNCTION sl_drop_view_cascade(viewname name) RETURNS boolean AS $$   
 BEGIN
   EXECUTE format('DROP VIEW %s CASCADE', quote_ident(viewname));
   RETURN TRUE;    
 END;
$$ LANGUAGE plpgsql VOLATILE STRICT;


-- ******************** Main entrance/solve query processing functions ****************************************

-- Checks if a problem is correctly defined. 
-- Note, attribute resolution is an expensive. Thus we can reuse input query attributes.
CREATE OR REPLACE FUNCTION sl_problem_check(prob sl_problem, input_sql_attrs sl_attribute_desc[] DEFAULT NULL) RETURNS void AS $$ 
 DECLARE 
    ad     sl_attribute_desc;
    uattr  name;
    fnd  boolean;
 BEGIN
   IF (input_sql_attrs IS NULL) THEN
     SELECT array_agg(A::sl_attribute_desc) 
     FROM sl_get_attributes_from_sql(prob.input_sql) A 
     INTO input_sql_attrs; 
   END IF;

   IF (COALESCE(array_length(prob.cols_unknown, 1), 0) = 0) THEN 
	RAISE EXCEPTION 'Error retrieving input query columns'; 
   END IF;

   IF (COALESCE(array_length(prob.cols_unknown, 1), 0) = 0) THEN 
	RAISE EXCEPTION 'No attributes for unknown variables are specified'; 
   END IF;
      
   -- Let's do a nested loop to check validity of unknown attributes
   FOREACH uattr IN ARRAY prob.cols_unknown LOOP
     fnd = false;     
     FOREACH ad IN ARRAY input_sql_attrs LOOP
	fnd = (uattr = ad.att_name);
	EXIT WHEN fnd;
     END LOOP;
     
     IF (fnd = FALSE) THEN
        RAISE EXCEPTION 'The unknown attribute "%" is not found in the target list (%)', uattr, 
		         (SELECT string_agg(input_sql_attrs[i].att_name, ',') 
		          FROM generate_subscripts(input_sql_attrs,1) as i);
     END IF;
   END LOOP;    
 END;
$$ LANGUAGE plpgsql STABLE STRICT;
COMMENT ON FUNCTION sl_problem_check(sl_problem, sl_attribute_desc[]) IS 'Checks the correcness of an optimization problem';

-- A helper function to perform the word wrap provided the length of the string partition
CREATE OR REPLACE FUNCTION sl_get_wordwrap(str text, length integer DEFAULT 60) RETURNS setof text AS $$
   SELECT string_agg(t, ' ') FROM (
      SELECT t, (string_agg(t,' ') OVER (ORDER BY r)) as ta
      FROM (SELECT row_number() OVER () r, t 
            FROM regexp_split_to_table(str,  E'\\s+') t) s) s
   GROUP BY char_length(ta)/length;
$$ LANGUAGE sql STABLE STRICT;

-- Build a help string for a parameter
CREATE OR REPLACE FUNCTION sl_get_paramhelp(pid_value int, short_help boolean DEFAULT true) RETURNS text AS $$
 DECLARE 
   p_row       sl_parameter%ROWTYPE;
 BEGIN
   SELECT * INTO p_row FROM sl_parameter p WHERE p.pid = pid_value;
   IF (p_row IS NULL) THEN
      RETURN '';
   ELSE 
      IF (short_help) THEN
         RETURN p_row.name;
      ELSE
         RETURN format(E'%s(%s)%s%s:\r\n\t\t%s',
			p_row.name, 
			p_row.type, 
			(CASE WHEN (p_row.value_min IS NULL) AND (p_row.value_max IS NULL) THEN ''
			      ELSE format(E' IN [%s..%s]',p_row.value_min, p_row.value_max)
			 END),
			(CASE WHEN p_row.value_default IS NULL THEN ''
			      ELSE format(E' DEFAULT %s',p_row.value_default)
			 END),
			(SELECT string_agg(t, E'\r\n\t\t') /* Needed for pretty formatting */
		         FROM sl_get_wordwrap(p_row.description) t));
      END IF;
   END IF;
 END;
$$ LANGUAGE plpgsql STABLE STRICT;

-- Build a help string for a solver, solver-method, etc.
CREATE OR REPLACE FUNCTION sl_get_solverhelp(solver_name name DEFAULT NULL, method_name name DEFAULT NULL) RETURNS text AS $$
 DECLARE
  s_row       sl_solver%ROWTYPE;
  m_row       sl_solver_method%ROWTYPE;
  txt	      text;
  help	      text;
 BEGIN
  s_row = NULL;
  m_row = NULL;
  -- Searches for a solver, if specified
  IF ((solver_name IS NOT NULL) AND (char_length(solver_name) > 0)) THEN
     SELECT * INTO s_row FROM sl_solver WHERE name = solver_name;   
  END IF;
  -- Searches for a solver method, if specified
  IF ((NOT(s_row IS NULL)) AND (method_name IS NOT NULL) AND (char_length(method_name) > 0)) THEN
     SELECT * INTO m_row FROM sl_solver_method WHERE (sid = s_row.sid) AND (name = method_name);
  END IF;  
  -- Build a respective help message
  help = '';
  IF (s_row IS NULL) THEN
     -- Print a list of supported solvers
     SELECT string_agg(format(E' - %s[%s method(-s)]: %s', 
						     name,
						     (SELECT count(*) FROM sl_solver_method m WHERE (m.sid=s.sid)),						     
						     (SELECT string_agg(t, E'\r\n\t\t') /* Needed for pretty formatting */
						      FROM sl_get_wordwrap(description) t)
			     ), E'\r\n') INTO txt 
     FROM sl_solver s;
     
     IF (txt IS NULL) THEN
       help = E'There are not installed solvers. Please install one.\r\n';
     ELSE
       help = format(E'Supported Solvers:\r\n%s\r\n', txt);
     END IF;
  ELSE
     -- OK, we got a solver, let's print into about it
     help = help || format(E'SOLVER \"%s\":\r\n', s_row.name);
     help = help || format(E'  Name:\t\t\t%s\r\n', s_row.name);
     help = help || format(E'  Version:\t\t%s\r\n', s_row.version);
     SELECT string_agg(auth, ', ') INTO txt FROM (VALUES 
						 (COALESCE(s_row.author_name,'')), 
						 (s_row.author_email), 
						 (COALESCE(s_row.author_url,''))) s(auth);
     IF (char_length(txt)>0) THEN
	help = help || format(E'  Author:\t\t%s\r\n', txt); 
     END IF;

     -- Print the default method, if set
     help = help || format(E'  Default Method:\t\"%s\"\r\n', COALESCE((SELECT name
							  FROM sl_solver_method
							  WHERE sid = s_row.sid AND mid = s_row.default_method_id), 
							'<NOT SET>'));
        
     help = help || format(E'  Description:\t\t%s\r\n', (SELECT string_agg(t, E'\r\n\t') /* Needed for pretty formatting */
						         FROM sl_get_wordwrap(s_row.description) t));

     IF (m_row IS NULL) THEN
	     -- Print supported methods
	     help = help || format(E'  Supported Methods:\r\n');
	     WITH method_names AS (SELECT format('%s(%s):', 
						name, 
						(SELECT string_agg(sl_get_paramhelp(p.pid, true), ',')
						 FROM sl_parameter p INNER JOIN sl_solver_method_param mp ON mp.pid = p.pid
						 WHERE mp.mid = m.mid 
						)) AS name, name_full
				   FROM sl_solver_method m
				   WHERE sid = s_row.sid),
		  max_len AS (SELECT max(char_length(name)) FROM method_names)
	     SELECT string_agg(format(E'   - %s %s', rpad(name, (SELECT * FROM max_len), ' '), 
					 (SELECT string_agg(t, E'\r\n\t\t\t') /* Needed for pretty formatting */
					  FROM sl_get_wordwrap(name_full) t)), E'\r\n')
	     INTO txt
	     FROM method_names;
	     help = help || format(E'%s\r\n', txt);
     ELSE
            -- Print info about the solver's parameters
            help = help || format(E'  Parameters Common to All Methods:\r\n');
            SELECT string_agg(format(E'   - %s',sl_get_paramhelp(p.pid, false)), E'\r\n')
            INTO txt
	    FROM sl_parameter p INNER JOIN sl_solver_param sp ON sp.pid = p.pid WHERE sp.sid = s_row.sid;
	    help = help || format(E'%s\r\n', txt);	 
	    -- Print info about the method
	    help = help || format(E'METHOD \"%s\":\r\n', m_row.name);
	    help = help || format(E'  Name:\t\t\t%s\r\n', m_row.name_full);
	    help = help || format(E'  Problem It Solves:\t%s\r\n', m_row.prob_name);
	    help = help || format(E'  Description:\t\t%s\r\n', (SELECT string_agg(t, E'\r\n\t\t\t') /* Needed for pretty formatting */
						             FROM sl_get_wordwrap(m_row.description) t));
	    help = help || format(E'  Method Parameters:\r\n');
	    SELECT string_agg(format(E'   - %s',sl_get_paramhelp(p.pid, false)), E'\r\n')
            INTO txt
	    FROM sl_parameter p INNER JOIN sl_solver_method_param mp ON mp.pid = p.pid WHERE mp.mid = m_row.mid;
	    help = help || format(E'%s\r\n', txt);		    
     END IF;
  END IF;
  help = help || format('SolverAPI (v%s.%s) for PostgreSQL 9.2', sl_get_apiversion()/100, sl_get_apiversion() % 100);

  RETURN help;
 END;
$$ LANGUAGE plpgsql STABLE;


-- Rework the problem to eliminate CTEs with decision variables:
--     it makes a FULL OUTER JOIN of all CTEs, to make one BIG input relation
CREATE OR REPLACE FUNCTION sl_rework_CTEs(problem sl_problem) RETURNS sl_problem AS $$
 DECLARE
    numDCtes   		integer;
    cte       		sl_CTE_relation;
    cte_cols		sl_attribute_desc[];
    cte_flagcol 	name;    
    id_col    		name;
    id_cols   		name[];    
    with_sql		text;
    input_sql 		text;    
    from_sql  		text;    
    col_sql   		text;
    new_cols_unknown	name[];    
    new_ctes  		sl_CTE_relation[]; 
    new_prb   		sl_problem;
 BEGIN
   numDCtes = COALESCE((SELECT count(*) FROM unnest(problem.ctes) AS n WHERE array_length(cols_unknown, 1) > 0), 0);

   IF numDCtes = 0 THEN 
	RETURN problem;
   END IF;

   -- Set a new name for the input relation
   new_prb.input_alias = sl_get_unique_tblname();   
   -- Set CTE col flag
   cte_flagcol = 'cte_' || sl_get_unique_colname();
   -- Generate a new set of col unknowns
   new_cols_unknown = problem.cols_unknown;

   -- Generate a new input relation
   id_col = sl_get_unique_colname();
   id_cols = ARRAY[id_col]::name[];
   with_sql = format('%s AS (SELECT (row_number() over ()) AS %s, * FROM (%s) AS %s)', problem.input_alias, id_col, problem.input_sql, problem.input_alias, problem.input_alias);
   from_sql = format('%s', problem.input_alias);
   col_sql = format('((CASE WHEN %s.%s IS NULL THEN 0 ELSE 1 END)::bit(%s) << %s)', problem.input_alias, id_col, numDCtes + 1, 0);   
   -- New CTE for the input relation
   new_ctes = ARRAY[ROW(format('SELECT %s FROM %s WHERE %s & (1::bit(%s) << %s) <> 0::bit(%4$s)', 
			       (SELECT string_agg(att.att_name, ',') FROM sl_get_attributes_from_sql(problem.input_sql) AS att), new_prb.input_alias, cte_flagcol, numDCtes + 1, 0), 
                        problem.input_alias,
                        ARRAY[]::name[] /* No single decision variable! */
                        )::sl_CTE_relation]::sl_CTE_relation[];
     
   -- Process CTEs with decision variables
   FOREACH cte IN ARRAY problem.ctes LOOP   
	IF array_length(cte.cols_unknown, 1)>0 THEN
		-- Combine CTE relations
		id_col = sl_get_unique_colname();	
		cte_cols = (SELECT array_agg(c) FROM sl_get_CTEattributes(problem, cte.input_alias) AS c);
			
		-- Expand "*" expression in the decision column list
		IF EXISTS(SELECT * FROM unnest(cte.cols_unknown) AS n WHERE n = '*')  THEN				
			cte.cols_unknown = (SELECT array_agg(a.att_name) FROM unnest(cte_cols) AS a);			
		END IF;

		-- Generate the new col unknowns
		new_cols_unknown = new_cols_unknown || (SELECT array_agg(format('col%s_%s', cte.input_alias, c)::name) FROM unnest(cte.cols_unknown) AS c);

		-- Generate the new form clause			
		with_sql = with_sql || format(', %s AS (SELECT (row_number() over ()) AS %s, %s FROM (%s) AS %s)', cte.input_alias, id_col, 
						(SELECT string_agg(format('%s AS col%s_%1$s', att.att_name, cte.input_alias), ',') FROM unnest(cte_cols) AS att),
						cte.input_sql, cte.input_alias);
		from_sql = from_sql || format(' FULL OUTER JOIN %s ON %s = COALESCE(%s)', cte.input_alias, id_col, (SELECT string_agg(c, ',')
													            FROM unnest(id_cols) AS c));
						
		id_cols = array_append(id_cols, id_col);		

		-- Setup the CTE flag column
		col_sql = col_sql || format('| ((CASE WHEN %s.%s IS NULL THEN 0 ELSE 1 END)::bit(%s) << %s)', cte.input_alias, id_col, numDCtes + 1, array_length(id_cols, 1) - 1);

		-- Prepare a new CTE relation
		new_ctes = array_append(new_ctes, ROW(format('SELECT %s FROM %s WHERE %s & (1::bit(%s) << %s) <> 0::bit(%4$s)', 
							     (SELECT string_agg(format('col%s_%s AS %2$s', cte.input_alias, att.att_name), ',') FROM unnest(cte_cols) AS att),
							      new_prb.input_alias, cte_flagcol, numDCtes + 1, array_length(id_cols, 1) - 1), 
						cte.input_alias,
						ARRAY[]::name[] /* No single decision variable! */
						)::sl_CTE_relation);
	ELSE 
		-- Else, if no decision variables, just copy CTE's
		new_ctes = array_append(new_ctes, cte);
	END IF;
   END LOOP;

   -- Build a new problem      
   new_prb.input_sql = format('WITH %s SELECT *, (%s) AS %s FROM %s', with_sql, col_sql, cte_flagcol, from_sql);

   -- RAISE EXCEPTION '% %', problem.cols_unknown,  (SELECT array_agg(c) FROM (SELECT unnest(n.cols_unknown) AS c FROM unnest(problem.ctes) AS n) AS c);

   --  problem.cols_unknown || (SELECT array_agg(format('col%s_%s', input_alias, c)::name) FROM (SELECT n.input_alias, unnest(n.cols_unknown) AS c FROM unnest(problem.ctes) AS n) AS c);
   new_prb.cols_unknown = new_cols_unknown; 
   new_prb.obj_dir = problem.obj_dir;
   new_prb.obj_sql = problem.obj_sql;
   new_prb.obj_sql = problem.obj_sql;
   new_prb.ctr_sql = problem.ctr_sql;
   new_prb.ctes = new_ctes;

   -- Generate new CTEs that have no unknown variables     
   RETURN new_prb;
 END
$$ LANGUAGE plpgsql VOLATILE;


-- A main exterance to the solving routines, the SOLVE function. 
-- It finds a solver method, generates the solver_params and call the solver
CREATE OR REPLACE FUNCTION sl_solve(query sl_solve_query, par_val_pairs text[][]) RETURNS setof record AS $$
DECLARE
 s_row       sl_solver%ROWTYPE;
 m_row       sl_solver_method%ROWTYPE;

 p	     text[];
 par 	     sl_parameter%ROWTYPE;
 spair       sl_parameter_value;
 par_query   text;
 
 sarg        sl_solver_arg; 
 r 	     record;
 input_atts  sl_attribute_desc[];
 return_atts sl_attribute_desc[];
 attr	     sl_attribute_desc;
 attr_name   name;
 i	     integer;
 fnd	     boolean;
 log_level   text;
BEGIN
	 IF (query IS NULL) THEN
	     RAISE EXCEPTION E'Optimization problem is not specified!';
	 END IF;
	 -- Check if user wants help about a solver/method
	 IF (EXISTS(SELECT * 
		    FROM generate_subscripts(par_val_pairs, 1) ind
	            WHERE lower((par_val_pairs)[ind][1]) = 'help')) THEN
	     RAISE EXCEPTION E'Help information requested\r\n%', sl_get_solverhelp(query.solver_name, query.method_name);	 
	 END IF;
	 -- Set's the API's version number
	 sarg.api_version = sl_get_apiversion();
	 -- Checks if the solver is specified
	 IF ((query.solver_name IS NULL) OR (char_length(query.solver_name) = 0)) THEN
	    RAISE EXCEPTION E'Solver name is not specified.\r\n%', sl_get_solverhelp(query.solver_name, query.method_name);
	 END IF;
	 -- Search for the solver by name 
	 SELECT * INTO s_row FROM sl_solver WHERE name = query.solver_name;
	 IF (s_row IS NULL) THEN
	    RAISE EXCEPTION E'Solver "%" cannot be found.\r\n%', query.solver_name, 
								 sl_get_solverhelp(query.solver_name, query.method_name);
	 END IF; 
	 -- Searches for the solver method or assigns a default
	 IF ((query.method_name IS NULL) OR (char_length(query.method_name) = 0)) THEN
	    SELECT * INTO m_row FROM sl_solver_method WHERE mid = s_row.default_method_id;
	    IF (m_row IS NULL) THEN
	       RAISE EXCEPTION E'Method name is not specified and the solver "%" has no default method.\r\n%', 
					query.solver_name, sl_get_solverhelp(query.solver_name, query.method_name);
	    END IF;
	 ELSE 
	    SELECT * INTO m_row FROM sl_solver_method WHERE (sid = s_row.sid) AND (name = query.method_name);
	    IF (m_row IS NULL) THEN
	       RAISE EXCEPTION E'The solver "%" has no method "%".\r\n%', 
					query.solver_name, query.method_name,sl_get_solverhelp(query.solver_name, query.method_name);
	    END IF;	    
	 END IF;
	 -- Initialize the parameter list
	 sarg.params = ARRAY[]::sl_parameter_value[];
	 -- Build default parameter values, if needed.
	 sarg.params = array_cat(sarg.params,(
		 SELECT array_agg(ROW(name, 
				      (CASE WHEN type = 'int'   THEN value_default::int   ELSE NULL END),
				      (CASE WHEN type = 'float' THEN value_default::float ELSE NULL END),
				      (CASE WHEN type = 'text'  THEN value_default        ELSE NULL END)
		                     )::sl_parameter_value) 
		 FROM sl_parameter
		 WHERE push_default AND
		      ((pid IN (SELECT pid FROM sl_solver_param WHERE sid = m_row.sid)) OR
		       (pid IN (SELECT pid FROM sl_solver_method_param WHERE mid = m_row.mid)))));
	 -- Build parameter list
	 IF (coalesce(array_length(par_val_pairs, 1), 0)>0) THEN 
		 FOREACH p SLICE 1 IN ARRAY par_val_pairs
		 LOOP
		     spair.param = p[1]; -- Cast from text to name
		     -- Checks if it's a valid parameter
		     SELECT * INTO par 
		     FROM sl_parameter
		     WHERE (lower(name) = lower(spair.param)) AND 
			   ((pid IN (SELECT pid FROM sl_solver_param WHERE sid = m_row.sid)) OR
			    (pid IN (SELECT pid FROM sl_solver_method_param WHERE mid = m_row.mid)));
			    
		     IF (par IS NULL) THEN
			 RAISE EXCEPTION E'The solver "%" or the solver method "%" does not support a parameter "%".\r\n%', 
					   query.solver_name, query.method_name, spair.param, sl_get_solverhelp(query.solver_name, query.method_name);
		     END IF;     
		     -- Copy a param-val pair from the 	     
	             BEGIN
			     spair.value_i = NULL;
			     spair.value_f = NULL;
			     spair.value_t = NULL;	     
			     CASE par.type
				   WHEN 'int' THEN spair.value_i = p[2]::int;
				   WHEN 'float' THEN spair.value_f = p[2]::float;
				   WHEN 'text' THEN spair.value_t = p[2];
				   ELSE RAISE EXCEPTION 'Unsupported parameter type "%"',par.type;
			     END CASE;			     
			     -- Check if the parameter value exceeds the MIN bounds
			     IF COALESCE(spair.value_i, spair.value_f) < par.value_min THEN
				RAISE EXCEPTION E'The value (%) of the parameter "%" is lower than the allowed value (%).\r\n%', 
					COALESCE(spair.value_i, spair.value_f), spair.param, par.value_min,
					sl_get_solverhelp(query.solver_name, query.method_name);
			     END IF;
			     -- Check if the parameter value exceeds the MAX bounds
			     IF COALESCE(spair.value_i, spair.value_f) > par.value_max THEN
				RAISE EXCEPTION E'The value (%) of the parameter "%" is higher than the allowed value (%).\r\n%', 
					COALESCE(spair.value_i, spair.value_f), spair.param, par.value_max,
					sl_get_solverhelp(query.solver_name, query.method_name);
			     END IF;			     
		     EXCEPTION 
			WHEN invalid_text_representation THEN
			      RAISE EXCEPTION 'Invalid parameter "%" value is specified for the solver method "%.%".',
					      spair.param, query.solver_name, query.method_name;
		     END;
	             -- Override the parameter value, if the parameter was previously set
	             SELECT ind INTO i FROM generate_subscripts(sarg.params, 1) ind
	             WHERE ((sarg.params)[ind]).param = spair.param;

		     IF (i IS NULL) THEN              
		        sarg.params = array_append(sarg.params, spair);
		     ELSE
		        sarg.params[i] = spair;
		     END IF;	    
		 END LOOP;
	 END IF;
	 
	 -- Set the solver and method names 
         sarg.solver_name = s_row.name;	-- Assign a solver
	 sarg.method_name = m_row.name; -- Assign a method

	 
	 -- Find a unique temporal table/materialized view name
	 -- i = 0;
-- 	 LOOP
-- 		sarg.tmp_name = 'sl_input_' || i::name;       -- Check the table exist in database and is visible
-- 		PERFORM table_name
-- 		FROM information_schema.tables
-- 		WHERE table_name = sarg.tmp_name;     -- A build-in temporal table name is "sl_input"
-- 		EXIT WHEN NOT FOUND;
-- 		i = i + 1;
-- 	 END LOOP;   

	 /* Set the temporary table name */
	 sarg.tmp_name = sl_get_unique_tblname();


	 -- Statically analyze the attributes of input SQL -- before the transformation
	 SELECT array_agg(A::sl_attribute_desc) 
	 FROM sl_get_attributes_from_sql((query.problem).input_sql) as A 
	 INTO return_atts;	 

	 -- Expand "*" expression in the decision column list
	 IF EXISTS(SELECT * FROM unnest((query.problem).cols_unknown) AS n WHERE n = '*')  THEN
		DECLARE 				
			prob        sl_problem; 
		BEGIN
			prob = query.problem;
			prob.cols_unknown = (SELECT array_agg(a.att_name) FROM unnest(return_atts) AS a);
			query.problem = prob;
		END;
	 END IF;

	 -- Rework the problem, to eliminate CTEs with decision variables
	 IF COALESCE(m_row.auto_rewrite_ctes, false) THEN 
		 sarg.problem = sl_rework_CTEs(query.problem);	 
		 
		 -- Statically analyze the attributes of input SQL -- after the transformation
		 SELECT array_agg(A::sl_attribute_desc) 
		 FROM sl_get_attributes_from_sql((sarg.problem).input_sql) as A 
		 INTO input_atts;
	 ELSE 
		sarg.problem = query.problem;
		input_atts = return_atts;
	 END IF;
	 
	 -- Detect attribute types
	 sarg.tmp_attrs = ARRAY[]::sl_attribute_desc[]; 
	 -- Prepare temp table attribute list while decorating attributes with their kinds
	 FOREACH attr IN ARRAY input_atts LOOP
	      fnd = false;     
	      FOREACH attr_name IN ARRAY (sarg.problem).cols_unknown LOOP
		 fnd = (attr.att_name = attr_name);
		 EXIT WHEN fnd;
	      END LOOP;
	      attr.att_kind = CASE fnd
				WHEN true THEN 'unknown' 
					  ELSE 'known'
			      END;
              sarg.tmp_attrs = array_append(sarg.tmp_attrs, attr);
	 END LOOP;	 
	 -- Finds an unique attribute name for a new primary key
	 /*i = 0;
	 LOOP
		sarg.tmp_id = 'sl_id_' || i::name;       -- check the attribute exist
		PERFORM input_atts[a].att_name 
		FROM generate_subscripts(input_atts, 1) AS a
		WHERE (input_atts[a].att_name = sarg.tmp_id);
		-- Exit if not found		
		EXIT WHEN NOT FOUND;
		i = i + 1;
	 END LOOP;*/
	 sarg.tmp_id = sl_get_unique_colname();
	 attr.att_name = sarg.tmp_id;
	 attr.att_type = 'bigint';
	 attr.att_kind = 'id'::sl_attribute_kind;
	 sarg.tmp_attrs = array_prepend(attr, sarg.tmp_attrs);
	 
	 -- Build a temporal table and get basic statistics about the problem
	 SELECT sl_createtmptable_unrestricted(sarg.tmp_name, (SELECT format('SELECT (row_number() OVER ()) AS %s, S.* FROM (%s) AS S',
									      sarg.tmp_id, (sarg.problem).input_sql)))
	 INTO sarg.prb_rowcount;
	 -- NOTE: In PG9.3.1, TEMP tables cannot be created in the MATVIEWS. 
	 -- The function "sl_createtmptable_unrestricted" overcomes this limitation, and has the semantics of "CREATE TEMP TABLE %s AS (%s)".
	 -- It corresponds to the following 2 lines:
	 --     EXECUTE format('CREATE TEMP TABLE %s WITH (fillfactor=100) AS (SELECT (row_number() OVER ()) AS %s, S.* FROM (%s) AS S)',  
	 --	     			     sarg.tmp_name, sarg.tmp_id, (sarg.problem).input_sql);	
	 --     GET DIAGNOSTICS sarg.prb_rowcount = ROW_COUNT; 
	 
	 sarg.prb_colcount = array_length((sarg.problem).cols_unknown, 1);
	 sarg.prb_varcount = (sarg.prb_colcount) * (sarg.prb_rowcount);
	 	
	 -- Add primary key constraint
	 EXECUTE format('CREATE INDEX %s_orderindex ON %s(%s) WITH (fillfactor=100)', sarg.tmp_name, sarg.tmp_name, sarg.tmp_id);

	 -- Check the optimization problem for correctness
	 PERFORM sl_problem_check(sarg.problem, input_atts);
	 	
	 -- Make a call to the solver	 
	 DECLARE
	   error_msg text;
	 BEGIN 
	     RETURN QUERY EXECUTE format('%s SELECT %s FROM %s', 
					sl_get_dst_prequery(sarg.problem, ROW(format('SELECT * FROM %s($1) AS (%s)', 
									      quote_ident(m_row.func_name),
									     (SELECT string_agg(format('%s %s', quote_ident(input_atts[att_nr].att_name), 
															    input_atts[att_nr].att_type), ',') 
									      FROM generate_subscripts(input_atts,1) as att_nr)
					                                     ))::sl_viewsql_out),

					(SELECT string_agg(format('%s::%s', quote_ident(return_atts[att_nr].att_name), 
					   					        return_atts[att_nr].att_type), ',') 
					 FROM generate_subscripts(return_atts,1) as att_nr),					  					                                    
					 (query.problem).input_alias)
			  USING (sarg);
	 EXCEPTION
	     -- Add error codes are listed http://www.postgresql.org/docs/9.2/static/errcodes-appendix.html	 
	     WHEN undefined_function OR raise_exception THEN			      
			GET STACKED DIAGNOSTICS error_msg = MESSAGE_TEXT;
			RAISE EXCEPTION E'Error executing the solver \"%\".\r\nERROR: %',
					 query.solver_name, error_msg;
	 END;
	 
	 -- Destroy a temporary table
	 EXECUTE format('DROP TABLE %s RESTRICT',sarg.tmp_name);
END;
$$ LANGUAGE plpgsql VOLATILE;
COMMENT ON FUNCTION sl_solve(sl_solve_query, text[][]) IS 'The main entrance method to execute solve queries.';


-- ******************** Utility functions to simplify constraint query processing* ****************************

-- A type to reference (or simbolically define) an unknown variable
CREATE TYPE sl_unkvar AS
(
	nr	bigint		/* A number of an unknown variable is sufficient to intentify it */
);

-- This function creates a reference to an unknwon variable
CREATE OR REPLACE FUNCTION sl_unkvar_make(var_nr bigint) RETURNS sl_unkvar AS $$
   SELECT ROW(var_nr)::sl_unkvar;
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- Enum defines basic constraint types
CREATE TYPE sl_ctr_type AS ENUM ('eq', 'ne', 'lt', 'le','ge', 'gt');

-- IO functions for "sl_ctr" type
CREATE FUNCTION sl_ctr_in(cstring)
RETURNS sl_ctr
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION sl_ctr_out(sl_ctr)
RETURNS cstring
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

-- A datatype to define a basic constraint of the kind:  
-- 	C (op) X, 
--           where:
--              C    - a numeric (float8) constant
--              op - [=|!=|<|<=|>=|>]
--              X    - expression/unknown variable of an any type (e.g., sl_unkvar),
CREATE TYPE sl_ctr (
	INTERNALLENGTH = variable,
	INPUT = sl_ctr_in,
	OUTPUT = sl_ctr_out 
);

-- A constructor function to make sl_ctr
CREATE FUNCTION sl_ctr_make(float8, sl_ctr_type, anyelement) RETURNS sl_ctr
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT;

-- A constructor function to make sl_ctr from other existing sl_ctr.
-- A polymorphics element will simply be copied, but user can still set C and op 
CREATE FUNCTION sl_ctr_makefrom(float8, sl_ctr_type, sl_ctr) RETURNS sl_ctr
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT;

-- Getter to get C from "sl_ctr"
CREATE FUNCTION sl_ctr_get_c(sl_ctr) RETURNS float8
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT;

-- Getter to get OP from "sl_ctr"
CREATE FUNCTION sl_ctr_get_op(sl_ctr) RETURNS sl_ctr_type
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT;
    
-- Getter to get X from "sl_ctr". 
-- The second argument defines the "template of X" to the PG parser to figure out the type of returned X element
CREATE FUNCTION sl_ctr_get_x(sl_ctr, anyelement) RETURNS anyelement
    AS 'MODULE_PATHNAME'
    LANGUAGE C IMMUTABLE STRICT;

-- The transitivity property of sl_ctr: C1 (op1) (C2 (op2) X)  <=>  (C1 (op1) X) and (C2 (op2) X)
-- C1 = (C2 (op2) X)  <=>  (C1 = X) and (C2 (op2) X)
CREATE FUNCTION sl_ctr_makeCT_eq(float8, sl_ctr) RETURNS setof sl_ctr AS $$
   SELECT sl_ctr_makefrom($1, 'eq', $2)
   UNION ALL
   SELECT $2;
$$ LANGUAGE SQL IMMUTABLE STRICT;    
CREATE OPERATOR = (LEFTARG = float8, RIGHTARG = sl_ctr, COMMUTATOR = =, PROCEDURE = sl_ctr_makeCT_eq);

-- C1 != (C2 (op2) X)  <=>  (C1 != X) and (C2 (op2) X)
CREATE FUNCTION sl_ctr_makeCT_ne(float8, sl_ctr) RETURNS setof sl_ctr AS $$
   SELECT sl_ctr_makefrom($1, 'ne', $2)
   UNION ALL
   SELECT $2;
$$ LANGUAGE SQL IMMUTABLE STRICT;    
CREATE OPERATOR != (LEFTARG = float8, RIGHTARG = sl_ctr, COMMUTATOR = !=, PROCEDURE = sl_ctr_makeCT_ne);

-- C1 < (C2 (op2) X)  <=>  (C1 < X) and (C2 (op2) X)
CREATE FUNCTION sl_ctr_makeCT_lt(float8, sl_ctr) RETURNS setof sl_ctr AS $$
   SELECT sl_ctr_makefrom($1, 'lt', $2)
   UNION ALL
   SELECT $2;
$$ LANGUAGE SQL IMMUTABLE STRICT;    
CREATE OPERATOR < (LEFTARG = float8, RIGHTARG = sl_ctr, COMMUTATOR = >, PROCEDURE = sl_ctr_makeCT_lt);

-- C1 <= (C2 (op2) X)  <=>  (C1 <= X) and (C2 (op2) X)
CREATE FUNCTION sl_ctr_makeCT_le(float8, sl_ctr) RETURNS setof sl_ctr AS $$
   SELECT sl_ctr_makefrom($1, 'le', $2)
   UNION ALL
   SELECT $2;
$$ LANGUAGE SQL IMMUTABLE STRICT;    
CREATE OPERATOR <= (LEFTARG = float8, RIGHTARG = sl_ctr, COMMUTATOR = >=, PROCEDURE = sl_ctr_makeCT_le);

-- C1 >= (C2 (op2) X)  <=>  (C1 >= X) and (C2 (op2) X)
CREATE FUNCTION sl_ctr_makeCT_ge(float8, sl_ctr) RETURNS setof sl_ctr AS $$
   SELECT sl_ctr_makefrom($1, 'ge', $2)
   UNION ALL
   SELECT $2;
$$ LANGUAGE SQL IMMUTABLE STRICT;    
CREATE OPERATOR >= (LEFTARG = float8, RIGHTARG = sl_ctr, COMMUTATOR = <=, PROCEDURE = sl_ctr_makeCT_ge);

-- C1 > (C2 (op2) X)  <=>  (C1 > X) and (C2 (op2) X)
CREATE FUNCTION sl_ctr_makeCT_gt(float8, sl_ctr) RETURNS setof sl_ctr AS $$
   SELECT sl_ctr_makefrom($1, 'gt', $2)
   UNION ALL
   SELECT $2;
$$ LANGUAGE SQL IMMUTABLE STRICT;    
CREATE OPERATOR > (LEFTARG = float8, RIGHTARG = sl_ctr, COMMUTATOR = <, PROCEDURE = sl_ctr_makeCT_gt);

-- The transitivity property of sl_ctr: (C1 (op1) X) (op2) C2   <=>  (C1 (op1) X) and (X (op2) C2)
-- (C1 (op) X) = C2  <=>  (C1 (op) X) and (C2 = X)
CREATE FUNCTION sl_ctr_makeTC_eq(sl_ctr,float8) RETURNS setof sl_ctr AS $$
   SELECT $1
   UNION ALL
   SELECT sl_ctr_makefrom($2, 'eq', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;    
CREATE OPERATOR = (LEFTARG = sl_ctr, RIGHTARG = float8, COMMUTATOR = =, PROCEDURE = sl_ctr_makeTC_eq);

-- (C1 (op) X) != C2  <=>  (C1 (op) X) and (C2 != X)
CREATE FUNCTION sl_ctr_makeTC_ne(sl_ctr,float8) RETURNS setof sl_ctr AS $$
   SELECT $1
   UNION ALL
   SELECT sl_ctr_makefrom($2, 'ne', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;    
CREATE OPERATOR != (LEFTARG = sl_ctr, RIGHTARG = float8, COMMUTATOR = !=, PROCEDURE = sl_ctr_makeTC_ne);

-- (C1 (op) X) < C2  <=>  (C1 (op) X) and (C2 > X)
CREATE FUNCTION sl_ctr_makeTC_lt(sl_ctr,float8) RETURNS setof sl_ctr AS $$
   SELECT $1
   UNION ALL
   SELECT sl_ctr_makefrom($2, 'gt', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;    
CREATE OPERATOR < (LEFTARG = sl_ctr, RIGHTARG = float8, COMMUTATOR = >, PROCEDURE = sl_ctr_makeTC_lt);

-- (C1 (op) X) <= C2  <=>  (C1 (op) X) and (C2 >= X)
CREATE FUNCTION sl_ctr_makeTC_le(sl_ctr,float8) RETURNS setof sl_ctr AS $$
   SELECT $1
   UNION ALL
   SELECT sl_ctr_makefrom($2, 'ge', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;    
CREATE OPERATOR <= (LEFTARG = sl_ctr, RIGHTARG = float8, COMMUTATOR = >=, PROCEDURE = sl_ctr_makeTC_le);

-- (C1 (op) X) >= C2  <=>  (C1 (op) X) and (C2 <= X)
CREATE FUNCTION sl_ctr_makeTC_ge(sl_ctr,float8) RETURNS setof sl_ctr AS $$
   SELECT $1
   UNION ALL
   SELECT sl_ctr_makefrom($2, 'le', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;    
CREATE OPERATOR >= (LEFTARG = sl_ctr, RIGHTARG = float8, COMMUTATOR = <=, PROCEDURE = sl_ctr_makeTC_ge);

-- (C1 (op) X) > C2  <=>  (C1 (op) X) and (C2 < X)
CREATE FUNCTION sl_ctr_makeTC_gt(sl_ctr,float8) RETURNS setof sl_ctr AS $$
   SELECT $1
   UNION ALL
   SELECT sl_ctr_makefrom($2, 'lt', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;    
CREATE OPERATOR > (LEFTARG = sl_ctr, RIGHTARG = float8, COMMUTATOR = <, PROCEDURE = sl_ctr_makeTC_gt);

-- Operators for constraining instances of "sl_unkvar"
-- C (op) UNKVAR
CREATE FUNCTION sl_ctr_makeCU_eq(float8, sl_unkvar) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'eq', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR = (LEFTARG = float8, RIGHTARG = sl_unkvar, COMMUTATOR = =, PROCEDURE = sl_ctr_makeCU_eq);

CREATE FUNCTION sl_ctr_makeCU_ne(float8, sl_unkvar) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'ne', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR != (LEFTARG = float8, RIGHTARG = sl_unkvar, COMMUTATOR = !=, PROCEDURE = sl_ctr_makeCU_ne);

CREATE FUNCTION sl_ctr_makeCU_lt(float8, sl_unkvar) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'lt', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR < (LEFTARG = float8, RIGHTARG = sl_unkvar, COMMUTATOR = >, PROCEDURE = sl_ctr_makeCU_lt);

CREATE FUNCTION sl_ctr_makeCU_le(float8, sl_unkvar) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'le', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR <= (LEFTARG = float8, RIGHTARG = sl_unkvar, COMMUTATOR = >=, PROCEDURE = sl_ctr_makeCU_le);

CREATE FUNCTION sl_ctr_makeCU_ge(float8, sl_unkvar) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'ge', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR >= (LEFTARG = float8, RIGHTARG = sl_unkvar, COMMUTATOR = <=, PROCEDURE = sl_ctr_makeCU_ge);

CREATE FUNCTION sl_ctr_makeCU_gt(float8, sl_unkvar) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'gt', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR > (LEFTARG = float8, RIGHTARG = sl_unkvar, COMMUTATOR = <, PROCEDURE = sl_ctr_makeCU_gt);

-- UNKVAR (op) C
CREATE FUNCTION sl_ctr_makeUC_eq(sl_unkvar,float8) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'eq', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR = (LEFTARG = sl_unkvar, RIGHTARG = float8, COMMUTATOR = =, PROCEDURE = sl_ctr_makeUC_eq);

CREATE FUNCTION sl_ctr_makeUC_ne(sl_unkvar,float8) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'ne', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR != (LEFTARG = sl_unkvar, RIGHTARG = float8, COMMUTATOR = !=, PROCEDURE = sl_ctr_makeUC_ne);

CREATE FUNCTION sl_ctr_makeUC_lt(sl_unkvar,float8) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'gt', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR < (LEFTARG = sl_unkvar, RIGHTARG = float8, COMMUTATOR = >, PROCEDURE = sl_ctr_makeUC_lt);

CREATE FUNCTION sl_ctr_makeUC_le(sl_unkvar,float8) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'ge', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR <= (LEFTARG = sl_unkvar, RIGHTARG = float8, COMMUTATOR = >=, PROCEDURE = sl_ctr_makeUC_le);

CREATE FUNCTION sl_ctr_makeUC_ge(sl_unkvar,float8) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'le', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR >= (LEFTARG = sl_unkvar, RIGHTARG = float8, COMMUTATOR = <=, PROCEDURE = sl_ctr_makeUC_ge);

CREATE FUNCTION sl_ctr_makeUC_gt(sl_unkvar,float8) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'lt', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR > (LEFTARG = sl_unkvar, RIGHTARG = float8, COMMUTATOR = <, PROCEDURE = sl_ctr_makeUC_gt);

-- ************************************************************************************************************