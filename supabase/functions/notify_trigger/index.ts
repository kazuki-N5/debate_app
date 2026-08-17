/**
 * Edge Function: notify_trigger
 * いいね / フォロー / 返信 のプッシュ通知(FCM)を送信する
 *
 * DBトリガー (sql/message_tab.sql の notify_* 関数) から net.http_post で呼ばれる想定。
 * リクエスト例:
 *   { "user_id": "受信者のUUID", "type": "like_post", "actor_name": "アクター名" }
 */
import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";
import serviceAccount from "./service-account.json" with { type: "json" };

Deno.serve(async (req) => {
  try {
    // シークレットチェック (NOTIFY_SECRET を設定した場合のみ必須)
    // DBトリガーからの呼び出し以外を弾くための防御
    const secret = Deno.env.get("NOTIFY_SECRET");
    if (secret && req.headers.get("x-notify-secret") !== secret) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    const { user_id, type, actor_name } = await req.json();
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

    const { title, body } = buildMessage(type, actor_name ?? "誰か");

    // FCM アクセストークン取得 (Google OAuth2 JWT)
    const accessToken = await getAccessToken();

    // FCM 送信
    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: user.fcm_token,
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

    if (!fcmRes.ok) {
      const errText = await fcmRes.text();
      console.error("FCM send failed:", errText);
      return new Response(
        JSON.stringify({ error: "FCM send failed" }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ message: "Success", title, body }),
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

/** 通知種別に応じたタイトル・本文 */
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

/** Google Auth を使用して FCM のアクセストークンを取得 */
function getAccessToken() {
  return new Promise((resolve, reject) => {
    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
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
