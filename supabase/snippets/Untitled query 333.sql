-- pg_net 拡張機能が有効であることを確認
CREATE EXTENSION IF NOT EXISTS pg_net;

-- QStash 予約用関数の作成
CREATE OR REPLACE FUNCTION public.schedule_gemini_with_qstash()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  qstash_token text := 'eyJVc2VySUQiOiJhYzQ3YjI2Yi03MTg4LTQ4ZjUtYTIwMS00ZGE2MTQ0ZmEwZDAiLCJQYXNzd29yZCI6IjJlYjA4YzRlZjg2YjRkNjI5YTg4ODhkYjFmNzU2OTczIn0=';
  target_url text := 'https://undebilitative-engagedly-salma.ngrok-free.dev/functions/v1/gemini';
  qstash_publish_url text := 'https://qstash-us-east-1.upstash.io/v2/publish/' || target_url;
BEGIN
  -- 変更点: お互いの選択が完了（NULLではない）し、かつ被らなかった（選択が異なる）場合
  IF (NEW.player1_choice IS NOT NULL AND NEW.player2_choice IS NOT NULL AND NEW.player1_choice != NEW.player2_choice) 
     -- 以前の状態は「どちらかがNULLだった」か「被っていた」場合（重複して発火するのを防ぐため）
     AND (OLD.player1_choice IS NULL OR OLD.player2_choice IS NULL OR OLD.player1_choice = OLD.player2_choice) THEN
    PERFORM net.http_post(
      url := qstash_publish_url,
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || qstash_token,
        'Content-Type', 'application/json',
        -- 変更点: 10秒後に設定
        'Upstash-Delay', '10s'
      ),
      body := jsonb_build_object(
        'room_id', NEW.id,
        'theme', NEW.current_theme,
        'player1_choice', NEW.current_choice1,
        'player2_choice', NEW.current_choice2
      )::text
    );
    RAISE NOTICE 'QStash timer scheduled for room_id: %', NEW.id;
  END IF;
  RETURN NEW;
END;
$$;


-- トリガーを rooms テーブルに設定
DROP TRIGGER IF EXISTS tr_schedule_gemini ON public.rooms;
CREATE TRIGGER tr_schedule_gemini
  -- 変更点: 監視するカラムを player1_choice, player2_choice に変更
  AFTER UPDATE OF player1_choice, player2_choice ON public.rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.schedule_gemini_with_qstash();
