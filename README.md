# Rideau Canal Skateway – End-to-End Monitoring System

This repository contains the **main documentation** for the Rideau Canal Skateway monitoring system.  
It ties together the three main parts of the project:

1. **IoT Sensor Simulation** – Python service that simulates real ice sensors and sends data to Azure IoT Hub.  
2. **Stream Processing & Storage** – Azure IoT Hub + Stream Analytics + Cosmos DB + Blob Storage.  
3. **Web Dashboard** – Node.js/Express application that visualizes canal conditions in near real time.

This README provides an overview of the scenario, architecture, implementation, results, and links to all related repositories and resources.

---

## Student Information

- **Student Name:** `<Your Name Here>`  
- **Student ID:** `<Your Student ID>`  

**Project Repositories:**

- **Sensor Simulation Repository:** `<link-to-sensor-simulation-repo>`  
- **Web Dashboard Repository:** `<link-to-web-dashboard-repo>`  
- **Main Documentation Repository (this repo):** `<link-to-main-docs-repo>`  
- **Live Dashboard Deployment:** `<https://your-dashboard-app.azurewebsites.net>`  

Replace the placeholders above with your actual name, student ID, Git repository URLs, and the live Azure App Service URL.

---

## Scenario Overview

### Problem Statement

The National Capital Commission (NCC) needs a way to **monitor ice conditions** on the Rideau Canal Skateway in near real time. Decisions about opening, closing, or partially restricting the canal must be based on:

- Ice thickness
- Surface temperature
- Snow accumulation
- External air temperature
- Overall safety at key locations

Manual measurements are slow and difficult to scale. The goal is to design a **cloud-based monitoring solution** that collects sensor data continuously, analyzes it, and provides a clear visual dashboard for operators.

### System Objectives

The system is designed to:

- Simulate **multiple independent sensors** at different locations along the canal.
- Ingest telemetries into **Azure IoT Hub** in real time.
- Aggregate data into 5-minute windows using **Azure Stream Analytics**.
- Derive a **safety status** (Safe / Caution / Unsafe) for each location.
- Persist aggregated data in **Cosmos DB** for operational use.
- Archive the same data in **Blob Storage** for historical analysis.
- Visualize the latest status and recent trends in a **web dashboard** hosted on Azure App Service.

---

## System Architecture

### Architecture Diagram

The main architecture diagram is stored in the `architecture/` folder, for example:

- `architecture/rideau-canal-architecture.png`

The diagram illustrates the end-to-end flow from simulated sensors to the final dashboard.

### Data Flow Explanation

1. **Sensor Simulation (Python)**  
   - Three virtual sensors (Dow's Lake, Fifth Avenue, NAC) each run in their **own thread**.  
   - Each sensor periodically generates a JSON reading (ice thickness, temperatures, snow, timestamp).  
   - Readings are sent as device-to-cloud messages to **Azure IoT Hub** using the Azure IoT SDK.

2. **Azure IoT Hub**  
   - Acts as the **ingestion point** for all device telemetry.  
   - The Stream Analytics job is configured with IoT Hub as an input source.

3. **Azure Stream Analytics**  
   - Consumes the raw sensor messages from IoT Hub.  
   - Uses a **5-minute tumbling window** per location to calculate:  
     - average / min / max ice thickness  
     - average / min / max surface temperature  
     - max snow accumulation  
     - average external temperature  
   - Derives a **safetyStatus** value (Safe / Caution / Unsafe) based on ice thickness and surface temperature.
   - Outputs the 5-minute aggregates to:
     - **Cosmos DB** for the live dashboard, and  
     - **Blob Storage** for archival (JSON lines).

4. **Azure Cosmos DB (SQL API)**  
   - Stores one document per (location, 5-minute window).  
   - Holds all fields required by the dashboard (metrics and safetyStatus).  
   - The Node.js backend queries this container to get:
     - Latest status per location  
     - Last hour of history for charts.

5. **Azure Blob Storage**  
   - Receives the same aggregated data from Stream Analytics.  
   - Uses a structured path like `aggregations/{date}/{time}`.  
   - Stores data as **JSON (line separated)** for later offline analysis or reporting.

6. **Web Dashboard (Node.js/Express + Chart.js)**  
   - Node.js backend runs on **Azure App Service** and exposes REST API endpoints (`/api/latest`, `/api/history/:sensorId`, `/api/status`).  
   - The frontend (HTML/CSS/JS + Chart.js) fetches data from these endpoints and displays:
     - Latest metrics for each location.  
     - Overall canal safety.  
     - Last hour of ice thickness, temperatures, and snow as line charts.

7. **End User (Operator)**  
   - Opens the dashboard in a web browser.  
   - Uses the view to make decisions about canal operations and safety communications.

### Azure Services Used

- **Azure IoT Hub** – device-to-cloud ingestion for simulated sensors.  
- **Azure Stream Analytics** – real-time stream processing, 5-minute aggregations, and safety status logic.  
- **Azure Cosmos DB (SQL API)** – operational datastore for the dashboard (5-minute aggregates).  
- **Azure Blob Storage** – long-term archival of the aggregated data as JSON.  
- **Azure App Service + App Service Plan** – hosting platform for the web dashboard (Node.js).  

Other supporting components:

- **Azure Resource Groups** – logical grouping of all project resources.  
- **Azure for Students subscription** – billing and access level used for this deployment.

---

## Implementation Overview

### IoT Sensor Simulation (Python) – `[link to repo]`

- Repository: `<link-to-sensor-simulation-repo>`  
- Implemented in Python using:
  - `azure-iot-device` for IoT Hub communication.  
  - `python-dotenv` for configuration.  
  - `threading` to simulate **three independent sensors**, each on its own thread.  
- Each thread:
  - Creates a `Sensor` object tied to a device ID and location.  
  - Periodically generates realistic winter data.  
  - Sends JSON messages to the IoT Hub device endpoint.

### Azure IoT Hub Configuration

- An **IoT Hub** is created (e.g., `iothubfinal`).  
- Three **IoT devices** are registered, one per location.  
- Device connection strings are placed in the sensor simulator `.env` file.  
- The IoT Hub is configured as an **input** in Stream Analytics.

### Stream Analytics Job (Query Included)

The Stream Analytics job:

- Input: IoT Hub telemetry (JSON).  
- Outputs:
  - Cosmos DB (for dashboard).  
  - Blob Storage (for archival).  
- Query (final version):

```sql
WITH Aggregates AS (
    SELECT
        location,
        System.Timestamp AS windowEndTime,
        AVG(iceThicknessCm)        AS avgIceThicknessCm,
        MIN(iceThicknessCm)        AS minIceThicknessCm,
        MAX(iceThicknessCm)        AS maxIceThicknessCm,
        AVG(surfaceTemperatureC)   AS avgSurfaceTemperatureC,
        MIN(surfaceTemperatureC)   AS minSurfaceTemperatureC,
        MAX(surfaceTemperatureC)   AS maxSurfaceTemperatureC,
        MAX(snowAccumulationCm)    AS maxSnowAccumulationCm,
        AVG(externalTemperatureC)  AS avgExternalTemperatureC,
        COUNT(*)                   AS readingCount
    FROM iothubfinal TIMESTAMP BY timestamp
    GROUP BY
        location,
        TumblingWindow(minute, 5)
)

-- Output 1: Cosmos DB (SensorAggregations)
SELECT
    CONCAT(location, '-', 
           DATEDIFF(second, '1970-01-01T00:00:00Z', windowEndTime)) AS id,
    location,
    windowEndTime,
    avgIceThicknessCm,
    minIceThicknessCm,
    maxIceThicknessCm,
    avgSurfaceTemperatureC,
    minSurfaceTemperatureC,
    maxSurfaceTemperatureC,
    maxSnowAccumulationCm,
    avgExternalTemperatureC,
    readingCount,
    CASE
        WHEN avgIceThicknessCm >= 30 AND avgSurfaceTemperatureC <= -2 THEN 'Safe'
        WHEN avgIceThicknessCm >= 25 AND avgSurfaceTemperatureC <=  0 THEN 'Caution'
        ELSE 'Unsafe'
    END AS safetyStatus
INTO SensorAggregations         -- Cosmos DB output alias
FROM Aggregates;

-- Output 2: Blob Storage (historical archive)
SELECT
    location,
    windowEndTime,
    avgIceThicknessCm,
    minIceThicknessCm,
    maxIceThicknessCm,
    avgSurfaceTemperatureC,
    minSurfaceTemperatureC,
    maxSurfaceTemperatureC,
    maxSnowAccumulationCm,
    avgExternalTemperatureC,
    readingCount,
    CASE
        WHEN avgIceThicknessCm >= 30 AND avgSurfaceTemperatureC <= -2 THEN 'Safe'
        WHEN avgIceThicknessCm >= 25 AND avgSurfaceTemperatureC <=  0 THEN 'Caution'
        ELSE 'Unsafe'
    END AS safetyStatus
INTO [historical-data]          -- Blob output alias
FROM Aggregates;
```

### Cosmos DB Setup

- **Account type:** Azure Cosmos DB for NoSQL (SQL API).  
- **Database:** e.g., `RideauCanalDb`.  
- **Container:** `SensorAggregations` (same name as Stream Analytics output alias).  
- Stores documents with fields such as:
  - `id`, `location`, `windowEndTime`  
  - `avgIceThicknessCm`, `avgSurfaceTemperatureC`, etc.  
  - `safetyStatus` and `readingCount`.  
- The web dashboard queries this container to fetch both the **latest document per location** and the **last hour of data**.

### Blob Storage Configuration

- A Storage account (e.g., `rideaucanalstordb`) is created.  
- Container: `historical-data`.  
- Stream Analytics is configured with:
  - Path pattern: `aggregations/{date}/{time}`  
  - Format: `JSON` (line separated).  
- Used for longer-term historical analysis and reporting.

### Web Dashboard (Node.js/Express + Chart.js) – `[link to repo]`

- Repository: `<link-to-web-dashboard-repo>`  
- Backend (`index.js`):
  - Uses `@azure/cosmos` to connect to Cosmos DB.  
  - Exposes REST APIs:
    - `GET /api/latest` – latest data per location.  
    - `GET /api/history/:sensorId` – last hour of data for a location.  
    - `GET /api/status` – overall canal safety (Safe/Caution/Unsafe) based on all locations.  
  - Serves static files from `public/` (HTML, CSS, JS).

- Frontend (`public/`):
  - `index.html` – page layout (status banner, cards, charts).  
  - `app.js` – fetches data from the backend and updates the DOM and Chart.js graphs every 30 seconds.  
  - `styles.css` – responsive styling and safety color coding.

### Azure App Service Deployment

- Azure Web App created on a Node 18/20 runtime.  
- Environment variables configured via **Application Settings**:
  - `COSMOS_ENDPOINT`  
  - `COSMOS_KEY`  
  - `COSMOS_DB_NAME`  
  - `COSMOS_CONTAINER_NAME`  
- Code deployed via Zip Deploy or GitHub Actions from the dashboard repository.  
- The live URL is shared in the **Student Information** and **Repository Links** sections.

---

## Repository Links

- **Sensor Simulation Repository:** `<link-to-sensor-simulation-repo>`  
- **Web Dashboard Repository:** `<link-to-web-dashboard-repo>`  
- **Main Documentation Repository (this repo):** `<link-to-main-docs-repo>`  
- **Live Dashboard Deployment:** `<https://your-dashboard-app.azurewebsites.net>`  

Update these with your real links before submission.

---

## Video Demonstration

Provide a short video (e.g., 5–10 minutes) showing:

- The sensor simulator running in a terminal.  
- Azure portal views (IoT Hub, Stream Analytics, Cosmos DB, Blob Storage).  
- The web dashboard updating in near real time as new data arrives.

**Video link:**  
`<https://your-video-link>` (YouTube, OneDrive, or similar)

If allowed, you can also embed it in your LMS or documentation as appropriate.

---

## Setup Instructions

### Prerequisites

- Azure subscription (Azure for Students is sufficient).  
- Access to the three project repositories (sensor, dashboard, docs).  
- Local tools (for development / demos):
  - Python 3.10+  
  - Node.js 18+  
  - Git  
  - Azure CLI (optional but helpful)

### High-Level Setup Steps

1. **Clone repositories**  
   - Clone the sensor simulation and dashboard repositories to your machine.

2. **Configure Azure IoT Hub**  
   - Create an IoT Hub.  
   - Register three IoT devices (Dow's Lake, Fifth Avenue, NAC).  
   - Copy their connection strings into the sensor simulator `.env` file.

3. **Run the Sensor Simulator**  
   - Install Python dependencies.  
   - Start `main.py` to send live telemetry to IoT Hub from all three simulated sensors.

4. **Create and Configure Stream Analytics Job**  
   - Set IoT Hub as the input.  
   - Configure two outputs: Cosmos DB and Blob Storage.  
   - Paste in the final Stream Analytics query from this README.  
   - Start the job and verify it is running.

5. **Create Cosmos DB and Blob Storage**  
   - Cosmos DB: create the database and `SensorAggregations` container.  
   - Blob Storage: create the storage account and `historical-data` container with the right path pattern.

6. **Deploy the Web Dashboard**  
   - Configure App Service with Cosmos DB settings.  
   - Deploy the Node.js dashboard (via Zip or GitHub Actions).  
   - Confirm that `/api/latest` and `/api/history/dows` return data.

7. **Open the Dashboard and Validate**  
   - Browse to the live App Service URL.  
   - Check that the cards and charts show data and update over time.  

### Detailed Setup

For detailed, step-by-step setup, see the READMEs in:

- **Sensor Simulation Repository** (sensor-specific configuration and usage).  
- **Web Dashboard Repository** (dashboard deployment and configuration details).

---

## Results and Analysis

### Sample Outputs and Screenshots

Include screenshots in a folder such as `screenshots/`, for example:

- `screenshots/dashboard-overview.png` – full dashboard view with all cards and charts.  
- `screenshots/stream-analytics-job.png` – Stream Analytics job running.  
- `screenshots/cosmos-data-explorer.png` – sample 5-minute aggregate document.  

Describe what the screenshots show and how they demonstrate that the system works end-to-end.

### Data Analysis

Some example observations:

- As temperature rises toward 0 °C and ice thickness decreases, locations may shift from **Safe** to **Caution** or **Unsafe**.  
- Snow accumulation affects the interpretation of surface conditions and can be monitored separately.  
- The last-hour charts clearly show trends (e.g., cooling overnight or warming during the day).  

You can expand this section with concrete findings based on your own test runs.

### System Performance Observations

- The system processes data in near real time:  
  - Simulator interval (e.g., 10 seconds).  
  - Stream Analytics window (5 minutes).  
  - Dashboard refresh interval (30 seconds).  
- For this student project scale, resource utilization and latency remain low and acceptable.  
- Cosmos DB queries for the last hour and latest point are fast and suitable for interactive dashboards.

---

## Challenges and Solutions

### 1. Python & Azure IoT SDK Issues

- **Challenge:** Missing `azure-iot-device` package and environment management problems.  
- **Solution:** Added the package to `requirements.txt`, used `python-dotenv` and a `.env` file, and cleaned up configuration to follow 12-factor principles.

### 2. Timezone and Timestamp Handling

- **Challenge:** `tzdata` / `ZoneInfo` errors when using local time zones like `America/Toronto`.  
- **Solution:** Standardized on **UTC ISO-8601** timestamps for telemetry, which is simpler and cloud-friendly.

### 3. Stream Analytics Query Functions

- **Challenge:** Attempted to use unsupported T-SQL functions like `FORMAT()` on datetimes, causing job failures.  
- **Solution:** Switched to `DATEDIFF` from `1970-01-01` to generate stable numeric IDs and simplified the query accordingly.

### 4. End-to-End Integration of Azure Resources

- **Challenge:** Ensuring that IoT Hub, Stream Analytics, Cosmos DB, Blob Storage, and App Service all pointed to the correct resources and connection strings.  
- **Solution:** Carefully aligned resource names, connection strings, and environment variables; used logging and Azure portal diagnostics to verify each step.

### 5. Dashboard Data Synchronization

- **Challenge:** Making the charts and status cards update smoothly without errors, even when data is temporarily missing.  
- **Solution:** Implemented defensive coding in the dashboard (`app.js`) with clear error messages, fallbacks, and consistent data formats from the backend.

You can add more project-specific challenges here if you encountered additional issues.

---

## AI Tools Disclosure

If your instructor or institution requires disclosure of AI assistance, you can use this section.

Example (adapt as needed):

- I used **ChatGPT (OpenAI)** as a coding and documentation assistant for this project.  
- AI assistance was used to:
  - Brainstorm architecture options and clarify Azure service roles.  
  - Help debug specific errors (e.g., Stream Analytics query issues, environment configuration).  
  - Draft and refine documentation (including this README and the component-specific READMEs).  
- All final decisions about architecture, configuration, and code changes were reviewed and validated by me, and I performed all deployments and testing myself.


---

## References

### Libraries and SDKs

- Azure IoT Device SDK for Python (`azure-iot-device`)  
- Azure Cosmos DB JavaScript SDK (`@azure/cosmos`)  
- Chart.js (charting library for the dashboard)  
- `dotenv`, `python-dotenv` for configuration management

### Official Documentation

- Microsoft Azure IoT Hub documentation  
- Azure Stream Analytics documentation  
- Azure Cosmos DB for NoSQL documentation  
- Azure App Service documentation  
- Node.js and Express.js documentation  
- Python and standard library documentation

You can expand this list with any additional articles, tutorials, or references you used during the project.
