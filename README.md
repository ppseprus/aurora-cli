# Aurora Forecast CLI

A CLI that retrieves the latest geomagnetic forecast data and calculates the probability of aurora visibility at any location on Earth. The tool uses the latitude of a given location to determine viewing probability based on current and forecasted geomagnetic activity indices.

## Installation

### Dependencies

- `bash` (version 3.2+)
- `curl` — for API requests
- `column` — for table formatting
- `jq` — for JSON parsing

_Note: `curl` and `column` are usually pre-installed._

#### macOS (w/ Homebrew)

```bash
brew install jq
```

#### Ubuntu/Debian

```bash
sudo apt-get install jq
```

### Clone

1. Clone or download the script:
```bash
git clone https://github.com/ppseprus/aurora-cli.git
cd aurora-cli
```

2. (Optional) Add to `PATH`:
```bash
sudo ln -s "$(pwd)/aurora.sh" /usr/local/bin/aurora
```

## Usage

### Command-Line Options

```
Usage:
  aurora [--Hp30|--GFZ] [--<hours>] <location>
  aurora [--Kp|--NOAA] [--hist] [--<hours>] <location>

Description:
  Displays aurora visibility forecast based on geomagnetic indices and location.
  The closer you are to the poles, the higher your chances of seeing aurora.

Index/Data Source:
  --Hp30, --GFZ      Use GFZ Hp30 index w/ a 30-minute resolution (default)
  --Kp, --NOAA       Use NOAA Planetary Kp index w/ a 3-hour resolution

Options:
  --<hours>          Limit forecast to next n hours (eg. --17) (default is 24)
  --hist             Include historical data (only when NOAA is the data source)
  --help             Show this help message
  --explain          Show detailed explanation of probability mapping
```

### Examples

#### Get Default (GFZ/ESA Hp30) 24-Hour Forecast

```bash
./aurora.sh "Stockholm, Sweden"
```

#### Get 12-Hour NOAA Kp Forecast

```bash
./aurora.sh --Kp --12 "Tromsø, Norway"
```

#### View Detailed Index and Probability Explanation

```bash
./aurora.sh --explain
```

## Output Example

```
→ Fetching coordinates for: Stockholm, Sweden
→ Retrieving GFZ/ESA Hp30 forecast...

━━━ Aurora Forecast ━━━
Location: Stockholm, Stockholms kommun, Stockholms län, 111 29, Sverige
Coordinates: 59.33°, 18.07°
Forecast Time: 2026-01-21 23:47 UTC

Latitude effect: Each degree above minimum adds ~20% visibility probability

Time_(UTC)        Hp30  Min_Latitude  Probability  Outlook
2026-01-22 00:00  3.67  ≥62°          0%           None
2026-01-22 00:30  4.33  ≥62°          0%           None
2026-01-22 01:00  4.33  ≥62°          0%           None
2026-01-22 01:30  4     ≥62°          0%           None
2026-01-22 02:00  4     ≥62°          0%           None
2026-01-22 02:30  4     ≥62°          0%           None
2026-01-22 03:00  4     ≥62°          0%           None
2026-01-22 03:30  4     ≥62°          0%           None
2026-01-22 04:00  4     ≥62°          0%           None
2026-01-22 04:30  4     ≥62°          0%           None
2026-01-22 05:00  4     ≥62°          0%           None
2026-01-22 05:30  4     ≥62°          0%           None
2026-01-22 06:00  4     ≥62°          0%           None
2026-01-22 06:30  4     ≥62°          0%           None
...

Tip: Use 'aurora-cli --explain' for detailed probability mapping explanation
```

## How It Works

### Geomagnetic Indices

This tool supports two planetary geomagnetic activity indices:

#### Hp30 (GFZ/ESA) - Default

- **30-minute resolution** for detailed short-term forecasting
- **Open-ended scale** — can exceed 9 during extreme storms
- **Model-driven** forecast data
- Derived from **13 globally distributed geomagnetic observatories**
- **Produced by GFZ Potsdam** and distributed via ESA Space Weather Service Network

#### Kp (NOAA) - Alternative

- **3-hour resolution**
- **Capped at 9.0** maximum
- Forecast values from **NOAA Space Weather Prediction Center**
- Optional **historical data** — definitive Kp values finalized later by GFZ
- Based on a subset of **real-time reporting observatories** (typically 8)

### Index Scale

Both indices use similar scales. Kp traditionally uses thirds ("tertiles") with plus/minus notation:

- Kp 5- → 4.67
- Kp 6+ → 6.33

### How the Script Uses Index Values

1. Forecast data uses decimal values (eg. 5.33)
2. To determine visibility, the script **rounds to the nearest whole number**:
   - **5.00–5.49** → rounds to **5** → aurora visible at 60°+ latitude
   - **5.50–6.49** → rounds to **6** → aurora visible at 57°+ latitude
   - **6.50–7.49** → rounds to **7** → aurora visible at 54°+ latitude

### Geomagnetic Index to Minimum Latitude Mapping

The script uses established geomagnetic latitude thresholds for each index level:

| Index | Min Latitude | Description |
|-------|--------------|-------------|
| 0 | ≥67° | Auroras barely visible near poles |
| 1 | ≥66° | Weak aurora activity |
| 2 | ≥65° | Low aurora activity |
| 3 | ≥64° | Moderate aurora activity |
| 4 | ≥62° | Active aurora conditions |
| 5 | ≥60° | Minor geomagnetic storm (G1) |
| 6 | ≥57° | Moderate geomagnetic storm (G2) |
| 7 | ≥54° | Strong geomagnetic storm (G3) |
| 8 | ≥51° | Severe geomagnetic storm (G4) |
| 9+ | ≥48° | Extreme geomagnetic storm (G5) |

_Source: [NOAA Space Weather Prediction Center - Tips on Viewing Aurora](https://www.swpc.noaa.gov/content/tips-viewing-aurora)_

### Probability Calculation

For each forecast period:
1. Your location's latitude is compared to the minimum latitude for the forecasted Kp
2. If your latitude is below the minimum → 0% probability
3. For each degree above minimum → +20% visibility probability
4. Maximum probability caps at 100%

#### Formula

`Probability = min(100, max(0, (Your_Latitude - Min_Latitude) × 20))`

#### Example

Location: Stockholm, Sweden (59.3°N)

| Index | Rounded | Min Latitude | Latitude Difference | Probability | Outlook |
|-------|---------|--------------|---------------------|-------------|---------|
| 5.33 | 5 | 60° | 59.3° - 60° = **-0.7°** | 0% | None |
| 5.67 | 6 | 57° | 59.3° - 57° = **2.3°** | 46% | Fair |
| 6.67 | 7 | 54° | 59.3° - 54° = **5.3°** | 100% | Excellent |

## Data Sources

- **Geocoding**: [OpenStreetMap Nominatim API](https://nominatim.openstreetmap.org/)
- **Hp30 Forecast**: [GFZ Potsdam via ESA Space Weather Service Network](https://spaceweather.gfz.de/)
- **Kp Forecast**: [NOAA Space Weather Prediction Center](https://www.swpc.noaa.gov/)

## Limitations

- Probability calculations are theoretical based on latitude only
- Actual visibility depends on:
  - Weather conditions (cloud cover)
  - Light pollution
  - Time of day
  - Local magnetic field variations
  - Solar wind conditions

## Acknowledgments

- GFZ Potsdam and ESA Space Weather Service Network for providing Hp30 data
- NOAA Space Weather Prediction Center for providing Kp index data
- OpenStreetMap for geocoding services
