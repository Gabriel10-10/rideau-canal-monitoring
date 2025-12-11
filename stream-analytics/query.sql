WITH Aggregates AS (
    SELECT
        location,
        System.Timestamp AS windowEndTime,
        AVG(iceThicknessCm)        AS avgIceThicknessCm,
        MIN(iceThicknessCm)        AS minIceThicknessCm,
        MAX(iceThicknessCm)        AS maxIceThicknessCm,
        AVG(surfaceTemperatureC)   AS avgSurfaceTemperatureC,
        MIN(surfaceTemperatureC)   AS minSurfaceTemperatureC,
        MAX(surfaceTemperatureC)   AS maxSurfaceTemperatureC,
        MAX(snowAccumulationCm)    AS maxSnowAccumulationCm,
        AVG(externalTemperatureC)  AS avgExternalTemperatureC,
        COUNT(*)                   AS readingCount
    FROM iothubfinal TIMESTAMP BY timestamp
    GROUP BY
        location,
        TumblingWindow(minute, 5)
)

-- ***** EXISTING OUTPUT TO COSMOS DB (unchanged) *****
SELECT
    CONCAT(location, '-', DATEDIFF(second, '1970-01-01T00:00:00Z', windowEndTime)) AS id,
    location,
    windowEndTime,
    avgIceThicknessCm,
    minIceThicknessCm,
    maxIceThicknessCm,
    avgSurfaceTemperatureC,
    minSurfaceTemperatureC,
    maxSurfaceTemperatureC,
    maxSnowAccumulationCm,
    avgExternalTemperatureC,
    readingCount,
    CASE
        WHEN avgIceThicknessCm >= 30 AND avgSurfaceTemperatureC <= -2 THEN 'Safe'
        WHEN avgIceThicknessCm >= 25 AND avgSurfaceTemperatureC <=  0 THEN 'Caution'
        ELSE 'Unsafe'
    END AS safetyStatus
INTO SensorAggregations        
FROM Aggregates;


-- ***** NEW OUTPUT TO BLOB STORAGE FOR ARCHIVAL *****
SELECT
    location,
    windowEndTime,
    avgIceThicknessCm,
    minIceThicknessCm,
    maxIceThicknessCm,
    avgSurfaceTemperatureC,
    minSurfaceTemperatureC,
    maxSurfaceTemperatureC,
    maxSnowAccumulationCm,
    avgExternalTemperatureC,
    readingCount,
    CASE
        WHEN avgIceThicknessCm >= 30 AND avgSurfaceTemperatureC <= -2 THEN 'Safe'
        WHEN avgIceThicknessCm >= 25 AND avgSurfaceTemperatureC <=  0 THEN 'Caution'
        ELSE 'Unsafe'
    END AS safetyStatus
INTO [historical-data]          
FROM Aggregates;
