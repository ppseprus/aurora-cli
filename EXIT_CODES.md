# Aurora CLI - Exit Codes

Aurora CLI uses a structured exit code system following Unix conventions. Exit codes are grouped by category to help identify the nature of success or failure.

## Exit Code Groups

**Success (0-1):** Normal operation outcomes  
**System/Environment (10-11):** Shell compatibility and dependency issues  
**User Input (20-23):** Invalid arguments and incompatible options  
**Network/API (30-34):** Connection failures, timeouts, and service issues  
**Data Processing (40-42):** Data validation and parsing problems  
**Internal (99):** Unexpected or unhandled errors

## Exit Code Reference

| Code | Name | Example |
|------|------|---------|
| 0 | Success with results | Forecast data retrieved and displayed |
| 1 | Success without results | No forecast entries match filter criteria (e.g., `--magnitude 7` when all values below 7) |
| 10 | Incompatible shell | Script run with non-bash shell or bash < 3.2 |
| 11 | Missing dependency | Dependency is missing (e.g., `jq` command not found on system) |
| 20 | Invalid argument syntax | Unknown option flag, missing value for option requiring argument |
| 21 | Missing required argument | Location not provided |
| 22 | Invalid argument value | Hours not 1-72, magnitude < 0, invalid estimate value, multiple locations specified |
| 23 | Incompatible options | `--hist` with GFZ source, `--estimate` with NOAA source |
| 30 | Network connectivity | Cannot reach API, general HTTP errors |
| 31 | API timeout | Request exceeded 30-second timeout |
| 32 | API unavailable | Service returns 5xx HTTP status codes |
| 33 | API rate limit | Too many requests (HTTP 429), Nominatim limit: 1 req/sec |
| 34 | Geocoding failure | Location string not found by OpenStreetMap |
| 40 | Data validation error | NOAA JSON response invalid or missing expected structure |
| 41 | Empty API response | GFZ API returned empty response |
| 42 | Data parsing error | GFZ CSV to JSON conversion failed |
| 99 | Unhandled error | Unexpected condition not covered by specific error codes |
