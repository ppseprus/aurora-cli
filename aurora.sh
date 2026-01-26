#!/usr/bin/env bash
#
# Aurora Forecast CLI
# Author: ppseprus
# Retrieves aurora visibility forecast based on location and NOAA Planetary K-index.
# License: MIT
#
set -euo pipefail

# Configuration
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly SCRIPT_VERSION="0.8.0"

# API Endpoints
readonly API_GEOCODING="https://nominatim.openstreetmap.org/search"
readonly API_GFZ_HP30="https://spaceweather.gfz.de/fileadmin/SW-Monitor/hp30_product_file_FORECAST_HP30_SWIFT_DRIVEN_LAST.csv"
readonly API_NOAA_KP="https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json"

# HTTP Configuration
readonly USER_AGENT="aurora-cli/${SCRIPT_VERSION} (https://github.com/ppseprus/aurora-cli)"
readonly HTTP_TIMEOUT=30

# Display Configuration
readonly DEFAULT_FORECAST_HOURS=24
readonly MAX_HISTORICAL_ENTRIES=16
readonly PROBABILITY_INCREMENT_PER_DEGREE=20

# Success Exit Codes
readonly EXIT_SUCCESS=0
readonly EXIT_NO_RESULTS=1

# Error Exit Codes
readonly EXIT_INCOMPATIBLE_SHELL=10
readonly EXIT_MISSING_DEPENDENCY=11
readonly EXIT_INVALID_ARGUMENT_SYNTAX=20
readonly EXIT_MISSING_REQUIRED_ARGUMENT=21
readonly EXIT_INVALID_ARGUMENT_VALUE=22
readonly EXIT_INCOMPATIBLE_OPTIONS=23
readonly EXIT_NETWORK_CONNECTIVITY=30
readonly EXIT_API_TIMEOUT=31
readonly EXIT_API_UNAVAILABLE=32
readonly EXIT_API_RATE_LIMIT=33
readonly EXIT_GEOCODING_FAILURE=34
readonly EXIT_DATA_VALIDATION_ERROR=40
readonly EXIT_EMPTY_API_RESPONSE=41
readonly EXIT_DATA_PARSING_ERROR=42
readonly EXIT_UNHANDLED_ERROR=99

# Validate shell environment
if [ -z "${BASH_VERSION:-}" ]; then
  echo "Error: This script requires Bash. Please run with 'bash aurora.sh' or make it executable." >&2
  exit "${EXIT_INCOMPATIBLE_SHELL}"
fi

# Validate bash version (require 3.2+)
if [ "${BASH_VERSINFO[0]}" -lt 3 ] || { [ "${BASH_VERSINFO[0]}" -eq 3 ] && [ "${BASH_VERSINFO[1]}" -lt 2 ]; }; then
  echo "Error: This script requires Bash 3.2 or higher. You have ${BASH_VERSION}." >&2
  exit "${EXIT_INCOMPATIBLE_SHELL}"
fi

# Color codes (disabled if not in TTY)
if [[ -t 1 ]]; then
  readonly COLOR_RESET=$'\033[0m'
  readonly COLOR_BOLD=$'\033[1m'
  readonly COLOR_RED=$'\033[0;31m'
  readonly COLOR_GREEN=$'\033[0;32m'
  readonly COLOR_YELLOW=$'\033[0;33m'
  readonly COLOR_BLUE=$'\033[0;34m'
  readonly COLOR_CYAN=$'\033[0;36m'
else
  readonly COLOR_RESET=''
  readonly COLOR_BOLD=''
  readonly COLOR_RED=''
  readonly COLOR_GREEN=''
  readonly COLOR_YELLOW=''
  readonly COLOR_BLUE=''
  readonly COLOR_CYAN=''
fi

# Display version information
show_version() {
  echo "aurora-cli ${SCRIPT_VERSION}"
}

# Display usage information
show_usage() {
  cat >&2 <<EOF
$(echo -e "${COLOR_BOLD}USAGE${COLOR_RESET}")
  ${SCRIPT_NAME} [--Hp30|--GFZ] [-f,--forecast <N>] [-m,--magnitude <M>] [-e,--estimate <value>] <location>
  ${SCRIPT_NAME} [--Kp|--NOAA] [-f,--forecast <N>] [-m,--magnitude <M>] [--hist] <location>

$(echo -e "${COLOR_BOLD}DESCRIPTION${COLOR_RESET}")
  Display aurora visibility forecast based on geomagnetic indices and your location.
  The closer you are to the magnetic poles, the higher your chances of seeing aurora.

$(echo -e "${COLOR_BOLD}INDEX / DATA SOURCE OPTIONS${COLOR_RESET}")
  --Hp30, --GFZ
      Use the GFZ Hp30 geomagnetic index (30-minute resolution). $(echo -e "${COLOR_BOLD}[default]${COLOR_RESET}")

  --Kp, --NOAA
      Use the NOAA Kp geomagnetic index (3-hour resolution).

$(echo -e "${COLOR_BOLD}FORECAST SETTINGS${COLOR_RESET}")
  -f, --forecast <N>
      Limit forecast to next N hours.
      Values can range from 1 to 72. $(echo -e "${COLOR_BOLD}[default: 24]${COLOR_RESET}")

  -m, --magnitude <M>
      Filter forecast to show only periods with magnitude ≥ M value.
      Minimum is 0, but the data is open-ended. $(echo -e "${COLOR_BOLD}[default: 0]${COLOR_RESET}")

  -e, --estimate <value>
      Select which estimate to use from ensemble forecast.
      Possible values:
      • median  - Use median estimate $(echo -e "${COLOR_BOLD}[default]${COLOR_RESET}")
      • low     - Use minimum estimate (more conservative)
      • high    - Use maximum estimate (more optimistic)
      Only supported when using GFZ Hp30.

  --hist
      Include historical data.
      Only supported when using NOAA Kp as data source.

$(echo -e "${COLOR_BOLD}INFORMATION OPTIONS${COLOR_RESET}")
  -h, --help
      Show this help message.

  -v, --version
      Show version information.

  --explain
      Show detailed explanation of probability calculations.

$(echo -e "${COLOR_BOLD}LOCATION FORMAT${COLOR_RESET}")
  Locations can be specified as:
  • City names: "Stockholm, Sweden" or "City, State, Country"
  • Geographic coordinates: "68.4363°N 17.3983°E"
  The tool will geocode your input using OpenStreetMap Nominatim.

$(echo -e "${COLOR_BOLD}NOTES${COLOR_RESET}")
  • Only one data source can be selected (GFZ Hp30 or NOAA Kp).
  • -e, --estimate only works when using GFZ Hp30.
  • --hist only works when using NOAA Kp.

$(echo -e "${COLOR_BOLD}EXAMPLES${COLOR_RESET}")
  ${SCRIPT_NAME} "Stockholm, Sweden"
  ${SCRIPT_NAME} "68.4363°N 17.3983°E"
  ${SCRIPT_NAME} -f 48 "Reykjavik, Iceland"
  ${SCRIPT_NAME} --Kp --hist --forecast 12 "Tromsø, Norway"
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
  • Provides ensemble forecasts with minimum, median, and maximum estimates
    reflecting uncertainty in the prediction model.
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

  Your location's absolute latitude determines aurora visibility probability:

  • If |latitude| < minimum latitude → 0% (too far from magnetic poles)
  • For each degree above minimum → +${PROBABILITY_INCREMENT_PER_DEGREE}% visibility probability
  • Probability caps at 100% when 5° or more above minimum
  • Formula: probability = min(100, max(0, (|latitude| - min_latitude) × ${PROBABILITY_INCREMENT_PER_DEGREE}))

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

# Error handling
error_exit() {
  local exit_code="${1:-${EXIT_UNHANDLED_ERROR}}"
  local message="$2"
  echo -e "${COLOR_RED}Error:${COLOR_RESET} ${message}" >&2
  exit ${exit_code}
}

# Info output
info() {
  local message="$1"
  echo -e "${COLOR_BLUE}→${COLOR_RESET} ${message}" >&2
}

# Check required dependencies
check_dependencies() {
  # Only check for jq - all other tools (curl, awk, bc, column) are standard utilities
  if ! command -v jq &>/dev/null; then
    error_exit "${EXIT_MISSING_DEPENDENCY}" "Missing required dependency: jq\n\nPlease install it using your package manager:\n  macOS:   brew install jq\n  Ubuntu:  sudo apt install jq\n  Fedora:  sudo dnf install jq"
  fi
}
# Validate hours parameter
validate_hours() {
  local hours="$1"
  if [[ ! ${hours} =~ ^[0-9]+$ ]]; then
    error_exit "${EXIT_INVALID_ARGUMENT_VALUE}" "Invalid hours value: ${hours}. Must be a positive integer."
  fi
  if ((hours < 1 || hours > 72)); then
    error_exit "${EXIT_INVALID_ARGUMENT_VALUE}" "Hours must be between 1 and 72. Got: ${hours}"
  fi
}

# Parse command line arguments
parse_args() {
  local location=""
  local show_historical="false"
  local data_source="GFZ"
  local forecast_hours="${DEFAULT_FORECAST_HOURS}"
  local hp30_column="4"  # Default to median
  local min_magnitude="0"  # Default: no filtering (show all)
  local estimate_used="false"  # Track if --estimate flag was explicitly used

  # Handle no arguments
  if [[ $# -eq 0 ]]; then
    show_usage
    exit "${EXIT_MISSING_REQUIRED_ARGUMENT}"
  fi

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_usage
        exit 0
        ;;
      -v|--version)
        show_version
        exit 0
        ;;
      --explain)
        explain
        exit 0
        ;;
      --GFZ|--Hp30)
        data_source="GFZ"
        shift
        ;;
      --NOAA|--Kp)
        data_source="NOAA"
        shift
        ;;
      -e|--estimate|--estimate=*|-e=*)
        estimate_used="true"
        local estimate_value=""
        if [[ "$1" == *=* ]]; then
          # Handle --estimate=value or -e=value pattern
          estimate_value="${1#*=}"
          shift
        elif [[ $# -gt 1 ]]; then
          # Handle --estimate value or -e value pattern
          shift
          estimate_value="$1"
          shift
        else
          error_exit "${EXIT_INVALID_ARGUMENT_SYNTAX}" "Option ${1} requires an argument."
        fi
        case "${estimate_value}" in
          median)
            hp30_column="4"
            ;;
          low)
            hp30_column="2"
            ;;
          high)
            hp30_column="6"
            ;;
          *)
            error_exit "${EXIT_INVALID_ARGUMENT_VALUE}" "Invalid estimate value: ${estimate_value}. Must be one of: median, low, high"
            ;;
        esac
        ;;
      --hist)
        show_historical="true"
        shift
        ;;
      -f|--forecast|--forecast=*|-f=*)
        if [[ "$1" == *=* ]]; then
          # Handle --forecast=hours or -f=hours pattern
          forecast_hours="${1#*=}"
          shift
        elif [[ $# -gt 1 ]]; then
          # Handle --forecast hours or -f hours pattern
          shift
          forecast_hours="$1"
          shift
        else
          error_exit "${EXIT_INVALID_ARGUMENT_SYNTAX}" "Option ${1} requires an argument."
        fi
        validate_hours "${forecast_hours}"
        ;;
      -m|--magnitude|--magnitude=*|-m=*)
        if [[ "$1" == *=* ]]; then
          # Handle --magnitude=value or -m=value pattern
          min_magnitude="${1#*=}"
          shift
        elif [[ $# -gt 1 ]]; then
          # Handle --magnitude value or -m value pattern
          shift
          min_magnitude="$1"
          shift
        else
          error_exit "${EXIT_INVALID_ARGUMENT_SYNTAX}" "Option ${1} requires an argument."
        fi
        # Validate magnitude value
        if [[ ! ${min_magnitude} =~ ^[0-9]+$ ]] || ((min_magnitude < 0)); then
          error_exit "${EXIT_INVALID_ARGUMENT_VALUE}" "Invalid magnitude value: ${min_magnitude}. Must be >= 0."
        fi
        ;;
      -*)
        error_exit "${EXIT_INVALID_ARGUMENT_SYNTAX}" "Unknown option: $1\n\nRun '${SCRIPT_NAME} --help' for usage information."
        ;;
      *)
        if [[ -z "${location}" ]]; then
          location="$1"
        else
          error_exit "${EXIT_INVALID_ARGUMENT_VALUE}" "Multiple locations specified. Please provide only one location."
        fi
        shift
        ;;
    esac
  done

  # Validate required arguments
  if [[ -z "${location}" ]]; then
    error_exit "${EXIT_MISSING_REQUIRED_ARGUMENT}" "Location is required.\n\nRun '${SCRIPT_NAME} --help' for usage information."
  fi

  # Validate incompatible options
  if [[ "${show_historical}" == "true" && "${data_source}" == "GFZ" ]]; then
    error_exit "${EXIT_INCOMPATIBLE_OPTIONS}" "Historical data (--hist) is only available with NOAA data source (--Kp or --NOAA)."
  fi

  if [[ "${estimate_used}" == "true" && "${data_source}" == "NOAA" ]]; then
    error_exit "${EXIT_INCOMPATIBLE_OPTIONS}" "The --estimate option is only available with GFZ data source (--Hp30 or --GFZ)."
  fi

  echo "${location}|${show_historical}|${data_source}|${forecast_hours}|${hp30_column}|${min_magnitude}"
}

# Handle API response errors and extract response body
# Usage: handle_api_response <response> <curl_exit_code> <service_name>
handle_api_response() {
  local response="$1"
  local curl_exit="$2"
  local service_name="$3"
  local http_code
  local response_body

  # Extract HTTP status code from response
  http_code=$(echo "${response}" | tail -n1)
  response_body=$(echo "${response}" | sed '$d')

  # Handle curl errors
  if [[ ${curl_exit} -eq 28 ]]; then
    error_exit "${EXIT_API_TIMEOUT}" "Request to ${service_name} timed out after ${HTTP_TIMEOUT} seconds. Please try again."
  elif [[ ${curl_exit} -ne 0 ]]; then
    error_exit "${EXIT_NETWORK_CONNECTIVITY}" "Failed to connect to ${service_name}."
  fi

  # Handle HTTP status codes
  if [[ "${http_code}" == "429" ]]; then
    error_exit "${EXIT_API_RATE_LIMIT}" "${service_name} rate limit exceeded. Please wait a moment and try again."
  elif [[ "${http_code}" =~ ^5 ]]; then
    error_exit "${EXIT_API_UNAVAILABLE}" "${service_name} is temporarily unavailable (HTTP ${http_code}). Please try again later."
  elif [[ "${http_code}" != "200" ]] && [[ -n "${http_code}" ]]; then
    error_exit "${EXIT_NETWORK_CONNECTIVITY}" "${service_name} returned error (HTTP ${http_code})."
  fi

  # Return cleaned response body
  echo "${response_body}"
}

# Geocode location to coordinates
geocode_location() {
  local location="$1"
  local geo_json
  local lat lon display_name

  info "Fetching coordinates for: ${COLOR_BOLD}${location}${COLOR_RESET}"

  local response
  response=$(curl -sf -w "\n%{http_code}" \
    -m "${HTTP_TIMEOUT}" \
    -H "User-Agent: ${USER_AGENT}" \
    --get "${API_GEOCODING}" \
    --data-urlencode "q=${location}" \
    --data "format=json" \
    --data "limit=1" 2>&1)
  local curl_exit=$?

  # Handle API response and extract body
  geo_json=$(handle_api_response "${response}" "${curl_exit}" "Geocoding service")

  # Parse geocoding response
  lat=$(echo "${geo_json}" | jq -r '.[0].lat // empty')
  lon=$(echo "${geo_json}" | jq -r '.[0].lon // empty')
  display_name=$(echo "${geo_json}" | jq -r '.[0].display_name // empty')

  # Validate geocoding results
  if [[ -z ${lat} || -z ${lon} ]]; then
    error_exit "${EXIT_GEOCODING_FAILURE}" "Location not found: ${location}\n\nTry using a more specific format:\n  • City, Country (e.g., 'Stockholm, Sweden')\n  • City, State, Country (e.g., 'Portland, Oregon, USA')"
  fi

  # Format coordinates to 2 decimal places
  lat=$(printf "%.2f" "${lat}")
  lon=$(printf "%.2f" "${lon}")

  echo "${lat}|${lon}|${display_name}"
}

# Fetch NOAA Kp forecast data
fetch_noaa_kp_forecast() {
  info "Retrieving NOAA Planetary Kp-index forecast..."

  local response
  response=$(curl -sf -w "\n%{http_code}" \
    -m "${HTTP_TIMEOUT}" \
    -H "User-Agent: ${USER_AGENT}" \
    "${API_NOAA_KP}" 2>&1)
  local curl_exit=$?

  # Handle API response and extract body
  local forecast_data
  forecast_data=$(handle_api_response "${response}" "${curl_exit}" "NOAA API")

  # Validate JSON response
  if ! echo "${forecast_data}" | jq -e '.[0][0]' &>/dev/null; then
    error_exit "${EXIT_DATA_VALIDATION_ERROR}" "Invalid response from NOAA API. Please try again later."
  fi

  echo "${forecast_data}"
}

# Fetch GFZ/ESA Hp30 forecast data
fetch_gfz_hp30_forecast() {
  local column="${1:-4}"  # Default to median (column 4)
  info "Retrieving GFZ/ESA Hp30 forecast..."

  local response
  response=$(curl -sf -w "\n%{http_code}" \
    -m "${HTTP_TIMEOUT}" \
    -H "User-Agent: ${USER_AGENT}" \
    "${API_GFZ_HP30}" 2>&1)
  local curl_exit=$?

  # Handle API response and extract body
  local csv_data
  csv_data=$(handle_api_response "${response}" "${curl_exit}" "GFZ API")

  # Validate CSV response
  if [[ -z "${csv_data}" ]]; then
    error_exit "${EXIT_EMPTY_API_RESPONSE}" "Empty response from GFZ API. Please try again later."
  fi

  # Convert CSV to JSON format
  # Skip header line and extract Time (UTC) column 1 and the selected estimate column
  local json_data
  json_data=$(echo "${csv_data}" | tail -n +2 | awk -F',' -v col="${column}" '
    BEGIN { print "[" }
    NR > 1 { print "," }
    {
      # Remove leading/trailing whitespace
      gsub(/^[ \t]+|[ \t]+$/, "", $1)
      gsub(/^[ \t]+|[ \t]+$/, "", $col)

      # Parse date format: DD-MM-YYYY HH:MM to YYYY-MM-DD HH:MM
      split($1, datetime, " ")
      split(datetime[1], dateparts, "-")
      day = dateparts[1]
      month = dateparts[2]
      year = dateparts[3]
      time_part = datetime[2]

      # Output JSON array format ["timestamp", value]
      formatted_time = year "-" month "-" day " " time_part
      printf "[\"%s\",%s]", formatted_time, $col
    }
    END { print "\n]" }
  ')

  # Validate JSON output
  if ! echo "${json_data}" | jq -e '.[0][0]' &>/dev/null; then
    error_exit "${EXIT_DATA_PARSING_ERROR}" "Failed to parse GFZ Hp30 data. Please try again later."
  fi

  echo "${json_data}" | jq -c .
}

# Map geomagnetic index to minimum latitude for aurora visibility
# Uses rounded index value to determine latitude threshold
get_minimum_latitude() {
  local index_value="$1"
  local rounded_index

  # Round to nearest integer using bc for precision
  rounded_index=$(printf "%.0f" "${index_value}")

  # Map index to minimum latitude based on scientific data
  case "${rounded_index}" in
    0) echo "67" ;;
    1) echo "66" ;;
    2) echo "65" ;;
    3) echo "64" ;;
    4) echo "62" ;;
    5) echo "60" ;;
    6) echo "57" ;;
    7) echo "54" ;;
    8) echo "51" ;;
    *) echo "48" ;;  # 9 and above
  esac
}

# Calculate aurora visibility probability based on latitude and index
calculate_visibility_probability() {
  local latitude="$1"
  local min_latitude="$2"
  local probability

  # Use absolute value of latitude (works for both hemispheres)
  latitude=$(awk -v lat="${latitude}" 'BEGIN {print (lat < 0) ? -lat : lat}')

  # Calculate latitude difference and probability using awk for floating point
  probability=$(awk -v lat="${latitude}" -v min_lat="${min_latitude}" -v incr="${PROBABILITY_INCREMENT_PER_DEGREE}" '
    BEGIN {
      diff = lat - min_lat
      prob = int(diff * incr)
      if (prob < 0) prob = 0
      else if (prob > 100) prob = 100
      print prob
    }
  ')

  echo "${probability}"
}

# Get outlook category based on probability
get_outlook_category() {
  local probability="$1"

  if ((probability == 0)); then
    echo "None"
  elif ((probability <= 20)); then
    echo "Low"
  elif ((probability <= 50)); then
    echo "Fair"
  elif ((probability <= 75)); then
    echo "Good"
  else
    echo "Excellent"
  fi
}

# Generate jq filter to enrich data with min_lat and probability
# This filter adds calculated fields based on geomagnetic index
build_enrichment_jq_filter() {
  cat <<'JQ_FILTER'
| map(. + {
    min_lat: (
      (.index | round) as $rounded |
      if $rounded >= 9 then 48
      elif $rounded == 8 then 51
      elif $rounded == 7 then 54
      elif $rounded == 6 then 57
      elif $rounded == 5 then 60
      elif $rounded == 4 then 62
      elif $rounded == 3 then 64
      elif $rounded == 2 then 65
      elif $rounded == 1 then 66
      else 67 end
    )
  })
| map(. + {
    prob: (
      (($lat | tonumber | fabs) - .min_lat) as $diff
      | if $diff <= 0 then 0
        else (($diff * 20) | if . > 100 then 100 else . end | floor)
        end
    )
  })
JQ_FILTER
}

# Display aurora forecast
display_forecast() {
  local latitude="$1"
  local longitude="$2"
  local location_name="$3"
  local forecast_json="$4"
  local show_historical="${5:-false}"
  local data_source="${6:-GFZ}"
  local forecast_hours="${7:-24}"
  local hp30_column="${8:-4}"
  local min_magnitude="${9:-}"
  local current_utc_time

  current_utc_time=$(date -u +"%Y-%m-%d %H:%M")

  # Determine index name for display
  local index_name
  if [[ ${data_source} == "GFZ" ]]; then
    index_name="Hp30"
  else
    index_name="Kp"
  fi

  # Determine estimate display name for GFZ source
  local estimate_display=""
  if [[ "${data_source}" == "GFZ" ]]; then
    case "${hp30_column}" in
      2) estimate_display="minimum (conservative)" ;;
      4) estimate_display="median" ;;
      6) estimate_display="maximum (optimistic)" ;;
      *) estimate_display="median" ;;
    esac
  fi

  # Calculate maximum forecast entries based on resolution
  local max_forecast_entries
  if [[ ${data_source} == "GFZ" ]]; then
    # GFZ: 30-minute resolution = 2 entries per hour
    max_forecast_entries=$((forecast_hours * 2))
  else
    # NOAA: 3-hour resolution = 1 entry per 3 hours
    max_forecast_entries=$(((forecast_hours + 2) / 3))
  fi

  # Process historical data if requested
  local historical_data=""
  if [[ ${show_historical} == "true" ]]; then
    local hist_jq_filter='.[1:] | map({time: .[0], index: (.[1] | tonumber)}) | map(select(.time < $now))'

    # Apply magnitude filter if specified (> 0)
    if [[ -n ${min_magnitude} ]] && ((min_magnitude > 0)); then
      hist_jq_filter="${hist_jq_filter} | map(select(.index >= ${min_magnitude}))"
    fi

    hist_jq_filter="${hist_jq_filter} | sort_by(.time) | .[-\$max_hist:]$(build_enrichment_jq_filter)"

    historical_data=$(echo "${forecast_json}" | jq -r --arg lat "${latitude}" --arg now "${current_utc_time}" --argjson max_hist "${MAX_HISTORICAL_ENTRIES}" "${hist_jq_filter}")
  fi

  # Process forecast data
  local forecast_data
  local jq_filter='.[1:] | map({time: .[0], index: (.[1] | tonumber)}) | map(select(.time >= $now))'

  # Apply magnitude filter if specified (> 0)
  if [[ -n ${min_magnitude} ]] && ((min_magnitude > 0)); then
    jq_filter="${jq_filter} | map(select(.index >= ${min_magnitude}))"
  fi

  jq_filter="${jq_filter} | .[0:\$max_entries]$(build_enrichment_jq_filter)"

  forecast_data=$(echo "${forecast_json}" | jq -r --arg lat "${latitude}" --arg now "${current_utc_time}" --argjson max_entries "${max_forecast_entries}" "${jq_filter}")

  # Display header
  echo
  echo -e "${COLOR_BOLD}  AURORA VISIBILITY FORECAST${COLOR_RESET}"
  echo -e "${COLOR_BOLD}================================================================================${COLOR_RESET}"
  echo
  echo -e "  ${COLOR_CYAN}Location:${COLOR_RESET}      ${location_name}"
  echo -e "  ${COLOR_CYAN}Coordinates:${COLOR_RESET}   ${latitude}°, ${longitude}°"
  echo -e "  ${COLOR_CYAN}Data Source:${COLOR_RESET}   ${data_source} ${index_name}"
  if [[ -n "${estimate_display}" ]]; then
    echo -e "  ${COLOR_CYAN}Estimate:${COLOR_RESET}      ${estimate_display}"
  fi
  echo -e "  ${COLOR_CYAN}Magnitude:${COLOR_RESET}     ≥${min_magnitude}"
  echo -e "  ${COLOR_CYAN}Forecast Time:${COLOR_RESET} ${current_utc_time} UTC"
  echo
  echo -e "  ${COLOR_BOLD}Note:${COLOR_RESET} Each degree above minimum latitude adds ~${PROBABILITY_INCREMENT_PER_DEGREE}% visibility probability"
  echo

  # Display forecast table
  # Generate table without colors, align with column, then apply colors to specific rows
  {
    echo -e "Time_(UTC)\t${index_name}\tMin_Lat\tProbability\tOutlook"

    # Show historical data if available
    if [[ ${show_historical} == "true" && -n ${historical_data} ]]; then
      echo "${historical_data}" | jq -r '
        .[] |
        (if .prob == 0 then "None"
         elif .prob <= 20 then "Low"
         elif .prob <= 50 then "Fair"
         elif .prob <= 75 then "Good"
         else "Excellent" end) as $outlook |
        (.index | . * 100 | round / 100) as $idx |
        (if $idx < 10 then " " + ($idx | tostring) else ($idx | tostring) end) as $padded_idx |
        (.prob | tostring) as $prob_str |
        (if .prob < 10 then "  " + $prob_str elif .prob < 100 then " " + $prob_str else $prob_str end) as $padded_prob |
        (.min_lat | tostring) as $lat_str |
        (if .min_lat < 10 then " " + $lat_str else $lat_str end) as $padded_lat |
        "\(.time)\t\($padded_idx)\t≥\($padded_lat)°\t\($padded_prob)%\t\($outlook)"
      '
      # Separator between historical and forecast
      echo -e "━━━━━ PRESENT ━━━━━\t\t\t\t"
    fi

    # Show forecast data
    echo "${forecast_data}" | jq -r '
      .[] |
      (if .prob == 0 then "None"
       elif .prob <= 20 then "Low"
       elif .prob <= 50 then "Fair"
       elif .prob <= 75 then "Good"
       else "Excellent" end) as $outlook |
      (.index | . * 100 | round / 100) as $idx |
      (if $idx < 10 then " " + ($idx | tostring) else ($idx | tostring) end) as $padded_idx |
      (.prob | tostring) as $prob_str |
      (if .prob < 10 then "  " + $prob_str elif .prob < 100 then " " + $prob_str else $prob_str end) as $padded_prob |
      (.min_lat | tostring) as $lat_str |
      (if .min_lat < 10 then " " + $lat_str else $lat_str end) as $padded_lat |
      "\(.time)\t\($padded_idx)\t≥\($padded_lat)°\t\($padded_prob)%\t\($outlook)"
    '
  } | column -t -s $'\t' \
    | awk -v bold="${COLOR_BOLD}" -v reset="${COLOR_RESET}" '
      NR == 1 { print bold $0 reset; next }
      /^━━━━━ PRESENT ━━━━━/ { print bold $0 reset; next }
      { print }
    '

  echo
  echo -e "  ${COLOR_CYAN}Tip:${COLOR_RESET} Run '${SCRIPT_NAME} --explain' for detailed probability calculations"
  echo

  # Return success if we have forecast data, failure if empty
  local result_count
  result_count=$(echo "${forecast_data}" | jq -r 'length')
  if [[ "${result_count}" -gt 0 ]]; then
    return 0
  else
    return 1
  fi
}

# Main execution
main() {
  # Handle information flags first (before dependency checks)
  for arg in "$@"; do
    case "${arg}" in
      -h|--help)
        show_usage
        exit 0
        ;;
      -v|--version)
        show_version
        exit 0
        ;;
      --explain)
        explain
        exit 0
        ;;
    esac
  done

  # Check system dependencies
  check_dependencies

  # Parse command line arguments
  local args_result location show_historical data_source forecast_hours hp30_column min_magnitude
  args_result=$(parse_args "$@")
  IFS='|' read -r location show_historical data_source forecast_hours hp30_column min_magnitude <<< "${args_result}"

  # Geocode location to coordinates
  local geo_result latitude longitude location_name
  geo_result=$(geocode_location "${location}")
  IFS='|' read -r latitude longitude location_name <<< "${geo_result}"

  # Fetch forecast data from appropriate source
  local forecast_json
  if [[ ${data_source} == "GFZ" ]]; then
    forecast_json=$(fetch_gfz_hp30_forecast "${hp30_column}")
  else
    forecast_json=$(fetch_noaa_kp_forecast)
  fi

  # Display forecast results
  display_forecast "${latitude}" "${longitude}" "${location_name}" "${forecast_json}" "${show_historical}" "${data_source}" "${forecast_hours}" "${hp30_column}" "${min_magnitude}"
  local has_results=$?

  if [[ ${has_results} -eq 0 ]]; then
    exit "${EXIT_SUCCESS}"
  else
    exit "${EXIT_NO_RESULTS}"
  fi
}

# Script entry point
main "$@"
