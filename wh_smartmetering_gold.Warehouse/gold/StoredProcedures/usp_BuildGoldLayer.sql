CREATE PROCEDURE gold.usp_BuildGoldLayer
AS
BEGIN

-- 1. DimCustomer (incremental merge)
MERGE gold.DimCustomer AS target
USING (
    SELECT customer_id, region, tariff_zone_id
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_id) AS rn
        FROM lh_smartmetering.silver.silver_customers
    ) x WHERE rn = 1
) AS source
ON target.customer_id = source.customer_id
WHEN MATCHED THEN
    UPDATE SET region = source.region, tariff_zone_id = source.tariff_zone_id
WHEN NOT MATCHED THEN
    INSERT (customer_id, region, tariff_zone_id)
    VALUES (source.customer_id, source.region, source.tariff_zone_id);

-- 2. DimMeter (incremental merge)
MERGE gold.DimMeter AS target
USING (
    SELECT meter_id, customer_id, install_date, meter_type, region, data_quality_flag
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY meter_id ORDER BY meter_id) AS rn
        FROM lh_smartmetering.silver.silver_meters
    ) x WHERE rn = 1
) AS source
ON target.meter_id = source.meter_id
WHEN MATCHED THEN
    UPDATE SET customer_id = source.customer_id, install_date = source.install_date,
               meter_type = source.meter_type, region = source.region,
               data_quality_flag = source.data_quality_flag
WHEN NOT MATCHED THEN
    INSERT (meter_id, customer_id, install_date, meter_type, region, data_quality_flag)
    VALUES (source.meter_id, source.customer_id, source.install_date, source.meter_type,
            source.region, source.data_quality_flag);

-- 3. DimTariffZone (incremental merge)
MERGE gold.DimTariffZone AS target
USING lh_smartmetering.silver.silver_tariff_zones AS source
ON target.tariff_zone_id = source.tariff_zone_id
WHEN MATCHED THEN
    UPDATE SET zone_name = source.zone_name, rate_per_kwh = source.rate_per_kwh,
               rate_status = source.rate_status
WHEN NOT MATCHED THEN
    INSERT (tariff_zone_id, zone_name, rate_per_kwh, rate_status)
    VALUES (source.tariff_zone_id, source.zone_name, source.rate_per_kwh, source.rate_status);

-- 4. DimWeather (incremental merge, keyed on region + date)
MERGE gold.DimWeather AS target
USING lh_smartmetering.silver.silver_weather AS source
ON target.region = source.region AND target.date = source.date
WHEN MATCHED THEN
    UPDATE SET temperature_2m = source.temperature_2m, weather_code = source.weather_code
WHEN NOT MATCHED THEN
    INSERT (region, date, temperature_2m, weather_code)
    VALUES (source.region, source.date, source.temperature_2m, source.weather_code);

-- 5. DimDate (only insert new dates, based on new meter reading range)
INSERT INTO gold.DimDate (full_date, year, month, day, month_name, day_name, quarter)
SELECT full_date, YEAR(full_date), MONTH(full_date), DAY(full_date),
       DATENAME(MONTH, full_date), DATENAME(WEEKDAY, full_date), DATEPART(QUARTER, full_date)
FROM (
    SELECT DISTINCT CAST(reading_datetime AS DATE) AS full_date
    FROM lh_smartmetering.silver.silver_meter_readings
) src
WHERE NOT EXISTS (
    SELECT 1 FROM gold.DimDate d WHERE d.full_date = src.full_date
);

-- 6. FactMeterReadings (only insert readings not already loaded)
INSERT INTO gold.FactMeterReadings 
    (meter_key, customer_key, tariff_zone_key, date_key, weather_key, consumption_kwh, data_quality_flag, reading_datetime)
SELECT 
    m.meter_key, c.customer_key, t.tariff_zone_key, d.date_key, w.weather_key,
    r.consumption_kwh, r.data_quality_flag, r.reading_datetime
FROM lh_smartmetering.silver.silver_meter_readings r
LEFT JOIN gold.DimMeter m ON CAST(r.meter_id AS VARCHAR(50)) = m.meter_id
LEFT JOIN gold.DimCustomer c ON m.customer_id = c.customer_id
LEFT JOIN gold.DimTariffZone t ON CAST(c.tariff_zone_id AS INT) = t.tariff_zone_id
LEFT JOIN gold.DimDate d ON CAST(r.reading_datetime AS DATE) = d.full_date
LEFT JOIN gold.DimWeather w ON c.region = w.region AND CAST(r.reading_datetime AS DATE) = w.date
WHERE r.data_quality_flag = 'Valid' 
  AND r.meter_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM gold.FactMeterReadings f 
      WHERE f.reading_datetime = r.reading_datetime 
      AND f.meter_key = m.meter_key
  );

END