CREATE OR REPLACE FUNCTION update_throughput()
RETURNS TRIGGER AS $$
DECLARE
    lot_start TIMESTAMP;
    time_diff DOUBLE PRECISION;
    total_qty_out INTEGER;
    throughput_value DOUBLE PRECISION;
    target_lot_id TEXT;
BEGIN
    -- หา lot ปัจจุบันของ line_id ที่เพิ่งมีการ insert เข้ามา
    SELECT lot_id, start_time
    INTO target_lot_id, lot_start
    FROM lot
    WHERE line_id = NEW.line_id
      AND (end_time IS NULL OR NEW.input_time <= end_time)
      AND NEW.input_time >= start_time
    ORDER BY start_time DESC
    LIMIT 1;

    IF target_lot_id IS NOT NULL THEN
        -- เวลาที่เครื่องทำงานทั้งหมด (วินาที)
        SELECT EXTRACT(EPOCH FROM (NEW.input_time - lot_start))
        INTO time_diff;

        -- เอาจำนวน qty_out ล่าสุดของ lot นั้นมาใช้
        SELECT COALESCE(qty_out, 0)
        INTO total_qty_out
        FROM lot
        WHERE lot_id = target_lot_id;

        -- คำนวณ throughput = qty_out / เวลา(นาที)
        IF time_diff > 0 THEN
            throughput_value := total_qty_out / (time_diff / 60.0);
        ELSE
            throughput_value := 0;
        END IF;

        -- อัปเดตค่ากลับเข้า lot
        UPDATE lot
        SET throughput = throughput_value
        WHERE lot_id = target_lot_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_throughput
AFTER INSERT ON ss_output
FOR EACH ROW
EXECUTE FUNCTION update_throughput();
