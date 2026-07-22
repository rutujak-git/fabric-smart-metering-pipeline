# Smart Metering Pipeline — A Microsoft Fabric Case Study

## The Idea

Imagine a utility company that collects electricity readings from smart meters every day, along with local weather data, and needs to turn that into something a billing team or analyst can actually use — clean data, accurate revenue numbers, and a dashboard that just works.

This project builds that whole system from scratch using Microsoft Fabric: raw data comes in daily, gets cleaned up, gets organized into a proper reporting structure, and lands in a Power BI report — all running automatically, end to end.

<img width="442" height="558" alt="image" src="https://github.com/user-attachments/assets/aa7fe325-7db7-435a-8709-59d0d6b64374" />


---

## Where the Data Comes From

A real utility company doesn't get all its data from one place — customer records live in a database, billing rates are usually static reference files, meter readings arrive as a steady stream of new files, and weather is something you'd pull from an outside source. This project mirrors that on purpose, using four different types of sources rather than one:

- **Customer and meter details** — live in an Azure SQL database, and are kept in sync with Fabric automatically using a feature called Mirroring (so this data is always up to date without needing its own pipeline)
- **Tariff (billing rate) information** — sits as a simple reference file in Azure storage, since billing rates don't change often
- **Daily meter readings** — new files dropped daily into an Azure Data Lake Storage container (the "landing zone"), just like a real utility company would receive them from field devices
- **Weather data** — pulled live each day from the [Open-Meteo API](https://api.open-meteo.com//v1/forecast?latitude=43.65&longitude=-79.38&current=temperature_2m,weather_code) (a free, no-auth-required public weather service), so we can eventually see whether hot or cold days affect electricity usage

### Where the test data comes from

Since there's no real utility company behind this project, a Python script (`generate_all_data.py`) is run from VS Code to simulate one. It creates realistic-looking customer records, meters, tariff zones, and daily meter readings (including some deliberately messy/bad rows, to test that the cleaning logic actually works), and uploads them to the right places — the SQL database and the storage landing zone — so the rest of the pipeline has something real to process.

---

## What Was Built

Here's every piece of the system and the part it plays:

| Layer | Item | Role |
|---|---|---|
| Bronze | `pipeline_bronze_meter_readings` | Pulls in daily meter reading files and live weather data |
| Bronze / Silver | `lh_smartmetering` (Lakehouse) | Where Bronze and Silver data lives |
| Silver | `df_silver_cleaning` (Dataflow Gen2) | Cleans and validates the raw data |
| Gold | `wh_smartmetering_gold` (Warehouse) | Holds the final reporting-ready tables |
| Gold | `gold.usp_BuildGoldLayer` (Stored Procedure) | Rebuilds the reporting tables from clean data |
| Orchestration | `pipeline_orchestrator_smart_metering` | Runs the three steps above in order, daily |
| Reporting | `sm_smartmetering_gold` (Semantic model) | Connects the reporting tables to Power BI |
| Reporting | `report_smartreporting_gold` (Power BI report) | The dashboard people actually look at |
| Deployment | `dp_smartmetering` (Deployment pipeline) | Copies the whole setup from Dev to Production safely |

**The flow, in order:**

`New files land in storage → Bronze pipeline picks them up → Silver cleans them → the stored procedure rebuilds the Gold reporting tables → Power BI reads the Gold layer and shows the dashboard`

All of this is triggered by one pipeline, once a day, with no manual steps in between.

---

## How the Data Flows

Think of this as three stages, like a factory line:

**1. Raw intake (Bronze)**
Everything lands here first, mostly untouched — just organized and stored safely. Files that come in get processed, then moved out of the way so they're never accidentally processed twice.

Here's exactly what happens, step by step, and why each step exists:

1. **Get Metadata** looks inside the storage landing zone and lists whatever files are currently sitting there — this is how the pipeline knows what's new.
2. **ForEach** loops through that list one file at a time, so each file gets handled individually rather than all at once.
3. **If Condition** checks: has this specific file already been processed before? This exists so the pipeline never accidentally re-processes the same file twice if it's re-run.
   - **If it's a new file:** the pipeline copies it into Bronze storage, then copies it again into a separate "already processed" folder (a paper trail), then deletes it from the landing zone — a log entry is written each time, so there's always a record of what was moved and when.
   - **If it's already been processed:** the pipeline just notes it and skips it, without touching it again.
4. Separately, a **Web activity** calls the weather API to get the day's temperature and conditions, and a **Notebook** takes that response and writes it straight into Bronze storage — no landing file needed here, since it's a live API call rather than a file drop.

**2. Cleaning (Silver)**
This is where the messy stuff gets sorted out — missing values, duplicate entries, weird outliers (like a reading that's impossibly high, or dated in the future). Nothing gets silently deleted; problem rows are tagged so we always know what happened and why.

**3. Reporting-ready (Gold)**
Only the clean, trustworthy data makes it here. It's reorganized into a simple structure — customers, meters, tariff zones, weather, and dates, all connected to one central table of actual readings. This is the structure Power BI reads from.

<img width="1440" height="802" alt="image" src="https://github.com/user-attachments/assets/8ca1dcdf-519b-472a-8fa6-781bb1aac96d" />

<img width="1440" height="804" alt="image" src="https://github.com/user-attachments/assets/536f00be-668f-4204-ac79-d7ca2e5c9261" />

<img width="1440" height="808" alt="image" src="https://github.com/user-attachments/assets/df646ee9-236d-42a0-9a1a-75d89328b1d4" />

---

## Keeping It Automatic

Rather than running each step by hand, a second pipeline — the **orchestrator** — chains everything together into one push-button (or scheduled) run:

1. **Invoke Pipeline** activity — calls the Bronze pipeline first, and waits for it to fully finish before moving on
2. **Dataflow Gen2** activity — once Bronze succeeds, this runs the Silver cleaning step
3. **Stored Procedure** activity — once Silver succeeds, this calls the procedure that rebuilds the Gold reporting tables

Each step only runs if the one before it succeeded — so if Bronze fails for any reason, Silver and Gold simply won't run on incomplete or stale data. It's scheduled to run once a day, so the system stays current without anyone needing to babysit it.

It's also been tested to run safely more than once — if it's re-run without new data showing up, it won't duplicate anything. If new readings do show up, only the new ones get added.

<img width="1440" height="808" alt="image" src="https://github.com/user-attachments/assets/1349677f-ce57-4651-87da-00397f073270" />


---

## The Dashboard

Before Power BI can show anything, it needs a **semantic model** — think of this as the translation layer that connects Power BI to the Gold tables sitting in the Warehouse, defines how the tables relate to each other, and holds the calculations the report uses.

The model, `sm_smartmetering_gold`, contains all five Gold dimension tables (`DimCustomer`, `DimMeter`, `DimTariffZone`, `DimWeather`, `DimDate`) plus the central `FactMeterReadings` table. Each dimension connects to the fact table through its own key — for example, `DimCustomer` connects on `customer_key`, `DimMeter` on `meter_key`, and so on — with each dimension on the "one" side and the fact table on the "many" side, the standard shape for this kind of reporting model. `DimDate` is also marked as an official date table, which unlocks proper date-based calculations.

Alongside the tables sits a dedicated measures table, holding the calculations the report relies on — total consumption, average consumption, total revenue (calculated by multiplying each reading's usage by its tariff zone's rate), reading count, and average temperature.

This model was built using a mode called **Direct Lake on SQL** — it reads live from the Warehouse without needing a separate data refresh step, and was chosen specifically because the Gold layer lives in a Warehouse rather than a Lakehouse.

On top of this model sits a Power BI report (`report_smartreporting_gold`) showing:
- Total electricity consumption and revenue at a glance
- A breakdown by region, by tariff zone, and by meter type
- A tariff zone summary table showing consumption, revenue, and rate side by side for each zone
- A first look at how temperature might relate to consumption

<img width="1440" height="810" alt="image" src="https://github.com/user-attachments/assets/fb8dfd6b-35fb-4971-a9a7-8bc86e042a36" />

<img width="1440" height="806" alt="image" src="https://github.com/user-attachments/assets/349f4704-a7c9-4a05-8e49-e0204846b7cc" />

*Note: since testing so far has mostly used a single day's worth of data, some trends (like day-over-day patterns) will become more interesting as more days of real data flow through the daily pipeline.*

---

## Keeping Track of Changes

Everything built in the Development workspace is connected to a Git repository, on a `dev` branch — so every change (a new pipeline step, an updated query, a schema tweak) gets committed and versioned, the same way a software engineer would track code changes. This gives a full history of how the project evolved, and a safety net to roll back to an earlier working version if something breaks.

Promotion to Production currently happens through Fabric's deployment pipeline, which copies tested items from the Development workspace directly into Production — separate from the Git branch itself. Merging the `dev` branch into `main` in Git is a planned next step, to keep the repository's main branch reflecting what's actually been deployed.

---

## Dev and Production

The whole project is built twice, in a sense — once in a development workspace to build and test safely, and once in a "production" workspace, kept in sync using Fabric's deployment pipeline feature. This mirrors how real teams avoid testing directly on live systems.

Deploying to production copies over the pipelines, the reporting layer, and the dashboard — but it doesn't copy actual data sitting in tables, since Dev and Prod are meant to hold their own separate data. That meant after deployment, Production's customer and meter tables started out empty and needed their own way of getting populated.

**The problem:** Customer and meter data is kept in sync using Fabric's Mirroring feature, which connects live to the Azure SQL database. It turns out that only one Mirroring connection is allowed to be active against a given database at a time — so trying to run Production's Mirroring connection while Development's was still active (both pointing at the exact same database) failed.

**The fix:** Development's Mirroring connection was disabled first, freeing up the database to be synced by a different connection. Production's Mirroring was then started using that same underlying database connection. This means only one environment's Mirroring can be actively syncing at any given time — a limitation worth knowing about, and a good example of a constraint you only discover by actually trying to run two environments side by side.

<img width="1440" height="812" alt="image" src="https://github.com/user-attachments/assets/be1aee1a-0a63-47cd-9a9e-0f8c4c9481e3" />

<img width="1436" height="812" alt="image" src="https://github.com/user-attachments/assets/64641aa2-6330-419a-971e-88c34fdec821" />

---

## A Few Interesting Problems Along the Way

Every real project hits some bumps — here are a few more worth mentioning (see the Dev/Production section above for the trickiest one):

- **Duplicate customers/meters in the source data** caused the reporting numbers to double up at first. Traced it back, added a simple "keep only one copy" rule, and the numbers matched perfectly.
- **A couple of Gold tables had to be rebuilt from scratch partway through.** The tariff zone table was first created with column names guessed from memory, which didn't match the actual source data — it had to be dropped and recreated with the right columns once the real source was checked. The date table was originally built using a more complex date-generation approach that didn't run reliably, so it was rebuilt using a simpler, more dependable method instead. Both are small reminders that it's worth double-checking a source's actual structure before building against it, rather than assuming.

---

