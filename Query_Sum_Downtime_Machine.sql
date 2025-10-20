SELECT 
    machine_id,
    SUM(down_time) AS total_down_time
FROM 
    v_machine_time
GROUP BY 
    machine_id
ORDER BY 
    total_down_time DESC;
