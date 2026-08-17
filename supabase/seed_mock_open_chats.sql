-- モックデータを open_chat_rooms テーブルに登録するSQLスクリプト
-- ※ 本番環境の Supabase SQLエディターに貼り付けて実行（RUN）してください。

DO $$
DECLARE
  v_owner_id uuid;
BEGIN
  -- owner_id に設定するユーザーを1名取得します
  SELECT id INTO v_owner_id FROM public.users LIMIT 1;
  
  -- もしユーザーが存在しない場合はエラーにして処理を停止します
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'ユーザーが存在しません。先にアプリ側でアカウント登録（またはログイン）を済ませてください。';
  END IF;

  -- モックデータを一括で登録します
  INSERT INTO public.open_chat_rooms (
    name, 
    description, 
    icon_url, 
    background_url, 
    owner_id, 
    password, 
    created_at, 
    member_count
  ) VALUES 
  ('サッカースパイク好き集まれ！', 'サッカースパイクを愛している人一緒に語りましょう！\nノート見て！宣伝❌\n#サッカー #スパイク', 'https://picsum.photos/seed/soccer_icon1/150/150', 'https://picsum.photos/seed/soccer_bg1/800/400', v_owner_id, NULL, NOW() - INTERVAL '10 days', 445),
  ('海外サッカー・プレミアリーグ観戦', '週末の試合について熱く語り合いましょう！', 'https://picsum.photos/seed/soccer_icon2/150/150', 'https://picsum.photos/seed/soccer_bg2/800/400', v_owner_id, NULL, NOW() - INTERVAL '30 days', 120),
  ('Jリーグサポーターズ', '応援しているクラブの情報交換や試合実況など！', 'https://picsum.photos/seed/jleague_icon/150/150', 'https://picsum.photos/seed/jleague_bg/800/400', v_owner_id, NULL, NOW() - INTERVAL '5 days', 305),
  ('秘密の会議室 (合言葉あり)', '合言葉を知っている人のみ参加できるテストルームです。合言葉は「1234」です。', 'https://picsum.photos/seed/secret_icon/150/150', 'https://picsum.photos/seed/secret_bg/800/400', v_owner_id, '1234', NOW() - INTERVAL '2 days', 12),
  ('ランニング・マラソン部', '日々のランニング記録やおすすめのシューズについて。', 'https://picsum.photos/seed/run_icon/150/150', 'https://picsum.photos/seed/run_bg/800/400', v_owner_id, NULL, NOW() - INTERVAL '100 days', 89),
  ('写真・カメラ愛好会', '撮った写真をシェアしたり機材について相談しましょう。', 'https://picsum.photos/seed/camera_icon/150/150', 'https://picsum.photos/seed/camera_bg/800/400', v_owner_id, NULL, NOW() - INTERVAL '200 days', 512),
  ('キャンプ・アウトドア情報', 'おすすめのキャンプ場やギアの紹介！', 'https://picsum.photos/seed/camp_icon/150/150', 'https://picsum.photos/seed/camp_bg/800/400', v_owner_id, NULL, NOW() - INTERVAL '40 days', 230),
  ('カフェ巡り・スイーツ好き', '美味しいカフェの情報を共有しましょう！', 'https://picsum.photos/seed/cafe_icon/150/150', 'https://picsum.photos/seed/cafe_bg/800/400', v_owner_id, NULL, NOW() - INTERVAL '15 days', 890),
  ('eスポーツ・FPSプレイヤー', 'ゲーム友達募集や大会の話題など。', 'https://picsum.photos/seed/game_icon/150/150', 'https://picsum.photos/seed/game_bg/800/400', v_owner_id, NULL, NOW() - INTERVAL '3 days', 156),
  ('読書記録・おすすめ本', '最近読んだ本やおすすめの小説を語る部屋です。', 'https://picsum.photos/seed/book_icon/150/150', 'https://picsum.photos/seed/book_bg/800/400', v_owner_id, NULL, NOW() - INTERVAL '60 days', 342);

  RAISE NOTICE 'モックデータの登録が完了しました！';
END $$;
