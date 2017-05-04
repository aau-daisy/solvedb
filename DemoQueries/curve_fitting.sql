-- Create the points tables
DROP TABLE IF EXISTS points;
CREATE TABLE points AS
SELECT id, x, (1.3*x + 1) as y FROM 
    (SELECT id, (id*2.0) as x FROM generate_series(0, 100) AS id) AS X;

-- Check the content of the table
SELECT * FROM points;

-- Distribute points on a circle of the radius 10.
SOLVESELECT a, b IN (SELECT NULL::float8 AS a, NULL::float8 AS b) AS t
MINIMIZE   (SELECT sum(abs(y - (a*x+b))) FROM t, points)
SUBJECTTO  (SELECT -100<=a<=100, -100<=b<=100 FROM t)
USING swarmops.pso(n:=30000);

-- Drop the table
DROP TABLE points;