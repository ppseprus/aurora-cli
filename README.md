# Aurora Forecast CLI

A command-line tool that provides aurora visibility forecasts based on a given location and NOAA's Planetary K-index data.

## Overview

Aurora Forecast CLI retrieves latest geomagnetic forecast data from NOAA and calculates the probability of aurora visibility at any location on Earth. The tool uses your latitude to determine viewing probability based on the current and forecasted Kp index values.

## Features

- **Location-based forecasts**: Enter any city or location worldwide
- **Latest NOAA data**: Fetches current Planetary K-index forecasts
- **Probability calculation**: Automatic calculation based on latitude and Kp index
- **Color-coded output**: Easy-to-read formatted tables (auto-disables for non-TTY)
- **Detailed explanations**: Built-in help for understanding aurora probability
- **Flexible CLI**: Multiple input formats and standard command-line options

## Requirements

- `bash` (version 3.2+)
- `curl` — for API requests
- `column` — for table formatting
- `jq` — for JSON parsing

### Dependencies

_Note: `curl` and `column` are usually pre-installed._

#### macOS (w/ Homebrew)

```bash
brew install jq
```

#### Ubuntu/Debian

```bash
sudo apt-get install jq
```

## Installation

1. Clone or download the script:
```bash
git clone https://github.com/ppseprus/aurora-cli.git
cd aurora-cli
```

2. Make the script executable:
```bash
chmod +x aurora.sh
```

3. (Optional) Add to your PATH:
```bash
sudo ln -s "$(pwd)/aurora.sh" /usr/local/bin/aurora
```

## Usage

### Command-Line Options

```bash
./aurora.sh [OPTIONS] <location>
```

#### Options

- `--at <location>` — Specify location (alternative syntax)
- `--hist` — Include historical K-index data (last ~48 hours)
- `--help` — Show help message
- `--explain` — Display detailed explanation of probability mapping

### Examples

#### Get Forecast for a Location

```bash
./aurora.sh "Stockholm, Sweden"
./aurora.sh --at "Tromsø, Norway"
```

#### View Detailed Probability Explanation

```bash
./aurora.sh --explain
```

## Output Example

```
→ Fetching coordinates for: Stockholm, Sweden
→ Retrieving NOAA Planetary K-index forecast...

━━━ Aurora Forecast ━━━
Location: Stockholm, Stockholms län, Sweden
Coordinates: 59.33°, 18.06°
Forecast Time: 2026-01-20 20:30 UTC

Latitude effect: Each degree above minimum adds ~20% visibility probability

Time_(UTC)        Kp    Min_Latitude  Probability  Outlook
2026-01-20 21:00  3.33  ≥64°          0%           None
2026-01-21 00:00  4.67  ≥62°          0%           None
2026-01-21 03:00  5.33  ≥60°          0%           None
2026-01-21 06:00  6.67  ≥57°          46%          Fair

Tip: Use 'aurora-cli --explain' for detailed probability mapping explanation
```

## How It Works

### Kp Index Scale

Kp indices use thirds ("tertiles") using whole numbers, and plus/minus symbols which translate to approximate decimal values of .33 and .67

- Kp 5- → 4.67
- Kp 6+ → 6.33


### How the script Uses Kp Values

1. NOAA's forecast data uses decimal values (eg. 5.33)
2. To determine visibility, the script **rounds to the nearest whole number**:
   - **5.00–5.49** → rounds to **5** → aurora visible at 60°+ latitude
   - **5.50–6.49** → rounds to **6** → aurora visible at 57°+ latitude
   - **6.50–7.49** → rounds to **7** → aurora visible at 54°+ latitude


### Kp Index to Minimum Latitude Mapping

The script uses established geomagnetic latitude thresholds for each Kp level:

| Kp | Min Latitude | Description |
|----|--------------|-------------|
| 0  | ≥67° | Auroras barely visible near poles |
| 1  | ≥66° | Weak aurora activity |
| 2  | ≥65° | Low aurora activity |
| 3  | ≥64° | Moderate aurora activity |
| 4  | ≥62° | Active aurora conditions |
| 5  | ≥60° | Minor geomagnetic storm (G1) |
| 6  | ≥57° | Moderate geomagnetic storm (G2) |
| 7  | ≥54° | Strong geomagnetic storm (G3) |
| 8  | ≥51° | Severe geomagnetic storm (G4) |
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

| Kp | Rounded | Min Latitude | Latitude Difference | Probability | Outlook |
|----|---------|--------------|---------------------|-------------|---------|
| 5.33 | 5 | 60° | 59.3° - 60° = **-0.7°** | 0% | None |
| 5.67 | 6 | 57° | 59.3° - 57° = **2.3°** | 46% | Fair |
| 6.67 | 7 | 54° | 59.3° - 54° = **5.3°** | 100% | Excellent |

## Data Sources

- **Geocoding**: [OpenStreetMap Nominatim API](https://nominatim.openstreetmap.org/)
- **K-index Forecast**: [NOAA Space Weather Prediction Center](https://www.swpc.noaa.gov/)

## Limitations

- Probability calculations are theoretical based on geomagnetic latitude only
- Actual visibility depends on:
  - Weather conditions (cloud cover)
  - Light pollution
  - Time of day (must be dark)
  - Local magnetic field variations
  - Solar wind conditions

## Acknowledgments

- NOAA Space Weather Prediction Center for providing K-index data
- OpenStreetMap for geocoding services
