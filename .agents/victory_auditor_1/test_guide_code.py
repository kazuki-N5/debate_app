import sys
import re
import yaml

def test_yaml_files():
    guide_path = r"C:\Users\kazuk\program\AppList\debata\.agents\SUPABASE_LOCAL_DEV_GUIDE.md"
    with open(guide_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Extract YAML code blocks
    yaml_blocks = re.findall(r"```yaml\n(.*?)```", content, re.DOTALL)
    print(f"Found {len(yaml_blocks)} YAML code blocks.")
    for idx, block in enumerate(yaml_blocks, 1):
        try:
            parsed = yaml.safe_load(block)
            print(f"  YAML block {idx}: Valid YAML (keys: {list(parsed.keys())})")
        except Exception as e:
            print(f"  YAML block {idx}: ERROR - {e}")
            return False
    return True

def test_sql_trigger_logic():
    # Simulate Postgres trigger logic in Python
    def sync_profiles_display_name(old_record, new_record):
        # NEW record copy
        NEW = dict(new_record)
        OLD = dict(old_record) if old_record else {'old_username': None, 'new_display_name': None}
        
        old_username_changed = NEW.get('old_username') != OLD.get('old_username')
        new_display_name_changed = NEW.get('new_display_name') != OLD.get('new_display_name')

        if new_display_name_changed and NEW.get('new_display_name') is not None:
            NEW['old_username'] = NEW['new_display_name']
        elif old_username_changed and NEW.get('old_username') is not None:
            NEW['new_display_name'] = NEW['old_username']
        elif NEW.get('new_display_name') is None and NEW.get('old_username') is not None:
            NEW['new_display_name'] = NEW['old_username']
            
        return NEW

    # Test 1: Insert with new_display_name
    rec = sync_profiles_display_name(None, {'old_username': None, 'new_display_name': 'Alice'})
    assert rec['old_username'] == 'Alice', f"Test 1 failed: {rec}"

    # Test 2: Insert with old_username
    rec = sync_profiles_display_name(None, {'old_username': 'Bob', 'new_display_name': None})
    assert rec['new_display_name'] == 'Bob', f"Test 2 failed: {rec}"

    # Test 3: Update new_display_name
    old_rec = {'old_username': 'Alice', 'new_display_name': 'Alice'}
    new_rec = {'old_username': 'Alice', 'new_display_name': 'Alice_Updated'}
    rec = sync_profiles_display_name(old_rec, new_rec)
    assert rec['old_username'] == 'Alice_Updated', f"Test 3 failed: {rec}"

    # Test 4: Update old_username
    old_rec = {'old_username': 'Bob', 'new_display_name': 'Bob'}
    new_rec = {'old_username': 'Bob_Updated', 'new_display_name': 'Bob'}
    rec = sync_profiles_display_name(old_rec, new_rec)
    assert rec['new_display_name'] == 'Bob_Updated', f"Test 4 failed: {rec}"

    print("SQL Trigger Logic simulation tests: PASSED")
    return True

if __name__ == "__main__":
    y_ok = test_yaml_files()
    s_ok = test_sql_trigger_logic()
    if y_ok and s_ok:
        print("ALL INDEPENDENT CODE TESTS PASSED")
        sys.exit(0)
    else:
        print("SOME TESTS FAILED")
        sys.exit(1)
