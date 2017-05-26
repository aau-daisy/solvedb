--drop function join_prediction_and_original_table(text,text, text[], text[]);
create or replace function join_prediction_and_original_table(input_table text, forecast_table text, joining_clmns text[], not_joining_clmns text[])
RETURNS void
AS $$
DECLARE
	query text;
	col   text;
	i     integer;
BEGIN
	query := 'CREATE OR REPLACE TEMP VIEW TMP_JOINED_TABLE AS ( SELECT ';
	if array_length(not_joining_clmns,1) > 0 THEN
		FOREACH col IN ARRAY not_joining_clmns LOOP
			query := query || col || ', ';
		END LOOP;
	end if;
	FOR i IN 0..array_length(joining_clmns,1) -1 LOOP
		query := query || joining_clmns[i] || ', ';
	END LOOP;
-- 	query := query || joining_clmns[i] || ' FROM ' || input_table || ' UNION ALL SELECT ';
-- 
-- 	IF array_length(not_joining_clmns,1) > 0 THEN
-- 		FOREACH col IN ARRAY not_joining_clmns LOOP
-- 			query := query || 'null as'  ||  col  || ', ';
-- 		END LOOP;	
-- 	END IF;
-- 	FOR i IN 0..array_length(joining_clmns,1)-1 LOOP
-- 		query := query || 't2.'  ||   joining_clmns[i] || ', ';
-- 	END LOOP;
-- 	query := query || 't2.'  ||   joining_clmns[i]   ||  ' FROM '  ||   forecast_table   ||  ' AS t2 LEFT JOIN ';
-- 	query := query || input_table  || ' AS t1 ON ';
-- 	FOR i IN 0..array_length(joining_clmns, 1)-1 LOOP
-- 		query := query || 't2.'  || joining_clmns[i] || ' = t1.'  ||  joining_clmns[i]  || ' AND ';
-- 	END LOOP;
-- 	query := query || 't2.'  || joining_clmns[i] || ' = t1.'  ||  joining_clmns[i];

	RAISE NOTICE 'query ---------- %', query;
END;
$$ language 'plpgsql';


--select * from join_prediction_and_original_table('Test', 'tmp_forecasting_table_Test')



