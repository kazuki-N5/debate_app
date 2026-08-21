-- ============================================================
-- rooms_v2 の結果（winner / reason / scores）二重上書き防止トリガー
-- ============================================================

-- すでに winner が確定している部屋に対して、後から winner, reason, scores が上書きされるのを完全に防ぐ
CREATE OR REPLACE FUNCTION public.prevent_room_result_overwrite()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  -- すでに winner が NULL でない（確定済み・キャンセル済み・降参済み）場合
  IF OLD.winner IS NOT NULL THEN
    -- winner, reason, scores は元の値を維持（後からの上書きを無視）
    NEW.winner := OLD.winner;
    NEW.reason := OLD.reason;
    NEW.scores := OLD.scores;
  END IF;

  RETURN NEW;
END;
$function$;

-- 既存の同名トリガーがあれば削除して再作成
DROP TRIGGER IF EXISTS trg_prevent_room_result_overwrite ON public.rooms_v2;

CREATE TRIGGER trg_prevent_room_result_overwrite
  BEFORE UPDATE OF winner, reason, scores ON public.rooms_v2
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_room_result_overwrite();
