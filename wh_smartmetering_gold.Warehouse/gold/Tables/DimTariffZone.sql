CREATE TABLE [gold].[DimTariffZone] (

	[tariff_zone_key] bigint IDENTITY NOT NULL, 
	[tariff_zone_id] int NULL, 
	[zone_name] varchar(100) NULL, 
	[rate_per_kwh] decimal(10,4) NULL, 
	[rate_status] varchar(50) NULL
);