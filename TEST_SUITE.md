# Aurora CLI - Test Suite

## Running Tests

```bash
./test.sh
```

## Test Structure

The test suite uses a simple bash-based testing framework with assertions and runs entirely with mocked API responses.

## Test Framework

### `assert_contains(output, criteria, [description])`
- Checks if output contains expected text

### `assert_not_contains(output, criteria, [description])`
- Checks if output does not contain text

### `assert_matches(actual, expected, [description])`
- Checks if actual output matches an expected output

### `assert_exit_code(actual, expected, [description])`
- Verifies command exit code

## Adding Tests

1. Create a test section or add to existing
2. Use test_start() to name the test
3. Execute command and capture output/exit code
4. Make assertions about the results

Example:
```bash
test_start "Description"
output=$("${SCRIPT_PATH}" [args] 2>&1)
exit_code=$?
assert_contains "${output}" "expected text"
assert_not_contains "${output}" "unexpected text"
assert_matches "${actual_output}" "expected output"
assert_exit_code "${exit_code}" [expected] 
```

## Exit Codes

See [EXIT_CODES.md](EXIT_CODES.md) for the complete exit code reference.
