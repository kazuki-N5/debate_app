import psycopg2

conn = psycopg2.connect(
    host='192.168.11.52',
    port=54322,
    user='postgres',
    password='postgres',
    dbname='postgres'
)

with conn.cursor() as cur:
    user_id = '360c3260-98b0-4b60-891b-7af2b231f653'
    cur.execute("SELECT id, player1_id, player2_id, winner, created_at, updated_at FROM rooms_v2 WHERE (player1_id = %s OR player2_id = %s) AND winner IS NULL;", (user_id, user_id))
    rooms = cur.fetchall()
    print("Unfinished rooms:", rooms)
