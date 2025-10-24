--1.ชุดการคำนวณ Quality
CREATE OR REPLACE VIEW v_quality AS
SELECT 
    line_id, 
    txndate, 
    SUM(qty_in) AS qty_in,
    SUM(qty_out) AS qty_out,
    SUM(
        CASE 
            WHEN line_id = 'LINE2' THEN qty_out - qty_good
            ELSE qty_rej
        END
    ) AS qty_rej,
    SUM(
        CASE 
            WHEN line_id = 'LINE1' THEN qty_out - qty_rej
            ELSE qty_good
        END
    ) AS qty_good

FROM (
    SELECT DISTINCT
        line_id,
        start_time,
        CAST(start_time AS DATE) AS txndate,
        qty_in,
        qty_out,
        qty_rej,
		qty_good
    FROM lot
) AS sub
GROUP BY line_id, txndate;

CREATE OR REPLACE VIEW v_quality_lot AS
SELECT DISTINCT
    line_id,
    lot_id,
    start_time,
    qty_in,
    qty_out,
    CASE 
        WHEN line_id = 'LINE2' THEN COALESCE(qty_rej, qty_out - qty_good)
        ELSE qty_rej
    END AS qty_rej,
    CASE 
        WHEN line_id = 'LINE1' THEN COALESCE(qty_good, qty_out - qty_rej)
        ELSE qty_good
    END AS qty_good
FROM lot;

SELECT * FROM v_quality_Lot;

------------------------------------------------------------------------------------------------------------------
--2.ชุดการคำนวณเวลาการทำงานของเครื่องจักร
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

CREATE OR REPLACE VIEW v_line_state AS
WITH machine_line AS (
    SELECT
        m.machine_id,
        CASE 
            WHEN m.machine_id BETWEEN 'M01' AND 'M06' THEN 'LINE1'
            WHEN m.machine_id BETWEEN 'M07' AND 'M12' THEN 'LINE2'
        END AS line_id,
        m.start_time,
        m.end_time,
        m.state
    FROM machine_state m
),
line_periods AS (
    SELECT
        l.line_id,
        GREATEST(m.start_time, l.start_time) AS start_time,
        LEAST(m.end_time, l.end_time) AS end_time,
        m.state
    FROM lot l
    JOIN machine_line m
      ON m.line_id = l.line_id
     AND m.start_time < l.end_time
     AND m.end_time > l.start_time
)
SELECT
    line_id,
    start_time,
    end_time,
    state
FROM line_periods
WHERE start_time < end_time
ORDER BY line_id, start_time;

---------------------------------------------------------------------------------------------
--3.ชุดการคำนวณค่า OEE
CREATE OR REPLACE VIEW v_oee AS
SELECT 
    m.line_id,
    m.txndate,
    TO_CHAR(m.txndate, 'MON') AS month,
    c.quarter,
    c.year,
    ROUND((w.actual_work_time::double precision / w.sched_work_time::double precision)::numeric, 2) * 100 AS availability,
    ROUND(((q.qty_out::double precision / w.actual_work_time::double precision) / (SELECT idea_output_rating::double precision FROM config))::numeric * 100, 2) AS performance,
    ROUND(((q.qty_good::double precision ) / q.qty_out::double precision) * 100) AS quality,
    ROUND(
        (
            (w.actual_work_time::double precision / w.sched_work_time::double precision)
            * ((q.qty_out::double precision / w.actual_work_time::double precision) / (SELECT idea_output_rating::double precision FROM config))
            * ((q.qty_good::double precision  / q.qty_out::double precision))
        )::numeric * 100, 
        2
    ) AS oee
FROM v_machine_time m
JOIN calendar c 
    ON m.txndate >= c.start_date 
    AND m.txndate < c.end_date
LEFT JOIN v_quality q 
    ON m.line_id = q.line_id 
    AND m.txndate = q.txndate
LEFT JOIN v_work_time w 
    ON m.line_id = w.line_id 
    AND m.txndate = w.txndate;

SELECT * FROM V_OEE;

------- Report process
--1.
-- ลบข้อมูลทั้งหมดในตาราง
TRUNCATE TABLE machine_time;

-- ใส่ข้อมูลจาก view ลงในตาราง
INSERT INTO machine_time
SELECT * FROM v_machine_time;

--1 Reject
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
SET qty_good = g.good_count
FROM (
    SELECT l.lot_id, COUNT(*) AS good_count
    FROM ss_good g
    JOIN lot l
      ON g.input_time >= l.start_time
     AND g.input_time < l.end_time
    GROUP BY l.lot_id
) AS g
WHERE ll.lot_id = g.lot_id
  AND ll.line_id = 'LINE2';
--3 Output
UPDATE lot ll
SET qty_out = g.output_count
FROM (
    SELECT l.lot_id, COUNT(*) AS output_count
    FROM ss_output o
    JOIN lot l
      ON o.input_time >= l.start_time
     AND o.input_time < l.end_time
    GROUP BY l.lot_id
) AS g
WHERE ll.lot_id = g.lot_id;
--4 Update to lot
---------------------
UPDATE lot AS l
SET 
    qty_good = v.qty_good,
    qty_rej = v.qty_rej,
    qty_out = v.qty_out
FROM v_quality_lot AS v
WHERE l.lot_id = v.lot_id
  AND l.line_id = v.line_id;





