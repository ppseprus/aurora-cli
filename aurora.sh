#!/usr/bin/env bash
#
# Aurora Forecast CLI
# Author: ppseprus
# Retrieves aurora visibility forecast based on location and NOAA Planetary K-index.
# License: MIT
#
set -euo pipefail

# Config
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly SCRIPT_VERSION="0.3.0"

readonly GFZ_HP30_FORECAST="https://spaceweather.gfz.de/fileadmin/SW-Monitor/hp30_product_file_FORECAST_HP30_SWIFT_DRIVEN_LAST.csv"
readonly NOAA_KP_FORECAST="https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json"
readonly NOMINATIM="https://nominatim.openstreetmap.org/search"

readonly USER_AGENT="aurora-cli/${SCRIPT_VERSION} (https://github.com/ppseprus/aurora-cli)"

readonly HISTORICAL_ENTRIES=16  # Number of historical K-index entries to display when `--hist` is provided

# Color codes (disabled if not in TTY)
if [[ -t 1 ]]; then
  readonly COLOR_RESET='\033[0m'
  readonly COLOR_BOLD='\033[1m'
  readonly COLOR_RED='\033[0;31m'
  readonly COLOR_GREEN='\033[0;32m'
  readonly COLOR_YELLOW='\033[0;33m'
  readonly COLOR_BLUE='\033[0;34m'
  readonly COLOR_CYAN='\033[0;36m'
else
  readonly COLOR_RESET=''
  readonly COLOR_BOLD=''
  readonly COLOR_RED=''
  readonly COLOR_GREEN=''
  readonly COLOR_YELLOW=''
  readonly COLOR_BLUE=''
  readonly COLOR_CYAN=''
fi

# Display usage information
usage() {
  cat >&2 <<EOF
$(echo -e "${COLOR_BOLD}Usage:${COLOR_RESET}")
  ${SCRIPT_NAME} [--Hp30|--GFZ] [--<hours>] <location>
  ${SCRIPT_NAME} [--Kp|--NOAA] [--hist] [--<hours>] <location>

$(echo -e "${COLOR_BOLD}Description:${COLOR_RESET}")
  Displays aurora visibility forecast based on geomagnetic indices and location.
  The closer you are to the poles, the higher your chances of seeing aurora.

$(echo -e "${COLOR_BOLD}Data Source:${COLOR_RESET}")
  --Hp30, --GFZ      Use GFZ Hp30 index w/ a 30-minute resolution $(echo -e "${COLOR_BOLD}(default)${COLOR_RESET}")
  --Kp, --NOAA       Use NOAA Planetary Kp index w/ a 3-hour resolution

$(echo -e "${COLOR_BOLD}Options:${COLOR_RESET}")
  --<hours>          Limit forecast to next n hours (eg. --17) $(echo -e "${COLOR_BOLD}(default is 24)${COLOR_RESET}")
  --hist             Include historical data $(echo -e "${COLOR_BOLD}(only when NOAA is the data source)${COLOR_RESET}")
  --help             Show this help message
  --explain          Show detailed explanation of probability mapping

$(echo -e "${COLOR_BOLD}Examples:${COLOR_RESET}")
  ${SCRIPT_NAME} "Stockholm, Sweden"
  ${SCRIPT_NAME} --24 "Stockholm, Sweden"
  ${SCRIPT_NAME} --Kp --12 "Stockholm, Sweden"
  ${SCRIPT_NAME} --explain
EOF
}

# Display detailed explanation of probability calculation
explain() {
  cat <<EOF
$(echo -e "${COLOR_BOLD}Aurora Visibility Probability Mapping${COLOR_RESET}")

$(echo -e "${COLOR_CYAN}About Geomagnetic Indices:${COLOR_RESET}")

  This tool uses two planetary geomagnetic activity indices to generate
  aurora visibility probabilities for a given location:

  $(echo -e "${COLOR_BOLD}Hp30 (GFZ/ESA)${COLOR_RESET}") - Default source
  • 30-minute resolution, suitable for short-term aurora probabilities
  • Open-ended scale — can exceed 9 during extreme storms
  • Model-driven forecast data
  • Derived from 13 globally distributed geomagnetic observatories
  • Produced by GFZ Potsdam and distributed via the ESA Space
    Weather Service Network

  $(echo -e "${COLOR_BOLD}Kp (NOAA)${COLOR_RESET}") - Alternative source
  • 3-hour resolution
  • Capped at 9.0 maximum
  • Forecast values from NOAA Space Weather Prediction Center
  • Optional historical data — definitive Kp values finalized later by GFZ
  • Based on a subset of real-time reporting observatories (typically 8)

$(echo -e "${COLOR_CYAN}Index Scale and Minimum Latitude Mapping:${COLOR_RESET}")

  Values use thirds: whole numbers, plus (+), and minus (-) symbols
  corresponding to approximate decimals of .33 and .67

  Index 5- → Decimal 4.67 → Rounded 5
  Index 6+ → Decimal 6.33 → Rounded 6

  The mapping rounds to the nearest integer for determining minimum latitude:

  Index  Min Latitude  Description
  ━━━━━  ━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   0         ≥67°     Auroras barely visible near poles
   1         ≥66°     Weak aurora activity
   2         ≥65°     Low aurora activity
   3         ≥64°     Moderate aurora activity
   4         ≥62°     Active aurora conditions
   5         ≥60°     Minor geomagnetic storm (G1)
   6         ≥57°     Moderate geomagnetic storm (G2)
   7         ≥54°     Strong geomagnetic storm (G3)
   8         ≥51°     Severe geomagnetic storm (G4)
   9+        ≥48°     Extreme geomagnetic storm (G5)

$(echo -e "${COLOR_CYAN}Probability Calculation:${COLOR_RESET}")

  Your location's latitude determines aurora visibility probability:

  • If your latitude < minimum latitude → 0% (too far from poles)
  • For each degree above minimum → +20% visibility probability
  • Probability caps at 100% when 5° or more above minimum

$(echo -e "${COLOR_CYAN}Latitude Effect:${COLOR_RESET}")

  $(echo -e "${COLOR_GREEN}Higher latitudes (closer to poles):${COLOR_RESET}") Better aurora visibility
  $(echo -e "${COLOR_YELLOW}Lower latitudes (closer to equator):${COLOR_RESET}") Rare aurora, only during storms

$(echo -e "${COLOR_CYAN}Example:${COLOR_RESET}")

  Location: Stockholm, Sweden (59.3°N)
  Index value: 5.33 (rounds to 5 with minimum latitude 60°)

  Calculation: 59.3° < 60° → 0% probability (just below threshold)

  If index = 6.67 (minimum 57°): 59.3° - 57° = 2.3° → 2.3 × 20 = 46% probability

$(echo -e "${COLOR_CYAN}Why Hp30 is Better for Aurora Watching:${COLOR_RESET}")

  Hp30's 30-minute resolution captures aurora substorms and intensifications
  that often last only tens of minutes, which are smoothed out in Kp's 3-hour
  average. This makes Hp30 more suitable for real-time aurora observability.

$(echo -e "${COLOR_BOLD}Note:${COLOR_RESET}") Actual visibility also depends on weather, light pollution, and time of day.

$(echo -e "${COLOR_CYAN}Naming:${COLOR_RESET}")
  • "p" = planetary (global average from multiple observatories)
  • "K" = Kennziffer (German: "characteristic digit")
  • "H" = hourly/half-hourly resolution
EOF
}

# Error handling function
error_exit() {
  echo -e "${COLOR_RED}Error:${COLOR_RESET} $1" >&2
  exit "${2:-1}"
}

# Check dependencies
check_dependencies() {
  local missing_deps=()

  for cmd in curl jq column; do
    if ! command -v "$cmd" &>/dev/null; then
      missing_deps+=("$cmd")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    error_exit "Missing required dependencies: ${missing_deps[*]}\nPlease install them to continue." 1
  fi
}

# Parse command line arguments
parse_args() {
  local location=""
  local show_hist="false"
  local data_source=""
  local hours="24"

  # No arguments provided
  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        exit 0
        ;;
      --explain)
        explain
        exit 0
        ;;
      --NOAA|--Kp)
        if [[ -n "$data_source" ]]; then
          usage
          exit 1
        fi
        data_source="NOAA"
        shift
        ;;
      --GFZ|--Hp30)
        if [[ -n "$data_source" ]]; then
          usage
          exit 1
        fi
        data_source="GFZ"
        shift
        ;;
      --hist)
        show_hist="true"
        shift
        ;;
      --[0-9]*)
        # Handle --<hours> format (eg. --12, --24, --48)
        hours="${1#--}"
        if [[ ! "$hours" =~ ^[0-9]+$ ]]; then
          usage
          exit 1
        fi
        shift
        ;;
      -*)
        usage
        exit 1
        ;;
      *)
        if [[ -z "$location" ]]; then
          location="$1"
          shift
        else
          usage
          exit 1
        fi
        ;;
    esac
  done

  if [[ -z "$data_source" ]]; then
    data_source="GFZ"
  fi

  if [[ -z "$location" ]]; then
    usage
    exit 1
  fi

  if [[ "$show_hist" == "true" && "$data_source" == "GFZ" ]]; then
    usage
    exit 1
  fi

  echo "${location}|${show_hist}|${data_source}|${hours}"
}

# Fetch geocoding data
geocode_location() {
  local location="$1"
  local geo_json

  echo -e "${COLOR_BLUE}→${COLOR_RESET} Fetching coordinates for: ${COLOR_BOLD}${location}${COLOR_RESET}" >&2

  geo_json=$(curl -sf \
    -H "User-Agent: $USER_AGENT" \
    --get "$NOMINATIM" \
    --data-urlencode "q=$location" \
    --data "format=json" \
    --data "limit=1") || error_exit "Failed to connect to geocoding service."

  local lat lon display_name
  lat=$(echo "$geo_json" | jq -r '.[0].lat // empty')
  lon=$(echo "$geo_json" | jq -r '.[0].lon // empty')
  display_name=$(echo "$geo_json" | jq -r '.[0].display_name // empty')

  if [[ -z "$lat" || -z "$lon" ]]; then
    error_exit "Location not found: ${location}\nTry a different format (eg. 'City, Country')"
  fi

  lat=$(printf "%.2f" "$lat")
  lon=$(printf "%.2f" "$lon")

  echo "$lat|$lon|$display_name"
}

# Fetch NOAA Kp forecast
fetch_kp_forecast() {
  echo -e "${COLOR_BLUE}→${COLOR_RESET} Retrieving NOAA Planetary K-index forecast..." >&2

  curl -sf "$NOAA_KP_FORECAST" || error_exit "Failed to fetch NOAA K-index forecast."
}

# Fetch GFZ/ESA Hp30 forecast
fetch_hp30_forecast() {
  echo -e "${COLOR_BLUE}→${COLOR_RESET} Retrieving GFZ/ESA Hp30 forecast..." >&2

  local csv_data
  csv_data=$(curl -sf "$GFZ_HP30_FORECAST") || error_exit "Failed to fetch GFZ/ESA Hp30 forecast."

  # Convert CSV to JSON format
  # Skip header line and extract Time (UTC) and median columns
  echo "$csv_data" | tail -n +2 | awk -F',' '
    BEGIN { print "[" }
    NR > 1 { print "," }
    {
      # Remove leading/trailing spaces from time and median values
      gsub(/^[ \t]+|[ \t]+$/, "", $1)
      gsub(/^[ \t]+|[ \t]+$/, "", $4)
      # Parse date format: DD-MM-YYYY HH:MM
      # Split on space to separate date and time
      split($1, datetime, " ")
      # Split date part: DD-MM-YYYY
      split(datetime[1], dateparts, "-")
      day = dateparts[1]
      month = dateparts[2]
      year = dateparts[3]
      time_part = datetime[2]
      # Construct YYYY-MM-DD HH:MM format
      formatted_time = year "-" month "-" day " " time_part
      printf "[\"" formatted_time "\"," $4 "]"
    }
    END { print "\n]" }
  ' | jq -c .
}

# Calculate and display aurora forecast
display_forecast() {
  local lat="$1"
  local lon="$2"
  local display_name="$3"
  local kp_json="$4"
  local show_hist="${5:-false}"
  local data_source="${6:-NOAA}"
  local hours="${7:-24}"
  local utc_now

  utc_now=$(date -u +"%Y-%m-%d %H:%M")

  local index_name
  if [[ "$data_source" == "GFZ" ]]; then
    index_name="Hp30"
  else
    index_name="Kp"
  fi

  # Process historical data if requested
  local hist_data=""
  if [[ "$show_hist" == "true" ]]; then
    hist_data=$(echo "$kp_json" | jq -r --arg lat "$lat" --arg now "$utc_now" --argjson entries "$HISTORICAL_ENTRIES" '
      .[1:]
      | map({
          time: .[0],
          kp: (.[1] | tonumber)
        })
      | map(select(.time < $now))
      | sort_by(.time)
      | .[-$entries:]
      | map(. + {
          min_lat: (
            (.kp | round) as $kp_int |
            if $kp_int >= 9 then 48
            elif $kp_int == 8 then 51
            elif $kp_int == 7 then 54
            elif $kp_int == 6 then 57
            elif $kp_int == 5 then 60
            elif $kp_int == 4 then 62
            elif $kp_int == 3 then 64
            elif $kp_int == 2 then 65
            elif $kp_int == 1 then 66
            else 67 end
          )
        })
      | map(. + {
          prob: (
            (($lat | tonumber) - .min_lat) as $d
            | if $d <= 0 then 0
              else ( ($d * 20) | if . > 100 then 100 else . end )
              end
          )
        })
    ')
  fi

  # Calculate max entries based on data source resolution
  local max_entries
  if [[ "$data_source" == "GFZ" ]]; then
    # GFZ has 30-minute resolution: 2 entries per hour
    max_entries=$((hours * 2))
  else
    # NOAA has 3-hour resolution: 1 entry per 3 hours
    max_entries=$(( (hours + 2) / 3 ))
  fi

  local table_data
  table_data=$(echo "$kp_json" | jq -r --arg lat "$lat" --arg now "$utc_now" --argjson max_entries "$max_entries" '
    .[1:]
    | map({
        time: .[0],
        kp: (.[1] | tonumber)
      })
    | map(select(.time >= $now))
    | .[0:$max_entries]
    | map(. + {
        min_lat: (
          (.kp | round) as $kp_int |
          if $kp_int >= 9 then 48
          elif $kp_int == 8 then 51
          elif $kp_int == 7 then 54
          elif $kp_int == 6 then 57
          elif $kp_int == 5 then 60
          elif $kp_int == 4 then 62
          elif $kp_int == 3 then 64
          elif $kp_int == 2 then 65
          elif $kp_int == 1 then 66
          else 67 end
        )
      })
    | map(. + {
        prob: (
          (($lat | tonumber) - .min_lat) as $d
          | if $d <= 0 then 0
            else ( ($d * 20) | if . > 100 then 100 else . end )
            end
        )
      })
  ')

  # Header
  echo
  echo -e "${COLOR_BOLD}━━━ Aurora Forecast ━━━${COLOR_RESET}"
  echo -e "${COLOR_CYAN}Location:${COLOR_RESET} ${display_name}"
  echo -e "${COLOR_CYAN}Coordinates:${COLOR_RESET} ${lat}°, ${lon}°"
  echo -e "${COLOR_CYAN}Forecast Time:${COLOR_RESET} ${utc_now} UTC"
  echo
  echo -e "${COLOR_BOLD}Latitude effect:${COLOR_RESET} Each degree above minimum adds ~20% visibility probability"
  echo

  # Table
  {
    echo -e "Time_(UTC)\t${index_name}\tMin_Latitude\tProbability\tOutlook"

    # Display historical data if available
    if [[ "$show_hist" == "true" && -n "$hist_data" ]]; then
      echo "$hist_data" | jq -r '
        .[] |
        (if .prob == 0 then "None"
         elif .prob <= 20 then "Low"
         elif .prob <= 50 then "Fair"
         elif .prob <= 75 then "Good"
         else "Excellent" end) as $outlook |
        "\(.time)\t\(.kp | tonumber | . * 100 | round / 100)\t≥\(.min_lat)°\t\(.prob | floor)%\t\($outlook)"
      '
      # Visual divider between historical and forecast data
      echo -e "${COLOR_BOLD}━━━ FORECAST ━━━${COLOR_RESET}\t\t\t\t"
    fi

    echo "$table_data" | jq -r '
      .[] |
      (if .prob == 0 then "None"
       elif .prob <= 20 then "Low"
       elif .prob <= 50 then "Fair"
       elif .prob <= 75 then "Good"
       else "Excellent" end) as $outlook |
      "\(.time)\t\(.kp | tonumber | . * 100 | round / 100)\t≥\(.min_lat)°\t\(.prob | floor)%\t\($outlook)"
    '
  } | column -t -s $'\t'

  echo
  echo -e "${COLOR_CYAN}Tip:${COLOR_RESET} Use '${SCRIPT_NAME} --explain' for detailed probability mapping explanation"
  echo
}

# Main function
main() {
  for arg in "$@"; do
    case "$arg" in
      --help)
        usage
        exit 0
        ;;
      --explain)
        explain
        exit 0
        ;;
    esac
  done

  check_dependencies

  local parse_result location show_hist data_source hours
  parse_result=$(parse_args "$@")
  IFS='|' read -r location show_hist data_source hours <<< "$parse_result"

  local geo_data lat lon display_name
  geo_data=$(geocode_location "$location")
  IFS='|' read -r lat lon display_name <<< "$geo_data"

  local forecast_json
  if [[ "$data_source" == "GFZ" ]]; then
    forecast_json=$(fetch_hp30_forecast)
  else
    forecast_json=$(fetch_kp_forecast)
  fi

  display_forecast "$lat" "$lon" "$display_name" "$forecast_json" "$show_hist" "$data_source" "$hours"
}

main "$@"
