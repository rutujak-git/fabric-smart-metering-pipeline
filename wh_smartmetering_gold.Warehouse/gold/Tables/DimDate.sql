CREATE TABLE [gold].[DimDate] (

	[date_key] bigint IDENTITY NOT NULL, 
	[full_date] date NULL, 
	[year] int NULL, 
	[month] int NULL, 
	[day] int NULL, 
	[month_name] varchar(20) NULL, 
	[day_name] varchar(20) NULL, 
	[quarter] int NULL
);