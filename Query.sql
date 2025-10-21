SELECT * from LOT;

CREATE OR REPLACE VIEW v_quality AS
SELECT 
    line_id, 
    txndate, 
    SUM(qty_in) AS qty_in,
    SUM(COALESCE(qty_out, qty_in - qty_rej)) AS qty_out,
    SUM(qty_rej) AS qty_rej
FROM (
    SELECT DISTINCT
        line_id,
        start_time,
        CAST(start_time AS DATE) AS txndate,
        COALESCE(qty_in, 0) AS qty_in,
        COALESCE(qty_out, 0) AS qty_out,
        COALESCE(qty_rej, 0) AS qty_rej
    FROM lot
) AS sub
GROUP BY line_id, txndate;

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

CREATE OR REPLACE VIEW v_work_time AS
SELECT 
    line_id,
    txndate,
    (total_time - pm_time) AS sched_work_time,
    (total_time - pm_time) - down_time AS actual_work_time
FROM (
    SELECT DISTINCT
        m.line_id,
        CAST(m.txn_date AS date) AS txndate,
        m.prod_time,
        m.down_time,
        (SELECT pm_time FROM config LIMIT 1) AS pm_time,
        (SELECT total_time FROM config LIMIT 1) AS total_time
    FROM machine_time m
) AS sub;

CREATE OR REPLACE VIEW v_machine_time AS
SELECT 
    machine_id,
    line_id,
    txndate,
    SUM(prod_time) AS prod_time,
    SUM(down_time) AS down_time
FROM (
    SELECT 
        machine_id,
        line_id,
        txndate,
        CASE 
            WHEN state = 'PROD' THEN state_time 
            ELSE 0 
        END AS prod_time,
        CASE 
            WHEN state IN ('UDOWN', 'SDOWN', 'IDLE', 'SETUP') THEN state_time 
            ELSE 0 
        END AS down_time
    FROM (
        SELECT 
            m.machine_id,
            mc.line_id,
            state,
            DATE(m.start_time) AS txndate,
            SUM(EXTRACT(EPOCH FROM (m.end_time - m.start_time)) / 3600) AS state_time
        FROM machine_state m
        JOIN machine mc ON m.machine_id = mc.machine_id
        GROUP BY m.machine_id, mc.line_id, state, DATE(m.start_time)
    ) sub1
) sub2
GROUP BY machine_id, line_id, txndate;



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
-- ลบข้อมูลทั้งหมดในตาราง
TRUNCATE TABLE machine_time;

-- ใส่ข้อมูลจาก view ลงในตาราง
INSERT INTO machine_time
SELECT * FROM v_machine_time;


--2 Reject
UPDATE lot ll
SET qty_rej = r.reject_count
FROM (
    SELECT l.lot_id, COUNT(*) AS reject_count
    FROM ss_reject r
    JOIN lot l
      ON r.input_time >= l.start_time
     AND r.input_time < l.end_time
    GROUP BY l.lot_id
) AS r
WHERE ll.lot_id = r.lot_id
  AND ll.line_id = 'LINE1';

--2 Good
UPDATE lot ll
SET qty_out = g.good_count
FROM (
    SELECT l.lot_id, COUNT(*) AS good_count
    FROM ss_good r
    JOIN lot l
      ON r.input_time >= l.start_time
     AND r.input_time < l.end_time
    GROUP BY l.lot_id
) AS g
WHERE ll.lot_id = g.lot_id
  AND ll.line_id = 'LINE2';
---------------------
UPDATE lot AS l
SET 
    qty_out = v.qty_out,
    qty_rej = v.qty_rej
FROM v_quality_lot AS v
WHERE l.lot_id = v.lot_id
  AND l.line_id = v.line_id;
---------------------

