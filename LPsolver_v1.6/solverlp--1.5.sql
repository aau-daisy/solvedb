-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION solverlp" to load this file. \quit

-- The solver's entry point to the BASIC LP
CREATE OR REPLACE FUNCTION lp_problem_solve_basic(sl_solver_arg) RETURNS SETOF record
AS 'MODULE_PATHNAME'
LANGUAGE C STABLE STRICT
COST 10000;

-- The solver's entry point to the MIP LP
CREATE OR REPLACE FUNCTION lp_problem_solve_mip(sl_solver_arg) RETURNS SETOF record
AS 'MODULE_PATHNAME'
LANGUAGE C STABLE STRICT
COST 10000;

-- The solver's entry point to the AUTO LP
CREATE OR REPLACE FUNCTION lp_problem_solve_auto(sl_solver_arg) RETURNS SETOF record
AS 'MODULE_PATHNAME'
LANGUAGE C STABLE STRICT
COST 10000;

-- The solver's entry point to the CBC
CREATE OR REPLACE FUNCTION lp_problem_solve_cbc(sl_solver_arg) RETURNS SETOF record
AS 'MODULE_PATHNAME'
LANGUAGE C STABLE STRICT
COST 10000;

-- Registers the solver and 3 methods.
WITH 
     -- Registers the solver and its parameters.
     solver AS   (INSERT INTO sl_solver(name, version, author_name, author_url, description)
                  values ('solverlp', 1.5, 'GNU Project', 'http://www.gnu.org/software/glpk/glpk.html', 'The port of GLPK solver by Laurynas Siksnys') 
                  returning sid),
     spar1 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('log_level' , 'int', 'Logging level of the solver: 20 - ERROR, 19 - WARNING, 18 - NOTICE, 17 - INFO, 15 - LOG, 14 - DEBUG', 17, 0, 20) 
                  RETURNING pid),
     sspar1 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar1
                  RETURNING sid),
     spar2 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('use_nulls' , 'int', 'When set to 1, values of non-referenced variables will be set to NULL, otherwise to 0', 0, 0, 1) 
                  RETURNING pid),
     sspar2 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar2
                  RETURNING sid),
     spar3 AS    (INSERT INTO sl_parameter(name, type, description, value_default, value_min, value_max)
                  values ('partition_size' , 'int', 'When set to 0, no problem partitioning is used. When set to >=1, enables the partitioning and indicates the size of a partition group.', 1, 0, 1000000) 
                  RETURNING pid),
     sspar3 AS   (INSERT INTO sl_solver_param(sid, pid)
                  SELECT sid, pid FROM solver, spar3
                  RETURNING sid),

     -- Registers the BASIC method. It has no parameters.
     method1 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'basic', 'Basic GLPK solver', 'lp_problem_solve_basic', 'linear programming optimization problem', 'Solves linear programming optimization problem using the simplex method' 
		  FROM solver RETURNING mid),

     method2 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'mip', 'MIP GLPK solver', 'lp_problem_solve_mip', 'linear programming optimization problem', 'Solves linear programming optimization problem with variables of the integer type. It uses both the simplex and the branch-and-bound method' 
		  FROM solver RETURNING mid),

     method3 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'auto', 'Automatically chose between Basic and MIP problem', 'lp_problem_solve_auto', 'linear programming optimization problem', 'Based on the column types, automatically choose to solve the basic of the MIP problem.'
		  FROM solver RETURNING mid),
     method4 AS (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'cbc', 'Uses the Coins CBC solver (experimental)', 'lp_problem_solve_cbc', 'LP/MIP problem', 'Force to use the CBC solver.'
		  FROM solver RETURNING mid),

      -- Register solver method parameters
     mpar4_1 AS  (INSERT INTO sl_parameter(name, type, description)
                  values ('args' , 'text', 'The string of arguments to be passed to CBC solver') 
                  RETURNING pid),
     mmpar4_1 AS (INSERT INTO sl_solver_method_param(mid, pid)
                  SELECT mid, pid FROM method4, mpar4_1
                  RETURNING pid)

     -- Perform the actual insert
     SELECT count(*) FROM solver, spar1, sspar1, spar2, sspar2, spar3, sspar3, method1, method2, method3, method4, mpar4_1, mmpar4_1;

-- Set the default method
UPDATE sl_solver s
SET default_method_id = mid
FROM sl_solver_method m
WHERE (s.sid = m.sid) AND (s.name = 'solverlp') AND (m.name='auto');
                                                                      
-- LP function type
CREATE FUNCTION lp_function_in(cstring)
RETURNS lp_function
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION lp_function_out(lp_function)
RETURNS cstring
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE TYPE lp_function (
	INTERNALLENGTH = variable,
	INPUT = lp_function_in,
	OUTPUT = lp_function_out 
);
COMMENT ON TYPE lp_function IS 'lp_function: Represent the terms of linear function';

-- Constructor functions and casts 

CREATE FUNCTION lp_function_make(int8) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_make'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION lp_function_makeCfloat8(float8) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_makeCfloat8'
LANGUAGE C IMMUTABLE STRICT;

CREATE CAST (float8 AS lp_function) WITH FUNCTION lp_function_makeCfloat8(float8) AS IMPLICIT;

CREATE FUNCTION lp_function_makeCnum(numeric) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_makeCnum'
LANGUAGE C IMMUTABLE STRICT;

CREATE CAST (numeric AS lp_function) WITH FUNCTION lp_function_makeCnum(numeric) AS IMPLICIT;

CREATE FUNCTION lp_function_makeCint4(int4) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_makeCint4'
LANGUAGE C IMMUTABLE STRICT;

CREATE CAST (int4 AS lp_function) WITH FUNCTION lp_function_makeCint4(int4) AS IMPLICIT;

CREATE FUNCTION lp_function_makeCbool(boolean) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_makeCbool'
LANGUAGE C IMMUTABLE STRICT;

CREATE CAST (boolean AS lp_function) WITH FUNCTION lp_function_makeCbool(boolean) AS IMPLICIT;

-- Basic operators 

CREATE FUNCTION lp_function_fmul(lp_function, float8) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_fmul'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION lp_function_fmul(float8, lp_function) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_fmulC'
LANGUAGE C IMMUTABLE STRICT;        

CREATE FUNCTION lp_function_fdiv(lp_function, float8) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_fdiv'
LANGUAGE C IMMUTABLE STRICT;

CREATE OPERATOR * (
	LEFTARG = lp_function,
	RIGHTARG = float8,
	COMMUTATOR = *,
	PROCEDURE = lp_function_fmul
);

CREATE OPERATOR * (
	LEFTARG = float8,
	RIGHTARG = lp_function,
	COMMUTATOR = *,
	PROCEDURE = lp_function_fmul
);

CREATE OPERATOR / (
	LEFTARG = lp_function,
	RIGHTARG = float8,
	PROCEDURE = lp_function_fdiv
);


CREATE FUNCTION lp_function_plus(lp_function, lp_function) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_plus'
LANGUAGE C IMMUTABLE CALLED ON NULL INPUT;

CREATE OPERATOR + (
	LEFTARG = lp_function,
	RIGHTARG = lp_function,
	COMMUTATOR = +,
	PROCEDURE = lp_function_plus
);

CREATE FUNCTION lp_function_sum_trans(bytea, lp_function) RETURNS bytea
AS 'MODULE_PATHNAME', 'lp_function_sum_trans'
LANGUAGE C IMMUTABLE;

CREATE FUNCTION lp_function_sum_final(bytea) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_sum_final'
LANGUAGE C IMMUTABLE STRICT;

-- **** Hash-based aggregation is selected by DEFAULT ***
CREATE AGGREGATE sum (
    sfunc = lp_function_sum_trans,
    stype = bytea,
    finalfunc = lp_function_sum_final,
    basetype = lp_function
);

-- ***************** EXPERIMENTAL functions ***************************

-- Hash-based aggregation 
CREATE AGGREGATE sum_hash (
    sfunc = lp_function_sum_trans,
    stype = bytea,
    finalfunc = lp_function_sum_final,
    basetype = lp_function
);

-- Slow aggregation funtion based on sorted variable nubmers
CREATE FUNCTION lp_function_plus_sorted(lp_function, lp_function) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_plus_sorted'
LANGUAGE C IMMUTABLE CALLED ON NULL INPUT;

CREATE AGGREGATE sum_sorted (
    sfunc = lp_function_plus_sorted,
    basetype = lp_function,
    stype = lp_function
);

-- Fast aggregation function based on arrays
CREATE FUNCTION lp_function_sum_array_trans(bytea, lp_function) RETURNS bytea
AS 'MODULE_PATHNAME', 'lp_function_sum_array_trans'
LANGUAGE C IMMUTABLE;

CREATE FUNCTION lp_function_sum_array_final(bytea) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_sum_array_final'
LANGUAGE C IMMUTABLE STRICT;

CREATE AGGREGATE sum_array (
    sfunc = lp_function_sum_array_trans,
    stype = bytea,
    finalfunc = lp_function_sum_array_final,
    basetype = lp_function
);

-- **********************************************************************

CREATE FUNCTION lp_function_minus(lp_function, lp_function) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_minus'
LANGUAGE C IMMUTABLE CALLED ON NULL INPUT;

CREATE OPERATOR - (
	LEFTARG = lp_function,
	RIGHTARG = lp_function,
	PROCEDURE = lp_function_minus
);

CREATE FUNCTION lp_function_minus1(lp_function) RETURNS lp_function
AS 'MODULE_PATHNAME', 'lp_function_minus1'
LANGUAGE C IMMUTABLE CALLED ON NULL INPUT;

CREATE OPERATOR - (
	LEFTARG = lp_function,
	PROCEDURE = lp_function_minus1
);


CREATE FUNCTION lp_function_unnest(lp_function) RETURNS SETOF lp_function
AS 'MODULE_PATHNAME', 'lp_function_unnest'
LANGUAGE C IMMUTABLE STRICT;

-- Operators for constraining instances of "lp_function"
-- C (op) lp_function
CREATE FUNCTION sl_ctr_makeCP_eq(float8, lp_function) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'eq', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR = (LEFTARG = float8, RIGHTARG = lp_function, COMMUTATOR = =, PROCEDURE = sl_ctr_makeCP_eq);

CREATE FUNCTION sl_ctr_makeCP_ne(float8, lp_function) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'ne', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR != (LEFTARG = float8, RIGHTARG = lp_function, COMMUTATOR = !=, PROCEDURE = sl_ctr_makeCP_ne);

CREATE FUNCTION sl_ctr_makeCP_lt(float8, lp_function) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'lt', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR < (LEFTARG = float8, RIGHTARG = lp_function, COMMUTATOR = >, PROCEDURE = sl_ctr_makeCP_lt);

CREATE FUNCTION sl_ctr_makeCP_le(float8, lp_function) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'le', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR <= (LEFTARG = float8, RIGHTARG = lp_function, COMMUTATOR = >=, PROCEDURE = sl_ctr_makeCP_le);

CREATE FUNCTION sl_ctr_makeCP_ge(float8, lp_function) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'ge', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR >= (LEFTARG = float8, RIGHTARG = lp_function, COMMUTATOR = <=, PROCEDURE = sl_ctr_makeCP_ge);

CREATE FUNCTION sl_ctr_makeCP_gt(float8, lp_function) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'gt', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR > (LEFTARG = float8, RIGHTARG = lp_function, COMMUTATOR = <, PROCEDURE = sl_ctr_makeCP_gt);

-- lp_function (op) C
CREATE FUNCTION sl_ctr_makePC_eq(lp_function,float8) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'eq', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR = (LEFTARG = lp_function, RIGHTARG = float8, COMMUTATOR = =, PROCEDURE = sl_ctr_makePC_eq);

CREATE FUNCTION sl_ctr_makePC_ne(lp_function,float8) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'ne', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR != (LEFTARG = lp_function, RIGHTARG = float8, COMMUTATOR = !=, PROCEDURE = sl_ctr_makePC_ne);

CREATE FUNCTION sl_ctr_makePC_lt(lp_function,float8) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'gt', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR < (LEFTARG = lp_function, RIGHTARG = float8, COMMUTATOR = >, PROCEDURE = sl_ctr_makePC_lt);

CREATE FUNCTION sl_ctr_makePC_le(lp_function,float8) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'ge', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR <= (LEFTARG = lp_function, RIGHTARG = float8, COMMUTATOR = >=, PROCEDURE = sl_ctr_makePC_le);

CREATE FUNCTION sl_ctr_makePC_ge(lp_function,float8) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'le', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR >= (LEFTARG = lp_function, RIGHTARG = float8, COMMUTATOR = <=, PROCEDURE = sl_ctr_makePC_ge);

CREATE FUNCTION sl_ctr_makePC_gt(lp_function,float8) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'lt', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR > (LEFTARG = lp_function, RIGHTARG = float8, COMMUTATOR = <, PROCEDURE = sl_ctr_makePC_gt);

-- lp_function (op) lp_function
CREATE FUNCTION sl_ctr_makePP_eq(lp_function,lp_function) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make(0, 'eq', $2-$1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR = (LEFTARG = lp_function, RIGHTARG = lp_function, COMMUTATOR = =, PROCEDURE = sl_ctr_makePP_eq);

CREATE FUNCTION sl_ctr_makePP_ne(lp_function,lp_function) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make(0, 'ne', $2-$1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR != (LEFTARG = lp_function, RIGHTARG = lp_function, COMMUTATOR = !=, PROCEDURE = sl_ctr_makePP_ne);

CREATE FUNCTION sl_ctr_makePP_lt(lp_function,lp_function) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make(0, 'lt', $2-$1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR < (LEFTARG = lp_function, RIGHTARG = lp_function, COMMUTATOR = >, PROCEDURE = sl_ctr_makePP_lt);

CREATE FUNCTION sl_ctr_makePP_le(lp_function,lp_function) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make(0, 'le', $2-$1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR <= (LEFTARG = lp_function, RIGHTARG = lp_function, COMMUTATOR = >=, PROCEDURE = sl_ctr_makePP_le);

CREATE FUNCTION sl_ctr_makePP_ge(lp_function,lp_function) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make(0, 'ge', $2-$1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR >= (LEFTARG = lp_function, RIGHTARG = lp_function, COMMUTATOR = <=, PROCEDURE = sl_ctr_makePP_ge);

CREATE FUNCTION sl_ctr_makePP_gt(lp_function,lp_function) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make(0, 'gt', $2-$1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR > (LEFTARG = lp_function, RIGHTARG = lp_function, COMMUTATOR = <, PROCEDURE = sl_ctr_makePP_gt);


-- Additional utility functions/constraints

-- This function ensures that all terms in the lp_function are different
CREATE OR REPLACE FUNCTION all_diff(exp lp_function) RETURNS SETOF sl_ctr AS $$
  WITH terms AS (SELECT row_number() over () AS id, term FROM lp_function_unnest(exp) AS term)
    SELECT t1.term <> t2.term 
    FROM terms AS t1, terms AS t2 
    WHERE t1.id < t2.id;
$$ LANGUAGE SQL STRICT