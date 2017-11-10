-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION sudokusolver" to load this file. \quit


-- Registers the solver and 1 method.
WITH 
     -- Registers the solver and its parameters.
     solver AS   (INSERT INTO sl_solver(name, version, author_name, author_url, description)
                  values ('sudokusolver', 1.0, '', '', 'The dedicated sudoku solver based on SOLVERLP by Laurynas Siksnys') 
                  returning sid),     

     -- Registers the BASIC method. It has no parameters.
     method1 AS  (INSERT INTO sl_solver_method(sid, name, name_full, func_name, prob_name, description)
                  SELECT sid, 'default', 'The dedicated Sudoku solver method', 'sudoku_solve_default', 'Sudoku problem', 'Solves the sudoku problem using the SOLVERLP' 
		  FROM solver RETURNING mid)

     -- Perform the actual insert
     SELECT count(*) FROM solver, method1;

-- Set the default method
UPDATE sl_solver s
SET default_method_id = mid
FROM sl_solver_method m
WHERE (s.sid = m.sid) AND (s.name = 'sudokusolver') AND (m.name='default');

-- This is a sudoku decision variable reference, and a contructor
-- DROP TYPE sudoku_var CASCADE;
CREATE TYPE sudoku_var AS (
  row_no	int,
  col_no 	int
);
CREATE FUNCTION sudoku_var_make(int, int) RETURNS sudoku_var AS $$ 
  SELECT ROW($1, $2)::sudoku_var;
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- Operators for constraining Sudoku cells
-- C (op) sudoku_var
-- Equality operator
CREATE FUNCTION sudoku_var_eq(int, sudoku_var) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'eq', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR = (LEFTARG = int, RIGHTARG = sudoku_var, COMMUTATOR = =, PROCEDURE = sudoku_var_eq);

-- Negation operator
CREATE FUNCTION sudoku_var_ne(int, sudoku_var) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($1, 'ne', $2);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR != (LEFTARG = int, RIGHTARG = sudoku_var, COMMUTATOR = !=, PROCEDURE = sudoku_var_ne);

-- sudoku_var (op) C
-- Equality operator
CREATE FUNCTION sudoku_var_eq(sudoku_var, int) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'eq', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR = (LEFTARG = sudoku_var, RIGHTARG = int, COMMUTATOR = =, PROCEDURE = sudoku_var_eq);

-- Negation operator
CREATE FUNCTION sudoku_var_ne(sudoku_var, int) RETURNS sl_ctr AS $$
   SELECT sl_ctr_make($2, 'ne', $1);
$$ LANGUAGE SQL IMMUTABLE STRICT;
CREATE OPERATOR != (LEFTARG = sudoku_var, RIGHTARG = int, COMMUTATOR = !=, PROCEDURE = sudoku_var_ne);


                                                                      
-- Install the solver method
CREATE OR REPLACE FUNCTION sudoku_solve_default(arg sl_solver_arg) RETURNS setof record AS $$
  DECLARE 
     t sl_attribute_desc;
     hasAttRow boolean = False;
     hasAttCol boolean = False;     
  BEGIN
     RAISE NOTICE 'Calling sudoku solver.';

     -- Check the schema and input data violations
     -- Check the schema
     FOR t IN (SELECT * FROM sl_get_attributes(arg)) LOOP
	IF t.att_kind = 'unknown'::sl_attribute_kind AND t.att_name <> 'val' THEN
	      RAISE EXCEPTION 'The unknown column must be called "val"!';
	   END IF;
	
	IF t.att_kind = 'known'::sl_attribute_kind AND t.att_name = 'col' THEN
	   hasAttCol = True;
	END IF;

	IF t.att_kind = 'known'::sl_attribute_kind AND t.att_name = 'row' THEN
	   hasAttRow = True;
	END IF;
     END LOOP;

     IF (NOT hasAttRow) OR (NOT hasAttCol) THEN
	RAISE EXCEPTION 'There must be "col" and "row" attributes in the table!';
     END IF;

     -- Check data
     
     IF arg.prb_rowcount <> 81 THEN
	RAISE EXCEPTION 'The SUDOKU solver required 9x9 = 81 rows in the input relation!';
     END IF;

     IF (arg.prb_varcount <> 81) OR (arg.prb_colcount <> 1) THEN
	RAISE EXCEPTION 'The SUDOKU solver works with a single unknown attribute only. !';
     END IF;

     -- Create a view on the input with 'id' column renamed     
     PERFORM sl_create_view(sl_build_out_rename(arg, sl_build_out(arg), 'id'::sl_attribute_kind, 'id_col'), 'sudoku_input');
     -- Create a model-view
     PERFORM sl_create_view(sl_build_dst_ctr_union(
		arg, 
		ROW('SELECT id_col, row, col, sudoku_var_make(row, col) as val FROM sudoku_input')::sl_viewsql_out, 
		'sl_ctr'), 'sudoku_ctrs');

  
     -- Create a view to solve the LP problem     
     CREATE TEMP VIEW sudoku_result AS 
	     SELECT id_col, col,row,val FROM (
		   SOLVESELECT sudoku(fval) AS (SELECT id_col,
		                         S.col,
					 S.row, 
					 V as val, 
					 COALESCE(S.val=V, false) as giv,
					 false as fval
				  FROM sudoku_input S, generate_series(1, 9) V)
		   SUBJECTTO 
			  -- Built-in constraints
			  (SELECT fval = giv FROM sudoku WHERE giv),
			  (SELECT sum(fval)=1 FROM sudoku GROUP BY col, row),
			  (SELECT sum(fval)=1 FROM sudoku GROUP BY val, row),
			  (SELECT sum(fval)=1 FROM sudoku GROUP BY val, col),
			  (SELECT sum(fval)=1 FROM sudoku GROUP BY val, ((col-1) / 3), ((row-1) / 3)),
			  -- Additional user-defined constraints
			  (SELECT fval = 1 FROM sudoku, sudoku_ctrs AS ctr(c) WHERE ('eq'::sl_ctr_type = sl_ctr_get_op(c)) AND 
										    (col = (sl_ctr_get_x(c, sudoku_var_make(0,0))).col_no) AND
										    (row = (sl_ctr_get_x(c, sudoku_var_make(0,0))).row_no) AND
										    (val = sl_ctr_get_c(c)::int)),

			  (SELECT fval = 0 FROM sudoku, sudoku_ctrs AS ctr(c) WHERE ('ne'::sl_ctr_type = sl_ctr_get_op(c)) AND 
										    (col = (sl_ctr_get_x(c, sudoku_var_make(0,0))).col_no) AND
										    (row = (sl_ctr_get_x(c, sudoku_var_make(0,0))).row_no) AND
										    (val = sl_ctr_get_c(c)::int))
			  
		   USING solverlp) s
	     WHERE fval
	     ORDER BY col, row;

     -- Solve the problem and return the result
     RETURN QUERY EXECUTE sl_return(arg, sl_build_out_join(arg, sl_build_out(arg), 'SELECT * FROM sudoku_result', 'id_col'));

     -- Clean-up
     DROP VIEW sudoku_result;     
     PERFORM sl_drop_view('sudoku_ctrs');
     PERFORM sl_drop_view('sudoku_input');
     
     RAISE NOTICE 'Sudoku solver completes.';
  END;
$$ LANGUAGE plpgsql VOLATILE STRICT;