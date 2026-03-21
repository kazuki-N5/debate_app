-- realtime.messages テーブルの RLS を有効化し、誰でも読み書きできるようにする
ALTER TABLE "realtime"."messages" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all to select" ON "realtime"."messages";
DROP POLICY IF EXISTS "Allow all to insert" ON "realtime"."messages";

CREATE POLICY "Allow all to select" ON "realtime"."messages" FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow all to insert" ON "realtime"."messages" FOR INSERT TO anon, authenticated WITH CHECK (true);
