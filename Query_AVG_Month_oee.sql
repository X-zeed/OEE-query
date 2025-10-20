SELECT 
    month,
    ROUND(AVG(availability)::numeric, 2) AS avg_availability,
    ROUND(AVG(performance)::numeric, 2) AS avg_performance,
    ROUND(AVG(quality)::numeric, 2) AS avg_quality,
    ROUND(AVG(oee)::numeric, 2) AS avg_oee
FROM oee
WHERE month = 'JAN'
GROUP BY month;
