-- LPsolver regression tests

create extension solverapi;
create extension solverLP;

-- Test function creation for unknown variables
select lp_function_make(1);
-- Test function creation for integers
select (1)::lp_function;
-- Test function creation for numericals
select (1.5)::lp_function;
-- Test function creation for booleans
select (true)::lp_function;

-- Test implicit casts
select lp_function_make(1) + 1;
select lp_function_make(1) + 1.5;
select lp_function_make(1) + true;

-- Test constant-function multiplication
select 2*(lp_function_make(1) + 10);
select (lp_function_make(1) + 10)*2;

-- Test constant-function division
select (3*lp_function_make(1)+10)/2;

-- Test function-function addition
select (3*lp_function_make(1) + 5) + (lp_function_make(2) + 10); -- when x1<x2
select (lp_function_make(2) + 10) + (3*lp_function_make(1) + 5); -- when x1>x2
select (lp_function_make(1) + 10) + (3*lp_function_make(1) + 5); -- when x1=x2

-- Test function aggregation
select sum(pol) from (values (3::lp_function), (2::lp_function)) as v (pol);

-- Test function-function substraction
select (3*lp_function_make(1) + 5) - (lp_function_make(2) + 10); -- when x1<x2
select (lp_function_make(2) + 10) - (3*lp_function_make(1) + 5); -- when x1>x2
select (lp_function_make(1) + 10) - (3*lp_function_make(1) + 5); -- when x1=x2

-- Test function assignment/inequality type
select 8 = 3::lp_function;
select 3::lp_function = 8;

-- Test constant-function inequalities
select 8 > 3::lp_function;
select 8 >= 3::lp_function;
select 8 < 3::lp_function;
select 8 <= 3::lp_function;

-- Test function-constant inequalities
select 3::lp_function > 8;
select 3::lp_function >= 8;
select 3::lp_function < 8;
select 3::lp_function <= 8;

-- Test function-function inequalities

select 3::lp_function > 2::lp_function;
select 3::lp_function >= 2::lp_function;
select 3::lp_function < 2::lp_function;
select 3::lp_function <= 2::lp_function;

-- Test the solver for SUDOKU (from the example from http://en.wikipedia.org/wiki/Sudoku)

create table sudoku_tmp
as (select (row_number() over ()) as id, col, row, val, (null::boolean) as giv, (null::boolean) as fval 
    from generate_series(1,9) as col, generate_series(1,9) as row, generate_series(1,9) as val);
-- Setup the givens
update sudoku_tmp
set giv = true
where (col, row, val) in (VALUES (1,9,5),(1,8,6),(1,6,8),(1,5,4),(1,4,7),
                                 (2,9,3),(2,7,9),(2,3,6),
                                 (3,7,8),
                                 (4,8,1),(4,5,8),(4,2,4),
                                 (5,9,7),(5,8,9),(5,6,6),(5,4,2),(5,2,1),(5,1,8),
                                 (6,8,5),(6,5,3),(6,2,9),
                                 (7,3,2),
                                 (8,7,6),(8,3,8),(8,1,7),
                                 (9,6,3),(9,5,1),(9,4,6),(9,2,5),(9,1,9));
-- call the solver
select lp_problem_solve(ARRAY[['tbl_name',  'sudoku_tmp'],
			      ['col_unique','id'],
			      ['col_unknown','fval'],
			      -- assign pre-defined numbers using the "givens"
			      ['ctr_sql','SELECT fval = giv FROM sudoku_tmp WHERE giv'], 
			      -- each cell must be assigned exactly one number
			      ['ctr_sql','SELECT sum(fval)=1 FROM sudoku_tmp GROUP BY col, row'],
			      -- cells in the same row must be assigned distinct numbers			  
			      ['ctr_sql','SELECT sum(fval)=1 FROM sudoku_tmp GROUP BY val, row'],
			      -- cells in the same col must be assigned distinct numbers			  
			      ['ctr_sql','SELECT sum(fval)=1 FROM sudoku_tmp GROUP BY val, col'],
			      -- cells in the same region must be assigned distinct numbers
			      ['ctr_sql','SELECT sum(fval)=1 FROM sudoku_tmp GROUP BY val, ((col-1) / 3), ((row-1) / 3)']
			     ]);

SELECT * FROM (
   SOLVESELECT fval IN (SELECT * FROM sudoku_tmp) as sudoku
   SUBJECTTO (SELECT fval = giv FROM sudoku WHERE giv),
	  (SELECT sum(fval)=1 FROM sudoku GROUP BY col, row),
	  (SELECT sum(fval)=1 FROM sudoku GROUP BY val, row),
	  (SELECT sum(fval)=1 FROM sudoku GROUP BY val, col),
	  (SELECT sum(fval)=1 FROM sudoku GROUP BY val, ((col-1) / 3), ((row-1) / 3))
   WITH solverlp) s
WHERE fval
ORDER BY col, row;

select * from sudoku_tmp
where fval
order by col, row, val;

drop table sudoku_tmp;

-- Solve the optimization problem from the GLPK example, (glpk.pdf, Sec. 1.3.1)
create table prob1
(
  id int,
  o int,
  v1 int,
  v2 int,
  v3 int,
  x float8
);

insert into prob1(id, o, v1, v2, v3)
values (1, 10, 1 ,10, 2),
       (2,  6, 1 , 4, 2),
       (3,  4, 1 , 5, 6);

-- call the solver
select lp_problem_solve(ARRAY[['tbl_name',  'prob1'],
			      ['col_unique','id'],
			      ['col_unknown','x'],
			      ['obj_dir','maximize'],
			      ['ctr_sql','SELECT x>=0 FROM prob1'],
			      ['obj_sql','SELECT sum(x*o) FROM prob1'],
			      ['ctr_sql','SELECT sum(x*v1)<=100 FROM prob1'],
			      ['ctr_sql','SELECT sum(x*v2)<=600 FROM prob1'],
			      ['ctr_sql','SELECT sum(x*v3)<=300 FROM prob1']
			     ]);

SOLVESELECT x IN (SELECT * FROM prob1) as prob1
MAXIMIZE (SELECT sum(x*o) FROM prob1)
SUBJECTTO (SELECT x>=0 FROM prob1),
	  (SELECT sum(x*v1)<=100 FROM prob1),
	  (SELECT sum(x*v2)<=600 FROM prob1),
	  (SELECT sum(x*v3)<=300 FROM prob1)
WITH solverlp;

select * from prob1;

drop table prob1;
