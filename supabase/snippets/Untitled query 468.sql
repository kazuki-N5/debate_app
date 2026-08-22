-- ============================================================
-- Migration: resba_spectate_replay
-- レスバの「リアルタイム観戦」と「終了後の観戦ログ閲覧」を支える基盤
--
-- 1. battle_invites に勝者・終了時刻をスナップショット（観戦ログ表示用）
--    winner_user_id / finished_at を追加し、バトル終了トリガーで記録する
-- 2. rooms_v2 の掃除（delete_old_rooms_with_result）で「レスバ発のバトル」を
--    削除対象から除外 → battle_room_id が SET NULL されず、
--    終了後も rooms_v2 + messages（対戦ログ）を閲覧できる
-- ============================================================

-- ---------- 1. battle_invites に勝者・終了時刻カラム追加 ----------
ALTER TABLE public.battle_invites
  ADD COLUMN winner_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN finished_at   timestamptz;

-- ---------- 2. バトル終了トリガーで勝者・終了時刻を記録 ----------
CREATE OR REPLACE FUNCTION public.finish_resba_on_battle_end()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  IF NEW.winner IS NOT NULL AND OLD.winner IS NULL THEN
    UPDATE battle_invites
       SET status = 'finished',
           winner_user_id = CASE
             WHEN NEW.winner = 'A' THEN NEW.player1_id
             WHEN NEW.winner = 'B' THEN NEW.player2_id
             ELSE NULL -- 引き分け（C）
           END,
           finished_at = now(),
           updated_at = now()
     WHERE battle_room_id = NEW.id AND status = 'accepted';
  END IF;
  RETURN NEW;
END;
$function$;

-- ---------- 3. rooms_v2 の掃除: レスバ発のバトルは削除対象から除外 ----------
-- レスバ（battle_invites.battle_room_id）に紐付くルームは
-- 「ポスト/返信に残る観戦ログ」の元データなので残す（1行あたり数百バイト）。
-- ランダムマッチ等のバトルは従来どおり winner 確定後 2 分で削除される。
CREATE OR REPLACE FUNCTION public.delete_old_rooms_with_result()
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  DELETE FROM public.rooms_v2 r
  WHERE
    r.winner IS NOT NULL
    AND r.updated_at <= now() - INTERVAL '2 minutes'
    AND NOT EXISTS (
      SELECT 1 FROM public.battle_invites b
      WHERE b.battle_room_id = r.id
    );
END;
$function$;

-- cron ジョブを再登録（jobname が既存なら更新される・冪等）
SELECT cron.schedule(
  'delete-old-rooms-v2',
  '*/5 * * * *',
  $$SELECT public.delete_old_rooms_with_result()$$
);
