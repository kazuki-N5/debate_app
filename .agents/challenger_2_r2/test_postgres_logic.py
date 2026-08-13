def plpgsql_sync_trigger_current(TG_OP, OLD, NEW):
    # Current code from SUPABASE_LOCAL_DEV_GUIDE.md
    if NEW['new_display_name'] is None and NEW['old_username'] is not None:
        NEW['new_display_name'] = NEW['old_username']
    elif NEW['old_username'] is None and NEW['new_display_name'] is not None:
        NEW['old_username'] = NEW['new_display_name']
    return NEW

def plpgsql_sync_trigger_fixed(TG_OP, OLD, NEW):
    # Corrected code for PostgreSQL dual-write trigger
    if TG_OP == 'INSERT':
        if NEW['new_display_name'] is None and NEW['old_username'] is not None:
            NEW['new_display_name'] = NEW['old_username']
        elif NEW['old_username'] is None and NEW['new_display_name'] is not None:
            NEW['old_username'] = NEW['new_display_name']
    elif TG_OP == 'UPDATE':
        old_user_changed = NEW['old_username'] != OLD['old_username']
        new_disp_changed = NEW['new_display_name'] != OLD['new_display_name']
        if old_user_changed and not new_disp_changed:
            NEW['new_display_name'] = NEW['old_username']
        elif new_disp_changed and not old_user_changed:
            NEW['old_username'] = NEW['new_display_name']
    return NEW

# Test 1: Old app updates old_username on an existing row where both columns are populated
OLD = {'id': '1', 'old_username': 'alice', 'new_display_name': 'alice'}
NEW_from_old_app = {'id': '1', 'old_username': 'alice_updated', 'new_display_name': 'alice'} # Postgres retains OLD.new_display_name

result_current = plpgsql_sync_trigger_current('UPDATE', OLD, dict(NEW_from_old_app))
result_fixed = plpgsql_sync_trigger_fixed('UPDATE', OLD, dict(NEW_from_old_app))

print("=== TEST 1: Old App UPDATE ===")
print("Current trigger output:", result_current)
print("Fixed trigger output:  ", result_fixed)
assert result_current['new_display_name'] == 'alice', "Current trigger failed to update new_display_name"
assert result_fixed['new_display_name'] == 'alice_updated', "Fixed trigger successfully updated new_display_name"

# Test 2: New app updates new_display_name on an existing row
NEW_from_new_app = {'id': '1', 'old_username': 'alice', 'new_display_name': 'bob_new'}
result_current_2 = plpgsql_sync_trigger_current('UPDATE', OLD, dict(NEW_from_new_app))
result_fixed_2 = plpgsql_sync_trigger_fixed('UPDATE', OLD, dict(NEW_from_new_app))

print("\n=== TEST 2: New App UPDATE ===")
print("Current trigger output:", result_current_2)
print("Fixed trigger output:  ", result_fixed_2)
assert result_current_2['old_username'] == 'alice', "Current trigger failed to update old_username"
assert result_fixed_2['old_username'] == 'bob_new', "Fixed trigger successfully updated old_username"

print("\nALL EMPIRICAL TESTS PASSED FOR BUG DEMONSTRATION & FIX VERIFICATION")
