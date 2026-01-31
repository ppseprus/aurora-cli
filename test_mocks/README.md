# Test Mocks

This directory contains mock data and a mock `curl` script for testing aurora.sh API interactions.

## Mock curl Script

**`curl`** - Mock implementation of `curl` that returns test data based on URL patterns and the `AURORA_TEST_SCENARIO` environment variable.

## Mock Data Files

### Geocoding (Nominatim API)
- **nominatim_stockholm.json** - Stockholm coordinates
- **nominatim_empty.json** - Empty result (location not found)

### Geomagnetic Index Data
- **gfz_hp30.csv** - GFZ Hp30 forecast data
- **gfz_empty.csv** - Empty GFZ response
- **gfz_malformed.csv** - Malformed GFZ response
- **noaa_kp.json** - NOAA Kp-index forecast data
- **noaa_invalid.json** - Invalid NOAA response

## Test Scenarios

Set `AURORA_TEST_SCENARIO` environment variable to one of the scenarios below:

| Scenario | Geocode API | GFZ API | NOAA API | Description |
|----------|-------------|---------|----------|-------------|
| `geocode_api_network_error` | `curl` exit 6, *no payload* |  HTTP 200 |  HTTP 200 | Simulate network error for geocoding API |
| `geocode_api_timeout` | `curl` exit 28, *no payload* |  HTTP 200 |  HTTP 200 | Simulate `curl` timeout for geocoding API |
| `geocode_api_rate_limit` | HTTP 429, *no payload* |  HTTP 200 |  HTTP 200 | Simulate rate limit for geocoding API |
| `geocode_api_fail` | HTTP 503, *no payload* |  HTTP 200 |  HTTP 200 | Geocoding service unavailable |
| `index_api_network_error` |  HTTP 200 | `curl` exit 6, *no payload* | `curl` exit 6, *no payload* | Simulate network error for index APIs |
| `index_api_timeout` |  HTTP 200 | `curl` exit 28, *no payload* | `curl` exit 28, *no payload* | Simulate `curl` timeout for index APIs |
| `index_api_rate_limit` |  HTTP 200 | HTTP 429 | HTTP 429 | Simulate rate limit for index APIs |
| `index_api_fail` |  HTTP 200 | HTTP 503 | HTTP 503 | Index APIs unavailable |
| `location_not_found` |  HTTP 200, empty |  HTTP 200 |  HTTP 200 | Location not found |
| `gfz_empty` |  HTTP 200 |  HTTP 200, empty | n/a | Empty GFZ response |
| `gfz_malformed` |  HTTP 200 |  HTTP 200, malformed | n/a | Malformed GFZ CSV data |
| `noaa_invalid` |  HTTP 200 | n/a |  HTTP 200, invalid | Invalid NOAA JSON response |
| `success` |  HTTP 200 |  HTTP 200 |  HTTP 200 | All APIs return valid data (default) |

## Usage

The `test_api.sh` script automatically sets up `PATH` to use the mock `curl`.
