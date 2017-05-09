-- Install data first
DROP TABLE IF EXISTS sudoku;
CREATE TABLE sudoku (
  ID   INT ,
  COL  INT ,
  LIN  INT ,
  VAL  INT ,
  PRIMARY KEY ( ID, COL, LIN )
  );

INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 1, 1, 2);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 1, 2, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 1, 3, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 1, 4, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 1, 5, 8);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 1, 6, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 1, 7, 7);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 1, 8, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 1, 9, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 2, 1, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 2, 2, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 2, 3, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 2, 4, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 2, 5, 1);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 2, 6, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 2, 7, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 2, 8, 9);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 2, 9, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 3, 1, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 3, 2, 3);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 3, 3, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 3, 4, 6);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 3, 5, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 3, 6, 9);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 3, 7, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 3, 8, 2);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 3, 9, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 4, 1, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 4, 2, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 4, 3, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 4, 4, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 4, 5, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 4, 6, 1);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 4, 7, 5);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 4, 8, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 4, 9, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 5, 1, 4);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 5, 2, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 5, 3, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 5, 4, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 5, 5, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 5, 6, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 5, 7, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 5, 8, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 5, 9, 3);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 6, 1, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 6, 2, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 6, 3, 9);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 6, 4, 7);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 6, 5, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 6, 6, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 6, 7, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 6, 8, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 6, 9, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 7, 1, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 7, 2, 6);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 7, 3, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 7, 4, 2);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 7, 5, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 7, 6, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 7, 7, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 7, 8, 8);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 7, 9, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 8, 1, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 8, 2, 2);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 8, 3, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 8, 4, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 8, 5, 4);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 8, 6, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 8, 7, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 8, 8, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 8, 9, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 9, 1, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 9, 2, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 9, 3, 4);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 9, 4, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 9, 5, 3);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 9, 6, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 9, 7, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 9, 8, 0);
INSERT INTO sudoku (ID, COL, LIN, VAL) VALUES (1, 9, 9, 9);


SELECT id, col, lin, val FROM (
   SOLVESELECT sel IN (SELECT id, col, lin, v as val, (val=v) as giv, NULL::boolean AS sel FROM sudoku,
                       generate_series(1,9) as v) as sudoku
   SUBJECTTO
          (SELECT sel = giv FROM sudoku WHERE giv),
          (SELECT sum(sel)=1 FROM sudoku GROUP BY lin, col),
          (SELECT sum(sel)=1 FROM sudoku GROUP BY val, lin),
          (SELECT sum(sel)=1 FROM sudoku GROUP BY val, col),
          (SELECT sum(sel)=1 FROM sudoku GROUP BY val, ((col-1) / 3), ((lin-1) / 3))
   USING solverlp) s
WHERE sel
ORDER BY col, lin;


