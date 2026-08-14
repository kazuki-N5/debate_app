import sqlite3

conn = sqlite3.connect(':memory:')
cursor = conn.cursor()

# Create profiles table
cursor.execute('''
CREATE TABLE profiles (
    id TEXT PRIMARY KEY,
    old_username TEXT,
    new_display_name TEXT
)
''')

# Create BEFORE UPDATE trigger mimicking the guide's logic
cursor.execute('''
CREATE TRIGGER sync_profiles_update
BEFORE UPDATE ON profiles
FOR EACH ROW
BEGIN
    UPDATE profiles
    SET new_display_name = NEW.old_username
    WHERE id = NEW.id
      AND NEW.new_display_name IS NULL
      AND NEW.old_username IS NOT NULL;
      
    UPDATE profiles
    SET old_username = NEW.new_display_name
    WHERE id = NEW.id
      AND NEW.old_username IS NULL
      AND NEW.new_display_name IS NOT NULL;
END;
''')

# Insert initial record (Phase 1/2 state)
cursor.execute("INSERT INTO profiles (id, old_username, new_display_name) VALUES ('1', 'alice', 'alice')")
conn.commit()

print("Initial row:", cursor.execute("SELECT * FROM profiles").fetchone())

# Old App updates old_username to 'alice_updated'
cursor.execute("UPDATE profiles SET old_username = 'alice_updated' WHERE id = '1'")
conn.commit()

row = cursor.execute("SELECT * FROM profiles").fetchone()
print("After Old App update:", row)
if row[1] != row[2]:
    print("BUG CONFIRMED: Dual-write out of sync! old_username=", row[1], "new_display_name=", row[2])
