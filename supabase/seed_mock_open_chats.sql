-- モックデータを open_chat_rooms テーブルに登録するSQLスクリプト
-- ※ 本番環境の Supabase SQLエディターに貼り付けて実行（RUN）してください。
-- ※ 2026-09-01: owner_id 廃止対応。作成者は open_chat_members に role='owner' で登録されます。

DO $$
DECLARE
  v_owner_id uuid;
  v_room_id uuid;
BEGIN
  -- オーナーに設定するユーザーを1名取得します
  SELECT id INTO v_owner_id FROM public.users LIMIT 1;
  
  -- もしユーザーが存在しない場合はエラーにして処理を停止します
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'ユーザーが存在しません。先にアプリ側でアカウント登録（またはログイン）を済ませてください。';
  END IF;

  -- ============ ルーム 1: サッカースパイク好き集まれ！ ============
  INSERT INTO public.open_chat_rooms (name, description, icon_url, background_url, password, created_at, member_count)
  VALUES ('サッカースパイク好き集まれ！', 'サッカースパイクを愛している人一緒に語りましょう！\nノート見て！宣伝❌\n#サッカー #スパイク', 'https://picsum.photos/seed/soccer_icon1/150/150', 'https://picsum.photos/seed/soccer_bg1/800/400', NULL, NOW() - INTERVAL '10 days', 445)
  RETURNING id INTO v_room_id;
  INSERT INTO public.open_chat_members (room_id, user_id, role) VALUES (v_room_id, v_owner_id, 'owner');

  -- ============ ルーム 2: 海外サッカー・プレミアリーグ観戦 ============
  INSERT INTO public.open_chat_rooms (name, description, icon_url, background_url, password, created_at, member_count)
  VALUES ('海外サッカー・プレミアリーグ観戦', '週末の試合について熱く語り合いましょう！', 'https://picsum.photos/seed/soccer_icon2/150/150', 'https://picsum.photos/seed/soccer_bg2/800/400', NULL, NOW() - INTERVAL '30 days', 120)
  RETURNING id INTO v_room_id;
  INSERT INTO public.open_chat_members (room_id, user_id, role) VALUES (v_room_id, v_owner_id, 'owner');

  -- ============ ルーム 3: Jリーグサポーターズ ============
  INSERT INTO public.open_chat_rooms (name, description, icon_url, background_url, password, created_at, member_count)
  VALUES ('Jリーグサポーターズ', '応援しているクラブの情報交換や試合実況など！', 'https://picsum.photos/seed/jleague_icon/150/150', 'https://picsum.photos/seed/jleague_bg/800/400', NULL, NOW() - INTERVAL '5 days', 305)
  RETURNING id INTO v_room_id;
  INSERT INTO public.open_chat_members (room_id, user_id, role) VALUES (v_room_id, v_owner_id, 'owner');

  -- ============ ルーム 4: 秘密の会議室 (合言葉あり) ============
  INSERT INTO public.open_chat_rooms (name, description, icon_url, background_url, password, created_at, member_count)
  VALUES ('秘密の会議室 (合言葉あり)', '合言葉を知っている人のみ参加できるテストルームです。合言葉は「1234」です。', 'https://picsum.photos/seed/secret_icon/150/150', 'https://picsum.photos/seed/secret_bg/800/400', '1234', NOW() - INTERVAL '2 days', 12)
  RETURNING id INTO v_room_id;
  INSERT INTO public.open_chat_members (room_id, user_id, role) VALUES (v_room_id, v_owner_id, 'owner');

  -- ============ ルーム 5: ランニング・マラソン部 ============
  INSERT INTO public.open_chat_rooms (name, description, icon_url, background_url, password, created_at, member_count)
  VALUES ('ランニング・マラソン部', '日々のランニング記録やおすすめのシューズについて。', 'https://picsum.photos/seed/run_icon/150/150', 'https://picsum.photos/seed/run_bg/800/400', NULL, NOW() - INTERVAL '100 days', 89)
  RETURNING id INTO v_room_id;
  INSERT INTO public.open_chat_members (room_id, user_id, role) VALUES (v_room_id, v_owner_id, 'owner');

  -- ============ ルーム 6: 写真・カメラ愛好会 ============
  INSERT INTO public.open_chat_rooms (name, description, icon_url, background_url, password, created_at, member_count)
  VALUES ('写真・カメラ愛好会', '撮った写真をシェアしたり機材について相談しましょう。', 'https://picsum.photos/seed/camera_icon/150/150', 'https://picsum.photos/seed/camera_bg/800/400', NULL, NOW() - INTERVAL '200 days', 512)
  RETURNING id INTO v_room_id;
  INSERT INTO public.open_chat_members (room_id, user_id, role) VALUES (v_room_id, v_owner_id, 'owner');

  -- ============ ルーム 7: キャンプ・アウトドア情報 ============
  INSERT INTO public.open_chat_rooms (name, description, icon_url, background_url, password, created_at, member_count)
  VALUES ('キャンプ・アウトドア情報', 'おすすめのキャンプ場やギアの紹介！', 'https://picsum.photos/seed/camp_icon/150/150', 'https://picsum.photos/seed/camp_bg/800/400', NULL, NOW() - INTERVAL '40 days', 230)
  RETURNING id INTO v_room_id;
  INSERT INTO public.open_chat_members (room_id, user_id, role) VALUES (v_room_id, v_owner_id, 'owner');

  -- ============ ルーム 8: カフェ巡り・スイーツ好き ============
  INSERT INTO public.open_chat_rooms (name, description, icon_url, background_url, password, created_at, member_count)
  VALUES ('カフェ巡り・スイーツ好き', '美味しいカフェの情報を共有しましょう！', 'https://picsum.photos/seed/cafe_icon/150/150', 'https://picsum.photos/seed/cafe_bg/800/400', NULL, NOW() - INTERVAL '15 days', 890)
  RETURNING id INTO v_room_id;
  INSERT INTO public.open_chat_members (room_id, user_id, role) VALUES (v_room_id, v_owner_id, 'owner');

  -- ============ ルーム 9: eスポーツ・FPSプレイヤー ============
  INSERT INTO public.open_chat_rooms (name, description, icon_url, background_url, password, created_at, member_count)
  VALUES ('eスポーツ・FPSプレイヤー', 'ゲーム友達募集や大会の話題など。', 'https://picsum.photos/seed/game_icon/150/150', 'https://picsum.photos/seed/game_bg/800/400', NULL, NOW() - INTERVAL '3 days', 156)
  RETURNING id INTO v_room_id;
  INSERT INTO public.open_chat_members (room_id, user_id, role) VALUES (v_room_id, v_owner_id, 'owner');

  -- ============ ルーム 10: 読書記録・おすすめ本 ============
  INSERT INTO public.open_chat_rooms (name, description, icon_url, background_url, password, created_at, member_count)
  VALUES ('読書記録・おすすめ本', '最近読んだ本やおすすめの小説を語る部屋です。', 'https://picsum.photos/seed/book_icon/150/150', 'https://picsum.photos/seed/book_bg/800/400', NULL, NOW() - INTERVAL '60 days', 342)
  RETURNING id INTO v_room_id;
  INSERT INTO public.open_chat_members (room_id, user_id, role) VALUES (v_room_id, v_owner_id, 'owner');

  RAISE NOTICE 'モックデータの登録が完了しました！';
END $$;