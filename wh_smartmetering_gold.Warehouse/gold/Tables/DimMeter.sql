CREATE TABLE [gold].[DimMeter] (

	[meter_key] bigint IDENTITY NOT NULL, 
	[meter_id] varchar(50) NULL, 
	[customer_id] varchar(50) NULL, 
	[install_date] date NULL, 
	[meter_type] varchar(50) NULL, 
	[region] varchar(50) NULL, 
	[data_quality_flag] varchar(100) NULL
);