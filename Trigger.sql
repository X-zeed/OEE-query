-- 1️⃣ สร้าง Trigger Function ก่อน
CREATE OR REPLACE FUNCTION update_lot_after_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. อัปเดต qty_rej
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

    -- 2. อัปเดต qty_good
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

    -- 3. อัปเดต qty_out
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

    -- 4. อัปเดตจาก View (v_quality_lot)
    UPDATE lot AS l
    SET 
        qty_good = v.qty_good,
        qty_rej = v.qty_rej,
        qty_out = v.qty_out
    FROM v_quality_lot AS v
    WHERE l.lot_id = v.lot_id
      AND l.line_id = v.line_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2️⃣ สร้าง Trigger สำหรับแต่ละตาราง
CREATE TRIGGER trg_update_lot_after_insert_reject
AFTER INSERT ON ss_reject
FOR EACH ROW
EXECUTE FUNCTION update_lot_after_insert();

CREATE TRIGGER trg_update_lot_after_insert_good
AFTER INSERT ON ss_good
FOR EACH ROW
EXECUTE FUNCTION update_lot_after_insert();

CREATE TRIGGER trg_update_lot_after_insert_output
AFTER INSERT ON ss_output
FOR EACH ROW
EXECUTE FUNCTION update_lot_after_insert();



CREATE OR REPLACE VIEW t_oee AS 
SELECT 
    m.line_id,
    m.txndate,
    TO_CHAR(m.txndate, 'MON') AS month,
    c.quarter,
    c.year,
    ROUND((w.actual_work_time::double precision / w.sched_work_time::double precision)::numeric, 2) * 100 AS availability,
    ROUND(((q.qty_out::double precision / w.actual_work_time::double precision) / (SELECT idea_output_rating::double precision FROM config))::numeric * 100, 2) AS performance,
    ROUND(((q.qty_good::double precision) / q.qty_out::double precision) * 100) AS quality,
    ROUND(
        (
            (w.actual_work_time::double precision / w.sched_work_time::double precision)
            * ((q.qty_out::double precision / w.actual_work_time::double precision) / (SELECT idea_output_rating::double precision FROM config))
            * ((q.qty_good::double precision / q.qty_out::double precision))
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
   AND m.txndate = w.txndate
WHERE m.txndate::date = CURRENT_DATE;

