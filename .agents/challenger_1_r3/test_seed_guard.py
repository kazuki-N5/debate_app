# Test harness for Section 2.6 Seed Guard logic
# Simulating PostgreSQL boolean & NULL logic in PL/pgSQL

def evaluate_seed_guard(app_environment_val):
    """
    Simulates PL/pgSQL:
    DO $$
    BEGIN
      IF current_setting('app.environment', true) IN ('production', 'prod', 'staging') THEN
        RAISE EXCEPTION 'CRITICAL: seed.sql execution blocked in non-local environment!';
      END IF;
    END $$;
    """
    # current_setting('app.environment', true) returns app_environment_val (which may be None)
    setting = app_environment_val
    
    # SQL IN operator with NULL handling:
    # If setting is None: NULL IN ('production', 'prod', 'staging') -> NULL (treated as False in IF)
    if setting is None:
        in_result = False
    else:
        in_result = setting in ('production', 'prod', 'staging')
    
    if in_result:
        return "BLOCKED (EXCEPTION RAISED)"
    else:
        return "PASSED (EXECUTED)"

def run_tests():
    test_cases = [
        ("production", "BLOCKED (EXCEPTION RAISED)"),
        ("prod", "BLOCKED (EXCEPTION RAISED)"),
        ("staging", "BLOCKED (EXCEPTION RAISED)"),
        ("local", "PASSED (EXECUTED)"),
        (None, "PASSED (EXECUTED)"),  # Unset / NULL
        ("", "PASSED (EXECUTED)"),    # Empty string
        ("dev", "PASSED (EXECUTED)"),
        ("development", "PASSED (EXECUTED)"),
        ("Production", "PASSED (EXECUTED)"), # Case sensitivity check
    ]
    
    print("=== Section 2.6 Seed Guard Test Results ===")
    all_passed = True
    for env_val, expected in test_cases:
        actual = evaluate_seed_guard(env_val)
        passed = (actual == expected)
        print(f"app.environment = {repr(env_val):15s} | Expected: {expected:25s} | Actual: {actual:25s} | Result: {'PASS' if passed else 'FAIL'}")
        if not passed:
            all_passed = False
            
    return all_passed

if __name__ == "__main__":
    run_tests()
