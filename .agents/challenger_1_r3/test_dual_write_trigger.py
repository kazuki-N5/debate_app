# Test harness for Section 3.6 Dual-Write Trigger Function
# Simulating PostgreSQL BEFORE INSERT OR UPDATE trigger sync_profiles_display_name()

class Row:
    def __init__(self, old_username=None, new_display_name=None):
        self.old_username = old_username
        self.new_display_name = new_display_name
        
    def copy(self):
        return Row(self.old_username, self.new_display_name)
        
    def __repr__(self):
        return f"Row(old_username={repr(self.old_username)}, new_display_name={repr(self.new_display_name)})"

def is_distinct_from(val1, val2):
    """Simulates SQL IS DISTINCT FROM"""
    return val1 != val2

def sync_profiles_display_name(OLD, NEW):
    """
    Simulates PL/pgSQL function:
    BEGIN
      IF NEW.new_display_name IS DISTINCT FROM OLD.new_display_name AND NEW.new_display_name IS NOT NULL THEN
        NEW.old_username := NEW.new_display_name;
      ELSIF NEW.old_username IS DISTINCT FROM OLD.old_username AND NEW.old_username IS NOT NULL THEN
        NEW.new_display_name := NEW.old_username;
      ELSIF NEW.new_display_name IS NULL AND NEW.old_username IS NOT NULL THEN
        NEW.new_display_name := NEW.old_username;
      END IF;
      RETURN NEW;
    END;
    """
    old_new_disp = OLD.new_display_name if OLD else None
    old_old_user = OLD.old_username if OLD else None

    # IF NEW.new_display_name IS DISTINCT FROM OLD.new_display_name AND NEW.new_display_name IS NOT NULL
    cond1 = is_distinct_from(NEW.new_display_name, old_new_disp) and (NEW.new_display_name is not None)
    
    # ELSIF NEW.old_username IS DISTINCT FROM OLD.old_username AND NEW.old_username IS NOT NULL
    cond2 = is_distinct_from(NEW.old_username, old_old_user) and (NEW.old_username is not None)
    
    # ELSIF NEW.new_display_name IS NULL AND NEW.old_username IS NOT NULL
    cond3 = (NEW.new_display_name is None) and (NEW.old_username is not None)
    
    if cond1:
        NEW.old_username = NEW.new_display_name
    elif cond2:
        NEW.new_display_name = NEW.old_username
    elif cond3:
        NEW.new_display_name = NEW.old_username
        
    return NEW

def run_tests():
    print("=== Section 3.6 Dual-Write Trigger Test Results ===")
    
    tests = []
    
    # --- INSERT TESTS (OLD is None) ---
    # Test 1: INSERT with new_display_name='Alice', old_username=None
    tests.append({
        'name': 'INSERT with new_display_name only',
        'OLD': None,
        'NEW': Row(old_username=None, new_display_name='Alice'),
        'expected_old': 'Alice',
        'expected_new': 'Alice'
    })
    
    # Test 2: INSERT with old_username='Bob', new_display_name=None
    tests.append({
        'name': 'INSERT with old_username only',
        'OLD': None,
        'NEW': Row(old_username='Bob', new_display_name=None),
        'expected_old': 'Bob',
        'expected_new': 'Bob'
    })
    
    # Test 3: INSERT with both null
    tests.append({
        'name': 'INSERT with both null',
        'OLD': None,
        'NEW': Row(old_username=None, new_display_name=None),
        'expected_old': None,
        'expected_new': None
    })

    # Test 4: INSERT with both set to same value 'Charlie'
    tests.append({
        'name': 'INSERT with both set to same value',
        'OLD': None,
        'NEW': Row(old_username='Charlie', new_display_name='Charlie'),
        'expected_old': 'Charlie',
        'expected_new': 'Charlie'
    })

    # --- UPDATE TESTS ---
    # Existing row: old_username='alice_v1', new_display_name='alice_v1'
    base_old = Row(old_username='alice_v1', new_display_name='alice_v1')
    
    # Test 5: UPDATE new_display_name to 'Alice_v2' (old_username unchanged in input)
    tests.append({
        'name': 'UPDATE new_display_name (new client write)',
        'OLD': base_old.copy(),
        'NEW': Row(old_username='alice_v1', new_display_name='Alice_v2'),
        'expected_old': 'Alice_v2',
        'expected_new': 'Alice_v2'
    })

    # Test 6: UPDATE old_username to 'Alice_v3' (new_display_name unchanged in input)
    tests.append({
        'name': 'UPDATE old_username (old client write)',
        'OLD': base_old.copy(),
        'NEW': Row(old_username='Alice_v3', new_display_name='alice_v1'),
        'expected_old': 'Alice_v3',
        'expected_new': 'Alice_v3'
    })

    # Test 7: UPDATE unrelated column (both old_username & new_display_name unchanged)
    tests.append({
        'name': 'UPDATE unrelated column (no change to username/display_name)',
        'OLD': base_old.copy(),
        'NEW': Row(old_username='alice_v1', new_display_name='alice_v1'),
        'expected_old': 'alice_v1',
        'expected_new': 'alice_v1'
    })

    # Test 8: UPDATE setting new_display_name to NULL while old_username is 'alice_v1'
    tests.append({
        'name': 'UPDATE setting new_display_name to NULL',
        'OLD': base_old.copy(),
        'NEW': Row(old_username='alice_v1', new_display_name=None),
        'expected_old': 'alice_v1',
        'expected_new': 'alice_v1'
    })

    all_passed = True
    for t in tests:
        old_row = t['OLD']
        new_row = t['NEW'].copy()
        result_row = sync_profiles_display_name(old_row, new_row)
        
        passed = (result_row.old_username == t['expected_old']) and (result_row.new_display_name == t['expected_new'])
        print(f"Test: {t['name']:55s} | Result: {'PASS' if passed else 'FAIL'}")
        if not passed:
            print(f"   Expected: old={t['expected_old']}, new={t['expected_new']}")
            print(f"   Got:      old={result_row.old_username}, new={result_row.new_display_name}")
            all_passed = False
            
    return all_passed

if __name__ == "__main__":
    run_tests()
