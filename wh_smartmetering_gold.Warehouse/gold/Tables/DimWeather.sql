CREATE TABLE [gold].[DimWeather] (

	[weather_key] bigint IDENTITY NOT NULL, 
	[region] varchar(50) NULL, 
	[date] date NULL, 
	[temperature_2m] decimal(5,2) NULL, 
	[weather_code] int NULL
);