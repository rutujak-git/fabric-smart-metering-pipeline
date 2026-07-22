[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Customers_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "customer_id", DestinationColumnName = "customer_id"], [SourceColumnName = "customer_name", DestinationColumnName = "customer_name"], [SourceColumnName = "region", DestinationColumnName = "region"], [SourceColumnName = "signup_date", DestinationColumnName = "signup_date"], [SourceColumnName = "tariff_zone_id", DestinationColumnName = "tariff_zone_id"]}], DynamicSchema = true, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared Customers = let
  Source = OneLake.SqlAnalytics("c50a881a-f4eb-402e-a192-efe134697892", "mirror_smartmetering_sql", "MountedRelationalDatabase"),
  #"Navigation 1" = Source{[Schema = "dbo", Item = "Customers"]}[Data],
  #"Capitalized each word" = Table.TransformColumns(#"Navigation 1", {{"region", each Text.Proper(_), type nullable text}}),
  #"Capitalized each word 1" = Table.TransformColumns(#"Capitalized each word", {{"customer_name", each Text.Proper(_), type nullable text}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Capitalized each word 1", "updated_tariff_zone_id", each if [tariff_zone_id] = null then
    if [region] = "Ontario" then 1
    else if [region] = "Quebec" then 2
    else if [region] = "Alberta" then 3
    else if [region] = "British Columbia" then 4
    else null
else [tariff_zone_id]), {{"updated_tariff_zone_id", Int64.Type}}),
  #"Removed columns" = Table.RemoveColumns(#"Added custom", {"MSSQL_System_Uniquifier_1845581613", "tariff_zone_id"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed columns", {{"updated_tariff_zone_id", "tariff_zone_id"}}),
  #"Filtered rows" = Table.SelectRows(#"Renamed columns", each [customer_id] <> null and [customer_id] <> "")
in
  #"Filtered rows";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Meters_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "meter_id", DestinationColumnName = "meter_id"], [SourceColumnName = "customer_id", DestinationColumnName = "customer_id"], [SourceColumnName = "meter_type", DestinationColumnName = "meter_type"], [SourceColumnName = "install_date", DestinationColumnName = "install_date"], [SourceColumnName = "region", DestinationColumnName = "region"], [SourceColumnName = "data_quality_flag", DestinationColumnName = "data_quality_flag"]}], DynamicSchema = true, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared Meters = let
  Source = OneLake.SqlAnalytics("c50a881a-f4eb-402e-a192-efe134697892", "mirror_smartmetering_sql", "MountedRelationalDatabase"),
  #"Navigation 1" = Source{[Schema = "dbo", Item = "Meters"]}[Data],
  #"Removed columns" = Table.RemoveColumns(#"Navigation 1", {"MSSQL_System_Uniquifier_1861581670"}),
  #"Filtered rows" = Table.SelectRows(#"Removed columns", each [meter_id] <> null and [meter_id] <> ""),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Filtered rows", "data_quality_flag", each let
    issues = List.RemoveNulls({
        if [install_date] = null then "missing install date" else null,
        if [meter_type] = null then "missing meter type" else null,
        if [region] = null then "missing region" else null
    })
in
    if List.Count(issues) = 0 then "Valid" else Text.Combine(issues, ", ")), {{"data_quality_flag", type text}})
in
  #"Added custom";
shared Customers_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "c50a881a-f4eb-402e-a192-efe134697892"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "94a00be1-8ba8-46ec-9271-6db7014aed81"]}[Data],
  Navigation_3 = Navigation_2{[Id = "silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "silver_customers", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
shared Meters_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "c50a881a-f4eb-402e-a192-efe134697892"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "94a00be1-8ba8-46ec-9271-6db7014aed81"]}[Data],
  Navigation_3 = Navigation_2{[Id = "silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "silver_meters", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "tariff-zones_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"tariff-zones" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c50a881a-f4eb-402e-a192-efe134697892"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "94a00be1-8ba8-46ec-9271-6db7014aed81"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Files", ItemKind = "Folder"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Name = "tariff-zones"]}[Content],
  #"Navigation 4" = #"Navigation 3"{[Name = "col-089742f8-738d-45e7-bc14-f67eb3ab25c9=tariff_zones_messy.csv"]}[Content],
  #"Navigation 5" = #"Navigation 4"{[Name = "part-00000-787938bf-bad6-4be9-a69a-b8026daeff61.c000.snappy.parquet"]}[Content],
  #"Imported Parquet" = Parquet.Document(#"Navigation 5"),
  #"Renamed columns" = Table.RenameColumns(#"Imported Parquet", {{"col-9171568b-5d63-47c4-ab09-6a92f5b90c65", "tariff_zone_id"}, {"col-b511cc31-99c7-4c57-8a79-f887cb942c5f", "zone_name"}, {"col-5b795396-138e-48d6-82de-1f2a2b318182", "rate_per_kwh"}}),
  #"Removed columns" = Table.RemoveColumns(#"Renamed columns", {"col-6b7645a6-d7ac-432d-82ae-779a1f17a734", "col-001e8990-a6e3-4e5e-9a97-e3c62dcada0c"}),
  #"Removed duplicates" = Table.Distinct(#"Removed columns", {"tariff_zone_id"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Removed duplicates", "rate_status", each if [rate_per_kwh] = null then "Missing rate" else "Valid"), {{"rate_status", type text}})
in
  #"Added custom";
shared #"tariff-zones_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "c50a881a-f4eb-402e-a192-efe134697892"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "94a00be1-8ba8-46ec-9271-6db7014aed81"]}[Data],
  Navigation_3 = Navigation_2{[Id = "silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "silver_tariff_zones", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "meter-readings_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "meter_id", DestinationColumnName = "meter_id"], [SourceColumnName = "reading_datetime", DestinationColumnName = "reading_datetime"], [SourceColumnName = "consumption_kwh", DestinationColumnName = "consumption_kwh"], [SourceColumnName = "reading_type", DestinationColumnName = "reading_type"], [SourceColumnName = "data_quality_flag", DestinationColumnName = "data_quality_flag"], [SourceColumnName = "duplicate_count", DestinationColumnName = "duplicate_count"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"meter-readings" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c50a881a-f4eb-402e-a192-efe134697892"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "94a00be1-8ba8-46ec-9271-6db7014aed81"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Files", ItemKind = "Folder"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Name = "bronze"]}[Content],
  #"Navigation 4" = #"Navigation 3"{[Name = "meter-readings"]}[Content],
  Custom = Table.Combine(List.Transform(#"Navigation 4"[Content], each Table.PromoteHeaders(Csv.Document(_, [Delimiter=",", Encoding=65001]), [PromoteAllScalars=true]))),
  #"Changed column type" = Table.TransformColumnTypes(Custom, {{"meter_id", Int64.Type}, {"reading_datetime", type datetime}, {"consumption_kwh", type number}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type", "data_quality_flag", each let
    issues = List.RemoveNulls({
        if [meter_id] = null then "missing meter_id" else null,
        if [consumption_kwh] < 0 then "negative consumption" else null,
        if [consumption_kwh] > 200 then "outlier consumption" else null,
        if [reading_datetime] > DateTime.LocalNow() then "future-dated reading" else null
    })
in
    if List.Count(issues) = 0 then "Valid" else Text.Combine(issues, ", ")), {{"data_quality_flag", type text}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "duplicate_count", each Table.RowCount(Table.SelectRows(#"Added custom", (r) => r[meter_id] = [meter_id] and r[reading_datetime] = [reading_datetime]))), {{"duplicate_count", Int64.Type}})
in
  #"Added custom 1";
shared #"meter-readings_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "c50a881a-f4eb-402e-a192-efe134697892"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "94a00be1-8ba8-46ec-9271-6db7014aed81"]}[Data],
  Navigation_3 = Navigation_2{[Id = "silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "silver_meter_readings", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "weather_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "region", DestinationColumnName = "region"], [SourceColumnName = "date", DestinationColumnName = "date"], [SourceColumnName = "temperature_2m", DestinationColumnName = "temperature_2m"], [SourceColumnName = "weather_code", DestinationColumnName = "weather_code"], [SourceColumnName = "ingested_at", DestinationColumnName = "ingested_at"], [SourceColumnName = "data_quality_flag", DestinationColumnName = "data_quality_flag"]}], DynamicSchema = true, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared weather = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c50a881a-f4eb-402e-a192-efe134697892"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "94a00be1-8ba8-46ec-9271-6db7014aed81"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Files", ItemKind = "Folder"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Name = "bronze"]}[Content],
  #"Navigation 4" = #"Navigation 3"{[Name = "weather"]}[Content],
  Custom = Table.Combine(List.Transform(#"Navigation 4"[Content], each Table.PromoteHeaders(Csv.Document(_, [Delimiter=",", Encoding=65001]), [PromoteAllScalars=true]))),
  #"Changed column type" = Table.TransformColumnTypes(Custom, {{"date", type date}, {"region", type text}, {"temperature_2m", type number}, {"weather_code", Int64.Type}, {"ingested_at", type datetime}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type", "data_quality_flag", each if [temperature_2m] = null then "Missing Temperature"
else if [weather_code] = null then "Missing Weather Code"
else if [date] = null then "Missing Date"
else if Date.From([date]) > Date.From(DateTimeZone.FixedLocalNow()) then "Future Date"
else "OK"), {{"data_quality_flag", type text}}),
  #"Sorted rows" = Table.Sort(#"Added custom", {{"date", Order.Descending}, {"ingested_at", Order.Descending}}),
  #"Removed duplicates" = Table.Distinct(#"Sorted rows", {"region"})
in
  #"Removed duplicates";
shared weather_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "c50a881a-f4eb-402e-a192-efe134697892"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "94a00be1-8ba8-46ec-9271-6db7014aed81"]}[Data],
  Navigation_3 = Navigation_2{[Id = "silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "silver_weather", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
