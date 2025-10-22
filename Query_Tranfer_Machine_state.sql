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
    CASE 
        WHEN end_time = (SELECT MAX(time_input) 
                         FROM machine_state_input m2 
                         WHERE m2.machine_id = grouped.machine_id)
        THEN end_time   -- ใช้เวลาสุดท้ายจาก machine_state_input
        ELSE end_time
    END AS end_time,
    state
FROM grouped
ORDER BY machine_id, start_time;
