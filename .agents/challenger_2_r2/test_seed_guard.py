def check_seed_guard_current(db_name, app_env):
    # Current condition from SUPABASE_LOCAL_DEV_GUIDE.md:
    # IF current_database() NOT LIKE '%postgres%' AND current_setting('app.environment', true) IS DISTINCT FROM 'local' THEN
    
    cond1 = 'postgres' not in db_name # current_database() NOT LIKE '%postgres%'
    cond2 = app_env != 'local'        # app.environment IS DISTINCT FROM 'local'
    
    if cond1 and cond2:
        return "RAISE EXCEPTION (Blocked)"
    else:
        return "EXECUTE SEED (Allowed)"

def check_seed_guard_fixed(db_name, app_env):
    # Corrected environment safeguard logic
    # In Supabase Cloud prod, app.environment is 'production' or unset, NOT 'local'.
    # A safe check must fail-closed if app.environment is NOT 'local' (or check if connected to remote/prod host).
    # If app.environment setting is used:
    if app_env != 'local':
        return "RAISE EXCEPTION (Blocked)"
    return "EXECUTE SEED (Allowed)"

print("=== SCENARIO 1: Supabase Cloud Production DB (name: 'postgres', env: 'production') ===")
res_current_prod = check_seed_guard_current('postgres', 'production')
res_fixed_prod = check_seed_guard_fixed('postgres', 'production')
print("Current guard result:", res_current_prod)
print("Fixed guard result:  ", res_fixed_prod)

print("\n=== SCENARIO 2: Local Supabase Docker DB (name: 'postgres', env: 'local') ===")
res_current_local = check_seed_guard_current('postgres', 'local')
res_fixed_local = check_seed_guard_fixed('postgres', 'local')
print("Current guard result:", res_current_local)
print("Fixed guard result:  ", res_fixed_local)

assert res_current_prod == "RAISE EXCEPTION (Blocked)", "CRITICAL BUG: Current seed guard allowed seed execution on Production!"
