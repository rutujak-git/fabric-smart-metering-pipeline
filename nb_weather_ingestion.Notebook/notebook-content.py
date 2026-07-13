# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "94a00be1-8ba8-46ec-9271-6db7014aed81",
# META       "default_lakehouse_name": "lh_smartmetering",
# META       "default_lakehouse_workspace_id": "c50a881a-f4eb-402e-a192-efe134697892",
# META       "known_lakehouses": [
# META         {
# META           "id": "94a00be1-8ba8-46ec-9271-6db7014aed81"
# META         }
# META       ]
# META     }
# META   }
# META }

# PARAMETERS CELL ********************

weather_json = ""
# weather_json = '{"current": {"temperature_2m": 27.4, "weather_code": 0}}'

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import json
import random
from datetime import datetime, timezone
import pandas as pd

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import json
import random
from datetime import datetime, timezone
import pandas as pd

data = json.loads(weather_json)
current = data["current"]

record = {
    "region": "Ontario",
    "date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
    "temperature_2m": current["temperature_2m"],
    "weather_code": current["weather_code"],
    "ingested_at": datetime.now(timezone.utc).isoformat()
}

df_clean = pd.DataFrame([record])
display(df_clean)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Write weather data to Bronze — as received, no artificial modification
import os

bronze_path = "Files/bronze/weather/"  # target folder inside the Lakehouse for weather data
filename = f"weather_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.csv"  # unique filename per run

os.makedirs(f"/lakehouse/default/{bronze_path}", exist_ok=True)  # create folder if it doesn't exist yet
df_clean.to_csv(f"/lakehouse/default/{bronze_path}{filename}", index=False)  # write data as-is
print(f"Bronze written: {bronze_path}{filename}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
