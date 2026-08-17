/**
 * Edge Function: notify_trigger
 * いいね / フォロー / 返信 / DM / オプチャ のプッシュ通知(FCM)を送信する
 *
 * DBトリガー (sql/message_tab.sql) から net.http_post で呼ばれる想定。
 *
 * リクエスト例:
 *   個別通知  : { "type": "like_post", "user_id": "受信者UUID", "actor_name": "アクター名" }
 *   DM通知    : { "type": "dm", "room_id": "ルームUUID", "sender_id": "送信者UUID" }
 *   オプチャ通知: { "type": "open_chat", "room_id": "ルームUUID", "sender_id": "送信者UUID" }
 */
import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";
import serviceAccount from "./service-account.json" with { type: "json" };

Deno.serve(async (req) => {
  try {
    // シークレットチェック (NOTIFY_SECRET を設定した場合のみ必須)
    const secret = Deno.env.get("NOTIFY_SECRET");
    if (secret && req.headers.get("x-notify-secret") !== secret) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    const body = await req.json();
    const { type } = body;

    // ルーム型通知 (DM / オプチャ): 受信者をDBから特定して送信
    if (type === "dm" || type === "open_chat") {
      const result = await sendRoomNotification(body);
      return new Response(JSON.stringify(result), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // 個別通知 (いいね/フォロー/返信)
    const { user_id, actor_name } = body;
    if (!user_id || !type) {
      return new Response(
        JSON.stringify({ error: "user_id and type are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL"),
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    );

    // 受信者のFCMトークンを取得 (通知ONかつトークン保有者のみ)
    const { data: user, error: userError } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", user_id)
      .eq("is_notification_enabled", true)
      .not("fcm_token", "is", null)
      .maybeSingle();
    if (userError) throw userError;
    if (!user?.fcm_token) {
      return new Response(
        JSON.stringify({ message: "No target (disabled or no token)." }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    const { title, body: messageBody } = buildMessage(type, actor_name ?? "誰か");
    const accessToken = await getAccessToken();
    const sent = await sendFcm(
      accessToken,
      user.fcm_token,
      title,
      messageBody,
      type
    );

    return new Response(
      JSON.stringify({ message: "Success", title, body: messageBody, sent }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Function error:", err.message);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }
});

/**
 * ルーム型通知 (DM / オプチャ) を送信する
 * - DM: ルームの他メンバー1人に送信
 * - オプチャ: 参加者全員(送信者以外)に送信
 */
async function sendRoomNotification({ type, room_id, sender_id }) {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL"),
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  );

  // 送信者名を取得
  const { data: sender } = await supabase
    .from("users")
    .select("name")
    .eq("id", sender_id)
    .maybeSingle();
  const actorName = sender?.name ?? "誰か";

  let receiverIds = [];
  let title = "";
  let messageBody = "";

  if (type === "dm") {
    // 受信者 = ルームの他メンバー
    const { data: members } = await supabase
      .from("dm_room_members")
      .select("user_id")
      .eq("room_id", room_id);
    receiverIds = (members ?? [])
      .map((m) => m.user_id)
      .filter((uid) => uid !== sender_id);

    // このルームのメッセージ件数 (1件なら初回)
    const { count } = await supabase
      .from("dm_messages")
      .select("id", { count: "exact", head: true })
      .eq("room_id", room_id);
    // 最新メッセージ本文
    const { data: lastMsg } = await supabase
      .from("dm_messages")
      .select("content")
      .eq("room_id", room_id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    title = "DMが届きました";
    if (count === 1) {
      // その人から初めてのDM → 本文は出さない
      messageBody = `${actorName} さんから通知が来ました`;
    } else {
      messageBody = `${actorName} さん: ${truncate(lastMsg?.content ?? "")}`;
    }
  } else {
    // オプチャ: ルーム名・参加者・最新メッセージを取得
    const { data: room } = await supabase
      .from("open_chat_rooms")
      .select("name")
      .eq("id", room_id)
      .maybeSingle();
    const { data: members } = await supabase
      .from("open_chat_members")
      .select("user_id")
      .eq("room_id", room_id);
    const { data: lastMsg } = await supabase
      .from("open_chat_messages")
      .select("content")
      .eq("room_id", room_id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    receiverIds = (members ?? [])
      .map((m) => m.user_id)
      .filter((uid) => uid !== sender_id);
    title = room?.name ?? "オープンチャット";
    messageBody = `${actorName} さん: ${truncate(lastMsg?.content ?? "")}`;
  }

  if (receiverIds.length === 0) {
    return { message: "No targets." };
  }

  // 受信者のFCMトークンを一括取得 (通知ONかつトークン保有者のみ)
  const { data: targetUsers, error: usersError } = await supabase
    .from("users")
    .select("id, fcm_token")
    .in("id", receiverIds)
    .eq("is_notification_enabled", true)
    .not("fcm_token", "is", null);
  if (usersError) throw usersError;
  if (!targetUsers || targetUsers.length === 0) {
    return { message: "No targets (disabled or no token)." };
  }

  const accessToken = await getAccessToken();

  // FCMトークンの重複排除して送信
  const uniqueTokens = new Set();
  let successCount = 0;
  for (const user of targetUsers) {
    if (!user.fcm_token || uniqueTokens.has(user.fcm_token)) continue;
    uniqueTokens.add(user.fcm_token);
    const sent = await sendFcm(accessToken, user.fcm_token, title, messageBody, type);
    if (sent) successCount++;
  }

  return {
    message: "Success",
    title,
    body: messageBody,
    counts: { success: successCount, total: uniqueTokens.size },
  };
}

/** 通知種別に応じたタイトル・本文 (個別通知用) */
function buildMessage(type, actorName) {
  switch (type) {
    case "like_post":
      return {
        title: "いいねされました",
        body: `${actorName} さんがあなたのポストにいいねしました`,
      };
    case "like_comment":
      return {
        title: "いいねされました",
        body: `${actorName} さんがあなたのコメントにいいねしました`,
      };
    case "follow":
      return {
        title: "フォローされました",
        body: `${actorName} さんがあなたをフォローしました`,
      };
    case "reply_comment":
      return {
        title: "返信が来ました",
        body: `${actorName} さんがあなたのコメントに返信しました`,
      };
    default:
      return { title: "新しい通知", body: actorName };
  }
}

/** FCM へ1件送信する (成功なら true) */
async function sendFcm(accessToken, fcmToken, title, body, type) {
  try {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: { title, body },
            // iOS: 音あり
            apns: { payload: { aps: { sound: "default" } } },
            // Android: ポップアップ(Heads-up)表示
            android: {
              priority: "high",
              notification: { channel_id: "high_importance_channel_v4" },
            },
            data: { type },
          },
        }),
      }
    );
    if (!res.ok) {
      console.error("FCM send failed:", await res.text());
      return false;
    }
    return true;
  } catch (e) {
    console.error("FCM send error:", e.message);
    return false;
  }
}

/** 本文を最大 length 文字に切り詰める */
function truncate(text, length = 30) {
  if (!text) return "";
  return text.length > length ? text.substring(0, length) + "…" : text;
}

/** Google Auth を使用して FCM のアクセストークンを取得 */
function getAccessToken() {
  return new Promise((resolve, reject) => {
    // private_key の改行エスケープを正規化 (JSONによって \n が残るケースへの防御)
    const privateKey = serviceAccount.private_key.replace(/\\n/g, "\n");
    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: privateKey,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    jwtClient.authorize((err, tokens) => {
      if (err) {
        reject(err);
        return;
      }
      resolve(tokens.access_token);
    });
  });
}
