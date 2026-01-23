# Aurora Forecast CLI

A CLI that retrieves the latest geomagnetic forecast data and calculates the probability of aurora visibility at any location on Earth. The tool uses the latitude of a given location to determine viewing probability based on current and forecasted geomagnetic activity indices.

## Installation

### Dependencies

- `bash` (version 3.2+)
- `jq` — for JSON parsing

_Note: The script also uses standard utilities (`curl`, `awk`, `bc`, `column`) which are pre-installed on all modern systems._

#### macOS (w/ Homebrew)

```bash
brew install jq
```

#### Ubuntu/Debian

```bash
sudo apt install jq
```

#### Fedora/RHEL

```bash
sudo dnf install jq
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
USAGE
  aurora [--Hp30|--GFZ] [-f,--forecast <N>] [-m,--magnitude <M>] [-e,--estimate <value>] <location>
  aurora [--Kp|--NOAA] [-f,--forecast <N>] [-m,--magnitude <M>] [--hist] <location>

DESCRIPTION
  Display aurora visibility forecast based on geomagnetic indices and your location.
  The closer you are to the magnetic poles, the higher your chances of seeing aurora.

INDEX / DATA SOURCE OPTIONS
  --Hp30, --GFZ
      Use the GFZ Hp30 geomagnetic index (30-minute resolution). [default]

  --Kp, --NOAA
      Use the NOAA Kp geomagnetic index (3-hour resolution).

FORECAST SETTINGS
  -f, --forecast <N>
      Limit forecast to next N hours.
      Values can range from 1 to 72. [default: 24]

  -m, --magnitude <M>
      Filter forecast to show only periods with magnitude ≥ M value.
      Minimum is 0, but the data is open-ended. [default: 0]

  -e, --estimate <value>
      Select which estimate to use from ensemble forecast.
      Possible values:
      • median  - Use median estimate [default]
      • low     - Use minimum estimate (more conservative)
      • high    - Use maximum estimate (more optimistic)
      Only supported when using GFZ Hp30.

  --hist
      Include historical data.
      Only supported when using NOAA Kp as data source.

INFORMATION OPTIONS
  -h, --help
      Show this help message.

  -v, --version
      Show version information.

  --explain
      Show detailed explanation of probability calculations.

LOCATION FORMAT
  Locations can be specified as:
  • City names: "Stockholm, Sweden" or "City, State, Country"
  • Geographic coordinates: "68.4363°N 17.3983°E"
  The tool will geocode your input using OpenStreetMap Nominatim.

NOTES
  • Only one data source can be selected (GFZ Hp30 or NOAA Kp).
  • -e, --estimate only works when using GFZ Hp30.
  • --hist only works when using NOAA Kp.

EXAMPLES
  aurora "Stockholm, Sweden"
  aurora "68.4363°N 17.3983°E"
  aurora -f 48 "Reykjavik, Iceland"
  aurora --Kp --hist --forecast 12 "Tromsø, Norway"
  aurora --explain
```

### Examples

#### Get Default (GFZ/ESA Hp30) 24-Hour Forecast

```bash
./aurora.sh "Stockholm, Sweden"
```

#### Get 12-Hour NOAA Kp Forecast

```bash
./aurora.sh --Kp -f 12 "Tromsø, Norway"
```

#### View Detailed Index and Probability Explanation

```bash
./aurora.sh --explain
```

## Output Example

```
→ Fetching coordinates for: Stockholm, Sweden
→ Retrieving GFZ/ESA Hp30 forecast...

  AURORA VISIBILITY FORECAST
================================================================================

  Location:      Stockholm, Stockholms kommun, Stockholms län, 111 29, Sverige
  Coordinates:   59.33°, 18.07°
  Data Source:   GFZ Hp30
  Estimate:      median
  Magnitude:     ≥0
  Forecast Time: 2026-01-23 22:53 UTC

  Note: Each degree above minimum latitude adds ~20% visibility probability

Time_(UTC)        Hp30   Min_Lat  Probability  Outlook
2026-01-23 23:00   3.67  ≥62°       0%         None
2026-01-23 23:30   3.33  ≥64°       0%         None
2026-01-24 00:00   3.33  ≥64°       0%         None
2026-01-24 00:30   3.33  ≥64°       0%         None
2026-01-24 01:00   3.33  ≥64°       0%         None
2026-01-24 01:30   3.33  ≥64°       0%         None
2026-01-24 02:00   3     ≥64°       0%         None
2026-01-24 02:30   3     ≥64°       0%         None
2026-01-24 03:00   3     ≥64°       0%         None
2026-01-24 03:30   3     ≥64°       0%         None
...

  Tip: Run 'aurora --explain' for detailed probability calculations
```

## How It Works

### Geomagnetic Indices

This tool supports two planetary geomagnetic activity indices:

#### Hp30 (GFZ/ESA) - Default

- **30-minute resolution** for detailed short-term forecasting
- **Open-ended scale** — can exceed 9 during extreme storms
- **Model-driven** forecast data
- Provides ensemble forecasts with minimum, median, and maximum estimates reflecting uncertainty in the prediction model.
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
1. Your location's absolute latitude is compared to the minimum latitude for the forecasted Kp
2. If your absolute latitude is below the minimum → 0% probability
3. For each degree above minimum → +20% visibility probability
4. Maximum probability caps at 100%

#### Formula

`Probability = min(100, max(0, (|Your_Latitude| - Min_Latitude) × 20))`

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

## License

MIT
