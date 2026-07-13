CREATE TABLE [gold].[FactMeterReadings] (

	[fact_key] bigint IDENTITY NOT NULL, 
	[meter_key] bigint NULL, 
	[customer_key] bigint NULL, 
	[tariff_zone_key] bigint NULL, 
	[date_key] bigint NULL, 
	[weather_key] bigint NULL, 
	[consumption_kwh] decimal(10,2) NULL, 
	[data_quality_flag] varchar(100) NULL, 
	[reading_datetime] datetime2(6) NULL
);