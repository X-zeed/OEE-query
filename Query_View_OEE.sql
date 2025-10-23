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
