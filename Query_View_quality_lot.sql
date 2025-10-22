CREATE OR REPLACE VIEW v_quality_lot AS
SELECT DISTINCT
    line_id,
    lot_id,
    start_time,
    qty_in,
    COALESCE(qty_out, qty_good + qty_rej) AS qty_out,
    COALESCE(qty_rej, qty_out - qty_good) AS qty_rej,
    COALESCE(qty_good, qty_out - qty_rej) AS qty_good
FROM lot;
