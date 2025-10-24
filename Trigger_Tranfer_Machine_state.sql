-- 1️⃣ สร้าง trigger function
CREATE OR REPLACE FUNCTION trg_update_machine_state()
RETURNS TRIGGER AS $$
BEGIN
    -- ลบข้อมูลเก่าของ machine_id ที่มีใน machine_state เพื่อ prevent duplication
    DELETE FROM machine_state
    WHERE machine_id IN (SELECT DISTINCT machine_id FROM machine_state_input);

    -- Insert ข้อมูลใหม่จาก logic ของคุณ
    WITH numbered AS (
        SELECT
            machine_id,
            state,
            time_input,
            ROW_NUMBER() OVER (PARTITION BY machine_id ORDER BY time_input) AS rn,
            ROW_NUMBER() OVER (PARTITION BY machine_id, state ORDER BY time_input) AS rn_state
        FROM machine_state_input
    ),
    grouped AS (
        SELECT
            machine_id,
            state,
            MIN(time_input) AS start_time,
            MAX(time_input) AS end_time
        FROM numbered
        GROUP BY
            machine_id,
            state,
            rn - rn_state
    )
    INSERT INTO machine_state (machine_id, start_time, end_time, state)
    SELECT
        machine_id,
        start_time,
        end_time,
        state
    FROM grouped
    ORDER BY machine_id, start_time;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 2️⃣ สร้าง trigger บน table machine_state_input
CREATE TRIGGER trg_machine_state_after_insert
AFTER INSERT ON machine_state_input
FOR EACH STATEMENT
EXECUTE FUNCTION trg_update_machine_state();
