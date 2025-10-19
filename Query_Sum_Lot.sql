SELECT 
    lot_id,
    MAX(start_time) AS start_time,
    SUM(qty_in) AS qty_in,
    SUM(qty_out) AS qty_out,
    SUM(qty_rej) AS qty_rej
FROM v_quality_lot
WHERE lot_id = 'A002'
GROUP BY lot_id
ORDER BY lot_id;
