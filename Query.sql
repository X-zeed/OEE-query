SELECT * from LOT;

CREATE OR REPLACE VIEW V_Quality AS
SELECT LINE_ID, TXNDATE, 
              SUM(QTY_IN) AS QTY_IN,
							SUM(NVL(QTY_OUT,QTY_IN-QTY_REJ)) AS QTY_OUT,
							SUM(NVL(QTY_REJ,0)) AS QTY_REJ
FROM
(
SELECT DISTINCT
     LINE_ID,
		 START_TIME,
		 TRUNC(START_TIME) AS TXNDATE,
		 QTY_IN,
		 QTY_OUT,
		 QTY_REJ 
FROM LOT
)
GROUP BY LINE_ID,TXNDATE;

CREATE OR REPLACE VIEW V_Quality_Lot AS
SELECT DISTINCT
     LINE_ID,
		 LOT_ID,
     START_TIME,
     QTY_IN,
     NVL(QTY_OUT,QTY_IN-QTY_REJ) AS QTY_OUT,
     NVL(QTY_REJ,0) AS QTY_REJ
FROM LOT;

SELECT * FROM V_Quality_Lot;

------------------------------------------------------------------------------------------------------------------
;

CREATE OR REPLACE VIEW V_WORK_TIME AS
SELECT LINE_ID,TXNDATE,
              (TOTAL_TIME - PM_TIME) AS SCHED_WORK_TIME,
							(TOTAL_TIME - PM_TIME) - DOWN_TIME AS ACTUAL_WORK_TIME 
FROM (
SELECT DISTINCT
             M.LINE_ID,
						 TRUNC(M.TXNDATE) AS TXNDATE,
						 M.PROD_TIME,M.DOWN_TIME,
						 (SELECT PM_TIME FROM CONFIG) AS PM_TIME,
						 (SELECT TOTAL_TIME FROM CONFIG) AS TOTAL_TIME
FROM MACHINE_TIME M
);


SELECT * from MACHINE_TIME;

CREATE OR REPLACE VIEW V_OEE AS
SELECT
      LINE_ID,
		 TXNDATE,
		 WW,
		 MONTH,
		 QUARTER,
		 YEAR,
		 ROUND(AVAILABILITY,2) AS AVAILABILITY,
		 ROUND(PERFORMANCE,2) AS PERFORMANCE, 
		 ROUND(QUALITY,2) AS QUALITY,
		 ROUND((AVAILABILITY *  PERFORMANCE * QUALITY) /100,2) AS OEE
FROM
(
SELECT DISTINCT 
     M.LINE_ID,
		 M.TXNDATE,
		 C.WW,
		 C.MONTH,
		 C.QUARTER,
		 C.YEAR,
		 (W.ACTUAL_WORK_TIME / W.SCHED_WORK_TIME) * 100 AS AVAILABILITY,
		 (Q.QTY_OUT/W.ACTUAL_WORK_TIME) / (SELECT IDEA_OUTPUT_RATING FROM CONFIG) * 100 AS PERFORMANCE,
		 CASE 
		    WHEN M.LINE_ID = 'LINE1' THEN   ((Q.QTY_IN - Q.QTY_REJ) / QTY_IN) * 100
				WHEN M.LINE_ID = 'LINE2' THEN  ((Q.QTY_OUT) / QTY_IN) * 100
				ELSE 0 END AS QUALITY
FROM MACHINE_TIME M,  
             CALENDAR C, 
						 V_QUALITY Q,
						 V_WORK_TIME W
WHERE M.TXNDATE >=  C.STARTDATE AND M.TXNDATE < C.ENDDATE
AND M.LINE_ID = Q.LINE_ID  AND M.TXNDATE = Q.TXNDATE
AND M.LINE_ID = W.LINE_ID AND M.TXNDATE  = W.TXNDATE
);

SELECT * FROM V_OEE;

------- Report process
--1.

INSERT INTO MACHINE_TIME
SELECT MACHINE_ID, LINE_ID,TXNDATE,
               DECODE(STATE,'PROD', STATE_TIME,0) AS PROD_TIME,
							 DECODE(STATE,'DOWN', STATE_TIME,0) AS DOWN_TIME
FROM
(
SELECT  DISTINCT M.MACHINE_ID, MC.LINE_ID, 
                M.START_TIME, M.END_TIME,STATE,
								TRUNC(M.START_TIME) AS TXNDATE,
								SUM(END_TIME - START_TIME) AS STATE_TIME
FROM machine_state M, machine MC
WHERE M.MACHINE_ID = MC.MACHINE_ID
GROUP BY M.MACHINE_ID, MC.LINE_ID, 
                M.START_TIME, M.END_TIME,STATE
);

--2 Reject
UPDATE lot AS ll
SET qty_rej = r.reject_count
FROM (
  SELECT l.lot_id, COUNT(*) AS reject_count
  FROM ss_reject AS r
  JOIN lot AS l
    ON r.input_time >= l.start_time
   AND r.input_time < l.end_time
  GROUP BY l.lot_id
) AS r
WHERE ll.lot_id = r.lot_id;


--2 Reject
UPDATE lot AS ll
SET qty_out = g.good_count
FROM (
  SELECT l.lot_id, COUNT(*) AS good_count
  FROM ss_good AS r
  JOIN lot AS l
    ON r.input_time >= l.start_time
   AND r.input_time < l.end_time
  GROUP BY l.lot_id
) AS g
WHERE ll.lot_id = g.lot_id;









