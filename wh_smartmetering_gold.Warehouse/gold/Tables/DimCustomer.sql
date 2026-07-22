CREATE TABLE [gold].[DimCustomer] (

	[customer_key] bigint IDENTITY NOT NULL, 
	[customer_id] varchar(50) NULL, 
	[region] varchar(50) NULL, 
	[tariff_zone_id] varchar(50) NULL
);