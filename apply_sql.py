import psycopg2
import sys

def apply():
    host = "192.168.11.52"
    port = "54322"
    user = "postgres"
    password = "postgres"
    dbname = "postgres"
    
    with open("supabase/migrations/20260821122537_fix_send_dm_resba_column.sql", "r", encoding="utf-8") as f:
        sql = f.read()
        
    try:
        conn = psycopg2.connect(
            host=host,
            port=port,
            user=user,
            password=password,
            dbname=dbname
        )
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute(sql)
            print("Successfully applied SQL")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    apply()
