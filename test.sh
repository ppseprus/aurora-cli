#!/usr/bin/env bash
#
# Aurora CLI Test Suite
# Tests argument validation, flags, exit codes, and API interactions
#
set -uo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/aurora.sh"
MOCK_DIR="${SCRIPT_DIR}/test_mocks"

# Current date for dynamic testing
CURRENT_DATE=$(date +%Y-%m-%d)

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
declare -a FAILED_TESTS=()

# Current test name
CURRENT_TEST=""

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

# Test helper functions
test_start() {
  CURRENT_TEST="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
  echo ""
  echo "${CURRENT_TEST}"
}

test_pass() {
  local message="$1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  ${GREEN}✓ ${message}${RESET}"
}

test_fail() {
  local message="$1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_TESTS+=("${CURRENT_TEST}: ${message}")
  echo "  ${RED}✗ ${message}${RESET}"
}

# Assertion functions
assert_contains() {
  local output="$1"
  local criteria="$2"
  local description="${3:-Should contain '${criteria}'}"

  if echo "${output}" | grep -qiF "${criteria}"; then
    test_pass "${description}"
  else
    test_fail "${description}"
  fi
}

assert_not_contains() {
  local output="$1"
  local criteria="$2"
  local description="${3:-Should not contain '${criteria}'}"

  if ! echo "${output}" | grep -qiF "${criteria}"; then
    test_pass "${description}"
  else
    test_fail "${description}"
  fi
}

assert_matches() {
  local actual="$1"
  local expected="$2"
  local description="${3:-Should match '${actual}'}"

  if [[ "${actual}" == "${expected}" ]]; then
    test_pass "${description}"
  else
    test_fail "${description} (expected ${expected}, got ${actual})"
  fi
}

assert_exit_code() {
  local actual="$1"
  local expected="$2"
  local description="${3:-Should exit with ${expected}}"

  if [[ "${actual}" -eq "${expected}" ]]; then
    test_pass "${description}"
  else
    test_fail "${description} (expected ${expected}, got ${actual})"
  fi
}

# Mocked curl
mock_curl() {
  local scenario="$1"
  shift
  export AURORA_TEST_SCENARIO="${scenario}"
  set +e  # Temporarily disable exit-on-error
  PATH="${MOCK_DIR}:${PATH}" "$@"
  local result=$?
  set -e  # Re-enable exit-on-error
  unset AURORA_TEST_SCENARIO
  return ${result}
}

# Print test summary
print_summary() {
  echo ""

  # Calculate total tests
  local tests_total=$((TESTS_PASSED + TESTS_FAILED))

  # Print simple summary
  echo "Tests run:    ${tests_total}${RESET}"
  echo "Tests passed: ${GREEN}${TESTS_PASSED}${RESET}"

  # If there are failures, show count and details
  if [[ ${TESTS_FAILED} -gt 0 ]]; then
    echo "Tests failed: ${RED}${TESTS_FAILED}${RESET}"
  fi

  if [[ ${TESTS_FAILED} -gt 0 ]]; then
    echo ""
    echo "Failed tests:"
    for failed_test in "${FAILED_TESTS[@]}"; do
      echo "  ${RED}✗ ${failed_test}${RESET}"
    done
    exit 1
  fi
}

# Verify test dependencies
if ! command -v jq &> /dev/null; then
  echo "${RED}Error: jq is required but not installed.${RESET}" >&2
  exit 1
fi

if [[ ! -f "${SCRIPT_PATH}" ]]; then
  echo "${RED}Error: aurora.sh not found at ${SCRIPT_PATH}${RESET}" >&2
  exit 1
fi

if [[ ! -d "${MOCK_DIR}" ]]; then
  echo "${RED}Error: Mock directory not found at ${MOCK_DIR}${RESET}" >&2
  exit 1
fi

# Print test header
echo "${BOLD}Aurora CLI Test Suite${RESET}"

# INFORMATION FLAGS TESTS

test_start "Using the --help flag"
output=$("${SCRIPT_PATH}" --help 2>&1)
exit_code=$?
assert_contains "${output}" "USAGE"
assert_exit_code "${exit_code}" 0

test_start "Using the -h short flag"
output=$("${SCRIPT_PATH}" -h 2>&1)
exit_code=$?
assert_contains "${output}" "USAGE"
assert_exit_code "${exit_code}" 0

test_start "Using the --version flag"
output=$("${SCRIPT_PATH}" --version 2>&1)
exit_code=$?
assert_contains "${output}" "aurora-cli"
assert_exit_code "${exit_code}" 0

test_start "Using the -v short flag"
output=$("${SCRIPT_PATH}" -v 2>&1)
exit_code=$?
assert_contains "${output}" "aurora-cli"
assert_exit_code "${exit_code}" 0

test_start "Using the --explain flag"
output=$("${SCRIPT_PATH}" --explain 2>&1)
exit_code=$?
assert_contains "${output}" "About Geomagnetic Indices"
assert_contains "${output}" "Index Scale and Minimum Latitude Mapping"
assert_contains "${output}" "Probability Calculation"
assert_contains "${output}" "Latitude Effect"
assert_contains "${output}" "Why Hp30 is Better for Aurora Watching"
assert_exit_code "${exit_code}" 0

# INVALID ARGUMENTS

test_start "Providing an unknown flag"
output=$("${SCRIPT_PATH}" --invalid-flag 2>&1)
exit_code=$?
assert_contains "${output}" "Unknown option"
assert_exit_code "${exit_code}" 20

test_start "Using --forecast without value"
output=$("${SCRIPT_PATH}" --forecast 2>&1)
exit_code=$?
assert_contains "${output}" "requires an argument"
assert_exit_code "${exit_code}" 20

test_start "Using -f without value"
output=$("${SCRIPT_PATH}" -f 2>&1)
exit_code=$?
assert_contains "${output}" "requires an argument"
assert_exit_code "${exit_code}" 20

test_start "Using --magnitude without value"
output=$("${SCRIPT_PATH}" --magnitude 2>&1)
exit_code=$?
assert_contains "${output}" "requires an argument"
assert_exit_code "${exit_code}" 20

test_start "Using -m without value"
output=$("${SCRIPT_PATH}" -m 2>&1)
exit_code=$?
assert_contains "${output}" "requires an argument"
assert_exit_code "${exit_code}" 20

test_start "Using --estimate without value"
output=$("${SCRIPT_PATH}" --estimate 2>&1)
exit_code=$?
assert_contains "${output}" "requires an argument"
assert_exit_code "${exit_code}" 20

test_start "Using -e without value"
output=$("${SCRIPT_PATH}" -e 2>&1)
exit_code=$?
assert_contains "${output}" "requires an argument"
assert_exit_code "${exit_code}" 20

# MISSING REQUIRED ARGUMENTS

test_start "Not providing any arguments"
output=$("${SCRIPT_PATH}" 2>&1)
exit_code=$?
assert_contains "${output}" "USAGE"
assert_exit_code "${exit_code}" 21

test_start "Providing only flags without location"
output=$("${SCRIPT_PATH}" --GFZ 2>&1)
exit_code=$?
assert_contains "${output}" "Location is required"
assert_exit_code "${exit_code}" 21

test_start "Providing only the --raw flag without location"
output=$("${SCRIPT_PATH}" --raw 2>&1)
exit_code=$?
assert_contains "${output}" "Location is required"
assert_exit_code "${exit_code}" 21

# INVALID ARGUMENT VALUES

test_start "Providing non-numeric forecast hours"
output=$("${SCRIPT_PATH}" --forecast asd "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "Invalid hours value"
assert_exit_code "${exit_code}" 22

test_start "Providing negative forecast hours"
output=$("${SCRIPT_PATH}" --forecast -5 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "Invalid hours value"
assert_exit_code "${exit_code}" 22

test_start "Providing zero as forecast hour"
output=$("${SCRIPT_PATH}" --forecast 0 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "must be between 1 and 72"
assert_exit_code "${exit_code}" 22

test_start "Providing greater than 72 as forecast hour"
output=$("${SCRIPT_PATH}" --forecast 999 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "must be between 1 and 72"
assert_exit_code "${exit_code}" 22

test_start "Providing non-numeric magnitude"
output=$("${SCRIPT_PATH}" --magnitude asd "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "Invalid magnitude value"
assert_exit_code "${exit_code}" 22

test_start "Providing negative magnitude"
output=$("${SCRIPT_PATH}" --magnitude -1 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "Invalid magnitude value"
assert_exit_code "${exit_code}" 22

test_start "Providing invalid estimate value"
output=$("${SCRIPT_PATH}" --estimate invalid "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "Invalid estimate value"
assert_exit_code "${exit_code}" 22

test_start "Providing numeric estimate value"
output=$("${SCRIPT_PATH}" --estimate 5 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "Invalid estimate value"
assert_exit_code "${exit_code}" 22

test_start "Providing multiple locations"
output=$("${SCRIPT_PATH}" "Stockholm" "Oslo" 2>&1)
exit_code=$?
assert_contains "${output}" "Multiple locations"
assert_exit_code "${exit_code}" 22

# INCOMPATIBLE OPTIONS

test_start "Using --hist with implicit --GFZ"
output=$("${SCRIPT_PATH}" --hist "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "only available with NOAA"
assert_exit_code "${exit_code}" 23

test_start "Using --hist with explicit --GFZ"
output=$("${SCRIPT_PATH}" --GFZ --hist "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "only available with NOAA"
assert_exit_code "${exit_code}" 23

test_start "Using --hist with --Hp30"
output=$("${SCRIPT_PATH}" --Hp30 --hist "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "only available with NOAA"
assert_exit_code "${exit_code}" 23

test_start "Using --estimate with --NOAA"
output=$("${SCRIPT_PATH}" --NOAA -e median "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "only available with GFZ"
assert_exit_code "${exit_code}" 23

test_start "Using --estimate with --Kp"
output=$("${SCRIPT_PATH}" --Kp --estimate low "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "only available with GFZ"
assert_exit_code "${exit_code}" 23

# NETWORK ERROR

test_start "Having geocode API network connectivity error"
output=$(mock_curl geocode_api_network_error "${SCRIPT_PATH}" "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "Failed to connect"
# FIXME: Should exit with 30
assert_exit_code "${exit_code}" 34 "Should return geocoding failure (network error prevents geocoding)"

test_start "Having index API network connectivity error"
output=$(mock_curl index_api_network_error "${SCRIPT_PATH}" "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "Failed to connect"
# FIXME: Should exit with 30
assert_exit_code "${exit_code}" 41 "Should return empty response error (network error caught but then validated)"

# API TIMEOUTS

test_start "Having geocode API network timeout (curl exits with 28)"
output=$(mock_curl geocode_api_timeout "${SCRIPT_PATH}" "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "timed out"
# FIXME: Should exit with 31
assert_exit_code "${exit_code}" 34 "Should return geocoding failure (timeout prevents geocoding)"

test_start "Having index API network timeout (curl exits with 28)"
output=$(mock_curl index_api_timeout "${SCRIPT_PATH}" "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "timed out"
# FIXME: Should exit with 31
assert_exit_code "${exit_code}" 41 "Should return empty response error (timeout caught but then validated)"

# API UNAVAILABLE

test_start "When geocode API is unavailable (HTTP 503)"
output=$(mock_curl geocode_api_fail "${SCRIPT_PATH}" "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "unavailable"
# FIXME: Should exit with 32
assert_exit_code "${exit_code}" 34 "Should return geocoding failure (service unavailable)"

test_start "When GFZ API is unavailable (HTTP 503)"
output=$(mock_curl index_api_fail "${SCRIPT_PATH}" --GFZ "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "unavailable"
# FIXME: Should exit with 32
assert_exit_code "${exit_code}" 41 "Should return empty response error (unavailable caught but then validated)"

test_start "When NOAA API is unavailable (HTTP 503)"
output=$(mock_curl index_api_fail "${SCRIPT_PATH}" --NOAA "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "unavailable"
# FIXME: Should exit with 32
assert_exit_code "${exit_code}" 40 "Should return empty response error (unavailable caught but then validated)"

# API RATE LIMITS

test_start "Having geocode API rate limit (HTTP 429)"
output=$(mock_curl geocode_api_rate_limit "${SCRIPT_PATH}" "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "rate limit"
# FIXME: Should exit with 33
assert_exit_code "${exit_code}" 34 "Should return geocoding failure (rate limit prevents geocoding)"

test_start "Having index API rate limit (HTTP 429)"
output=$(mock_curl index_api_rate_limit "${SCRIPT_PATH}" "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "rate limit"
# FIXME: Should exit with 33
assert_exit_code "${exit_code}" 41 "Should return empty response error (rate limit caught but then validated)"

# GEOCODING ERROR SCENARIOS

test_start "When location not found"
output=$(mock_curl location_not_found "${SCRIPT_PATH}" "NonexistentPlace123456" 2>&1)
exit_code=$?
assert_contains "${output}" "Location not found"
assert_exit_code "${exit_code}" 34 "Should return geocoding failure error"

# DATA VALIDATION ERROR SCENARIOS

test_start "Receiving invalid NOAA API response"
output=$(mock_curl noaa_invalid "${SCRIPT_PATH}" --NOAA "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "Invalid response"
assert_exit_code "${exit_code}" 40 "Should return data validation error"

# EMPTY API RESPONSE

test_start "Receiving empty GFZ API response"
output=$(mock_curl gfz_empty "${SCRIPT_PATH}" --GFZ "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "Failed to parse"
# FIXME: Should exit with 41
assert_exit_code "${exit_code}" 42 "Should return data parsing error"

# DATA PARSING ERROR

test_start "Receiving malformed GFZ API response"
output=$(mock_curl gfz_malformed "${SCRIPT_PATH}" --GFZ "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "Failed to parse"
assert_exit_code "${exit_code}" 42 "Should return data parsing error"

# VALID FLAG FORMATS AND COMBINATIONS

test_start "Using GFZ flag format: --GFZ"
output=$(mock_curl success "${SCRIPT_PATH}" --GFZ "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Using GFZ flag format: --Hp30"
output=$(mock_curl success "${SCRIPT_PATH}" --Hp30 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Using NOAA flag format: --NOAA"
output=$(mock_curl success "${SCRIPT_PATH}" --NOAA "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Using NOAA flag format: --Kp"
output=$(mock_curl success "${SCRIPT_PATH}" --Kp "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Using forecast flag format: --forecast 24"
output=$(mock_curl success "${SCRIPT_PATH}" --forecast 24 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Using forecast flag format: --forecast=24"
output=$(mock_curl success "${SCRIPT_PATH}" --forecast=24 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Using forecast flag format: -f 24"
output=$(mock_curl success "${SCRIPT_PATH}" -f 24 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Using forecast flag format: -f=24"
output=$(mock_curl success "${SCRIPT_PATH}" -f=24 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Providing multiple forecast values"
output=$("${SCRIPT_PATH}" --forecast 1 --forecast 2 "Stockholm" --raw | wc -l | xargs 2>&1)
exit_code=$?
assert_matches "${output}" 4 "Should respect the last value provided"
assert_exit_code "${exit_code}" 0

test_start "Providing multiple forecast values"
output=$("${SCRIPT_PATH}" --forecast 2 --forecast 1 "Stockholm" --raw | wc -l | xargs 2>&1)
exit_code=$?
assert_matches "${output}" 2 "Should respect the last value provided"
assert_exit_code "${exit_code}" 0

test_start "Using magnitude format: --magnitude 3"
output=$(mock_curl success "${SCRIPT_PATH}" --magnitude 3 "Stockholm" 2>&1)
exit_code=$?
[[ ${exit_code} -eq 0 || ${exit_code} -eq 1 ]] && test_pass "Exit code is 0 or 1 (got ${exit_code})" || test_fail "Expected exit code 0 or 1 (got ${exit_code})"

test_start "Using magnitude format: --magnitude=3"
output=$(mock_curl success "${SCRIPT_PATH}" --magnitude=3 "Stockholm" 2>&1)
exit_code=$?
[[ ${exit_code} -eq 0 || ${exit_code} -eq 1 ]] && test_pass "Exit code is 0 or 1 (got ${exit_code})" || test_fail "Expected exit code 0 or 1 (got ${exit_code})"

test_start "Using magnitude format: -m 3"
output=$(mock_curl success "${SCRIPT_PATH}" -m 3 "Stockholm" 2>&1)
exit_code=$?
[[ ${exit_code} -eq 0 || ${exit_code} -eq 1 ]] && test_pass "Exit code is 0 or 1 (got ${exit_code})" || test_fail "Expected exit code 0 or 1 (got ${exit_code})"

test_start "Using magnitude format: -m=3"
output=$(mock_curl success "${SCRIPT_PATH}" -m=3 "Stockholm" 2>&1)
exit_code=$?
[[ ${exit_code} -eq 0 || ${exit_code} -eq 1 ]] && test_pass "Exit code is 0 or 1 (got ${exit_code})" || test_fail "Expected exit code 0 or 1 (got ${exit_code})"

test_start "Providing multiple magnitude values"
output=$("${SCRIPT_PATH}" --magnitude 1 --magnitude 2 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "Magnitude:     ≥2" "Should respect the last value provided"
assert_exit_code "${exit_code}" 0

test_start "Providing multiple magnitude values"
output=$("${SCRIPT_PATH}" --magnitude 2 --magnitude 1 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "Magnitude:     ≥1" "Should respect the last value provided"
assert_exit_code "${exit_code}" 0

test_start "Selecting minimum estimates for Hp30"
output=$(mock_curl success "${SCRIPT_PATH}" -e=low "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Selecting median estimates for Hp30"
output=$(mock_curl success "${SCRIPT_PATH}" -e median "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Selecting median estimates for Hp30"
output=$(mock_curl success "${SCRIPT_PATH}" --estimate median "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Selecting maximum estimates for Hp30"
output=$(mock_curl success "${SCRIPT_PATH}" --estimate=high "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Providing multiple estimate values"
output=$("${SCRIPT_PATH}" --estimate low --estimate high "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "maximum" "Should respect the last value provided"
assert_exit_code "${exit_code}" 0

test_start "Providing multiple estimate values"
output=$("${SCRIPT_PATH}" --estimate high --estimate low "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "minimum" "Should respect the last value provided"
assert_exit_code "${exit_code}" 0

test_start "Having multiple compatible flags: --GFZ -f 24 -m 3 -e median"
output=$(mock_curl success "${SCRIPT_PATH}" --GFZ -f 24 -m 3 -e median "Stockholm" 2>&1)
exit_code=$?
[[ ${exit_code} -eq 0 || ${exit_code} -eq 1 ]] && test_pass "Exit code is 0 or 1 (got ${exit_code})" || test_fail "Expected exit code 0 or 1 (got ${exit_code})"

test_start "Having multiple compatible flags: --NOAA --hist -f 12"
output=$(mock_curl success "${SCRIPT_PATH}" --NOAA --hist -f 12 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

# BOUNDARY VALUES

test_start "Providing minimum valid forecast hours (1)"
output=$(mock_curl success "${SCRIPT_PATH}" -f 1 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Providing maximum valid forecast hours (72)"
output=$(mock_curl success "${SCRIPT_PATH}" -f 72 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Providing minimum valid magnitude (0)"
output=$(mock_curl success "${SCRIPT_PATH}" -m 0 "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

test_start "Providing large magnitude value (999)"
output=$(mock_curl success "${SCRIPT_PATH}" -m 999 "Stockholm" 2>&1)
exit_code=$?
[[ ${exit_code} -eq 0 || ${exit_code} -eq 1 ]] && test_pass "Exit code is 0 or 1 (got ${exit_code})" || test_fail "Expected exit code 0 or 1 (got ${exit_code})"

# LOCATION PARSING

test_start "Providing a location"
location="whatever location"
output=$(mock_curl success "${SCRIPT_PATH}" "${location}" 2>&1)
exit_code=$?
assert_contains "${output}" "Fetching coordinates for: ${location}" "Should try fetching the coordinates of the provided location"
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_exit_code "${exit_code}" 0

# API SUCCESS SCENARIOS

test_start "Having GFZ/Hp30 success"
output=$(mock_curl success "${SCRIPT_PATH}" --GFZ "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "AURORA VISIBILITY FORECAST" "Should contain the title"
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_contains "${output}" "Stockholm" "Should contain the target location"
assert_contains "${output}" "GFZ Hp30"
assert_exit_code "${exit_code}" 0

test_start "Having NOAA/Kp success"
output=$(mock_curl success "${SCRIPT_PATH}" --NOAA "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "AURORA VISIBILITY FORECAST" "Should contain the title"
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_contains "${output}" "Stockholm" "Should contain the target location"
assert_contains "${output}" "NOAA Kp"
assert_exit_code "${exit_code}" 0


test_start "Having NOAA/Kp with historical data"
output=$(mock_curl success "${SCRIPT_PATH}" --NOAA --hist "Stockholm" 2>&1)
exit_code=$?
assert_contains "${output}" "AURORA VISIBILITY FORECAST" "Should contain the title"
assert_contains "${output}" "${CURRENT_DATE}" "Should contain the current date"
assert_contains "${output}" "Stockholm" "Should contain the target location"
assert_contains "${output}" "━━━━━ PRESENT ━━━━━" ""Should contain the temporal divider
assert_contains "${output}" "NOAA Kp"
assert_exit_code "${exit_code}" 0

# RAW OUTPUT

test_start "Having raw output format with matching results"
output=$(mock_curl success "${SCRIPT_PATH}" --raw "Stockholm" 2>&1)
exit_code=$?
assert_not_contains "${output}" "→ " "Should not contain info logs"
assert_not_contains "${output}" "AURORA VISIBILITY FORECAST" "Should not contain the title"
assert_not_contains "${output}" "Location:" "Should not contain location label"
assert_not_contains "${output}" "Coordinates:" "Should not contain coordinates label"
assert_not_contains "${output}" "Data Source:" "Should not contain data source label"
assert_not_contains "${output}" "Estimate:" "Should not contain estimate label"
assert_not_contains "${output}" "Magnitude:" "Should not contain magnitude label"
assert_not_contains "${output}" "Forecast Time:" "Should not contain forecast time label"
assert_not_contains "${output}" "Time_(UTC)" "Should not contain time table header"
assert_not_contains "${output}" "Hp30" "Should not contain Hp30 index table header"
assert_not_contains "${output}" "Kp" "Should not contain Kp index table header"
assert_not_contains "${output}" "Min_Lat" "Should not contain min latitude table header"
assert_not_contains "${output}" "Probability" "Should not contain probability table header"
assert_not_contains "${output}" "Outlook" "Should not contain outlook table header"
assert_not_contains "${output}" "%" "Should not contain percentage sign"
assert_not_contains "${output}" "≥" "Should not contain greater than or equal sign"
assert_contains "${output}" $'\t' "Should contain tab separators"
assert_exit_code "${exit_code}" 0

test_start "Having raw output format without matching results"
output=$(mock_curl success "${SCRIPT_PATH}" --raw -m 10 "Stockholm" 2>&1)
exit_code=$?
assert_not_contains "${output}" "→ " "Should not contain info logs"
assert_not_contains "${output}" "AURORA VISIBILITY FORECAST" "Should not contain the title"
assert_not_contains "${output}" "Location:" "Should not contain location label"
assert_not_contains "${output}" "Coordinates:" "Should not contain coordinates label"
assert_not_contains "${output}" "Data Source:" "Should not contain data source label"
assert_not_contains "${output}" "Estimate:" "Should not contain estimate label"
assert_not_contains "${output}" "Magnitude:" "Should not contain magnitude label"
assert_not_contains "${output}" "Forecast Time:" "Should not contain forecast time label"
assert_not_contains "${output}" "Time_(UTC)" "Should not contain time table header"
assert_not_contains "${output}" "Hp30" "Should not contain Hp30 index table header"
assert_not_contains "${output}" "Kp" "Should not contain Kp index table header"
assert_not_contains "${output}" "Min_Lat" "Should not contain min latitude table header"
assert_not_contains "${output}" "Probability" "Should not contain probability table header"
assert_not_contains "${output}" "Outlook" "Should not contain outlook table header"
assert_not_contains "${output}" "%" "Should not contain percentage sign"
assert_not_contains "${output}" "≥" "Should not contain greater than or equal sign"
assert_matches "${output}" ""
assert_exit_code "${exit_code}" 1

# PRINT SUMMARY

print_summary
