CREATE OR REPLACE VIEW v_oee AS
SELECT 
    m.line_id,
    m.txn_date,
    TO_CHAR(m.txn_date, 'MON') AS month,
    c.quarter,
    c.year,
    ROUND((w.actual_work_time::double precision / w.sched_work_time::double precision)::numeric, 2) * 100 AS availability,
    ROUND(((q.qty_out::double precision / w.actual_work_time::double precision) / (SELECT idea_output_rating::double precision FROM config))::numeric * 100, 2) AS performance,
    ROUND(
        CASE 
            WHEN m.line_id = 'LINE1' THEN ((q.qty_in::double precision - q.qty_rej::double precision) / q.qty_in::double precision) * 100
            WHEN m.line_id = 'LINE2' THEN (q.qty_out::double precision / q.qty_in::double precision) * 100
            ELSE 0
        END::numeric, 
        2
    ) AS quality,
    ROUND(
        (
            (w.actual_work_time::double precision / w.sched_work_time::double precision)
            * ((q.qty_out::double precision / w.actual_work_time::double precision) / (SELECT idea_output_rating::double precision FROM config))
            * (
                CASE 
                    WHEN m.line_id = 'LINE1' THEN ((q.qty_in::double precision - q.qty_rej::double precision) / q.qty_in::double precision)
                    WHEN m.line_id = 'LINE2' THEN (q.qty_out::double precision / q.qty_in::double precision)
                    ELSE 0
                END
            )
        )::numeric * 100, 
        2
    ) AS oee
FROM machine_time m
JOIN calendar c 
    ON m.txn_date >= c.start_date 
    AND m.txn_date < c.end_date
LEFT JOIN v_quality q 
    ON m.line_id = q.line_id 
    AND m.txn_date = q.txndate
LEFT JOIN v_work_time w 
    ON m.line_id = w.line_id 
    AND m.txn_date = w.txndate;
