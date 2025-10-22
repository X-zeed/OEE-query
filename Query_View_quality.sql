drop VIEW IF EXISTS v_quality;

CREATE OR REPLACE VIEW v_quality AS
SELECT 
    line_id, 
    txndate, 
    SUM(qty_in) AS qty_in,
    SUM(COALESCE(qty_out, qty_good + qty_rej)) AS qty_out,
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
        COALESCE(qty_in, 0) AS qty_in,
        COALESCE(qty_out, 0) AS qty_out,
        COALESCE(qty_rej, 0) AS qty_rej,
	COALESCE(qty_good, 0) AS qty_good
    FROM lot
) AS sub
GROUP BY line_id, txndate;
