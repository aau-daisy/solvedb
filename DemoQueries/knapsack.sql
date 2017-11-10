-- Install data first
DROP TABLE IF EXISTS item;
CREATE TABLE item (
	item text PRIMARY KEY,
	weight float8,
	profit float8,
	quantity int
);

INSERT INTO item (item, weight, profit, quantity)
VALUES ('item 1', 10.0, 5.0, NULL),
       ('item 2',  9.0, 4.5, NULL),
       ('item 3',  1.5, 2.0, NULL),
       ('item 4',  7.0, 3.0, NULL);

-- Solve the problem
SELECT * FROM (
SOLVESELECT u(quantity) AS (SELECT * FROM item)
MAXIMIZE  (SELECT SUM(quantity * profit) FROM u)
SUBJECTTO (SELECT SUM(quantity * weight) <= 15 FROM u),
	  (SELECT 0 <= quantity <=1 FROM u)
USING solverlp) AS s
