-- "avatars" バケット内のすべてのオブジェクト操作を許可するポリシー

-- 1. 読み取り（SELECT）: 全員に公開
CREATE POLICY "Allow Public Select" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'avatars');

-- 2. 挿入（INSERT）: 誰でもアップロード可能
CREATE POLICY "Allow Public Insert" ON storage.objects
FOR INSERT TO public
WITH CHECK (bucket_id = 'avatars');

-- 3. 更新（UPDATE）: 誰でも上書き可能
CREATE POLICY "Allow Public Update" ON storage.objects
FOR UPDATE TO public
USING (bucket_id = 'avatars');

-- 4. 削除（DELETE）: 誰でも削除可能
CREATE POLICY "Allow Public Delete" ON storage.objects
FOR DELETE TO public
USING (bucket_id = 'avatars');
