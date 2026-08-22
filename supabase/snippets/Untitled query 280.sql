-- ============================================================
-- Migration: remove_old_bbs_room_flow
-- 対戦募集をレスバ(募集型)に統一したため、旧「rooms_v2 募集ルーム」システムを削除する
--
-- 削除対象:
--  1. 旧RPC 6本(create/apply/approve/cancel/delete/get の bbs_room 系)
--  2. rooms_v2.challenger_id カラム(旧フロー専用)
--
-- 残すもの:
--  - rooms_v2.is_bbs       : v2_process_game_result のトロフィー判定 + レスババトル作成で使用
--  - rooms_v2.password     : フレンド対戦(join_room_v2)で使用
--  - is_user_blocked ほか  : レスバ/モデレーション機能で使用
-- ============================================================

-- ---------- 1. 旧RPCの削除 ----------
DROP FUNCTION IF EXISTS public.create_bbs_room(uuid, text, text, text, text);
DROP FUNCTION IF EXISTS public.apply_bbs_room(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.approve_bbs_room(uuid, uuid, boolean);
DROP FUNCTION IF EXISTS public.cancel_bbs_application(uuid);
DROP FUNCTION IF EXISTS public.delete_bbs_room(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_bbs_rooms();

-- ---------- 2. rooms_v2.challenger_id の削除 ----------
-- (残っていた旧応募状態をクリアしてから削除)
UPDATE public.rooms_v2 SET challenger_id = NULL WHERE challenger_id IS NOT NULL;
ALTER TABLE public.rooms_v2 DROP COLUMN IF EXISTS challenger_id;
