/**
 * Edge Function: notify_trigger
 * いいね / フォロー / 返信 / DM / オプチャ / レスバ招待 のプッシュ通知(FCM)を送信する
 *
 * DBトリガーから net.http_post で呼ばれる。
 */
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";
import serviceAccount from "./service-account.json" with { type: "json" };

interface RequestBody {
  type: string;
  user_id?: string;
  actor_name?: string;
  room_id?: string;
  sender_id?: string;
  invite_id?: string;
}

interface NotificationSettings {
  is_notification_enabled?: boolean;
  like_enabled?: boolean;
  comment_enabled?: boolean;
  follow_enabled?: boolean;
  dm_enabled?: boolean;
  open_chat_enabled?: boolean;
  match_waiting_enabled?: boolean;
}

Deno.serve(async (req: Request) => {
  try {
    // シークレットチェック (NOTIFY_SECRET を設定した場合のみ必須)
    const secret = Deno.env.get("NOTIFY_SECRET");
    if (secret && req.headers.get("x-notify-secret") !== secret) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    const body: RequestBody = await req.json();
    const { type } = body;

    // ルーム型通知 (DM / オプチャ): 受信者をDBから特定して送信
    if (type === "dm" || type === "open_chat") {
      const result = await sendRoomNotification(body);
      return new Response(JSON.stringify(result), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // 個別通知 (いいね/フォロー/返信/レスバ)
    const { user_id, actor_name, invite_id } = body;
    if (!user_id || !type) {
      return new Response(
        JSON.stringify({ error: "user_id and type are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 受信者のFCMトークンを取得 (トークン保有者のみ)
    const { data: user, error: userError } = await supabase
      .from("users")
      .select("fcm_token, notification_settings(is_notification_enabled, like_enabled, comment_enabled, follow_enabled, dm_enabled, open_chat_enabled, match_waiting_enabled)")
      .eq("id", user_id)
      .not("fcm_token", "is", null)
      .maybeSingle();
    if (userError) throw userError;
    if (!user?.fcm_token || (user.fcm_token as string).trim() === "") {
      return new Response(
        JSON.stringify({ message: "No target (disabled or no token)." }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // マスター + カテゴリ別設定チェック (プッシュ通知の細かいON/OFF。設定行がなければON扱い)
    const settingsList = user.notification_settings as unknown as NotificationSettings[] | null;
    const settings = settingsList?.[0];
    if (!isPushEnabled(type, settings)) {
      return new Response(
        JSON.stringify({ message: "No target (notification disabled)." }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    const { title, body: messageBody } = buildMessage(type, actor_name ?? "誰か");
    const accessToken = await getAccessToken();
    const sent = await sendFcm(
      supabase,
      user_id,
      accessToken,
      user.fcm_token,
      title,
      messageBody,
      type,
      invite_id
    );

    return new Response(
      JSON.stringify({ message: "Success", title, body: messageBody, sent }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    console.error("Function error:", errorMsg);
    return new Response(
      JSON.stringify({ error: errorMsg }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }
});

/**
 * ルーム型通知 (DM / オプチャ) を送信する
 */
async function sendRoomNotification({ type, room_id, sender_id }: RequestBody) {
  if (!room_id || !sender_id) {
    return { message: "room_id and sender_id are required" };
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  // 送信者名を取得
  const { data: sender } = await supabase
    .from("users")
    .select("name")
    .eq("id", sender_id)
    .maybeSingle();
  const actorName = sender?.name ?? "誰か";

  let receiverIds: string[] = [];
  let title = "";
  let messageBody = "";

  if (type === "dm") {
    const { data: members } = await supabase
      .from("dm_room_members")
      .select("user_id")
      .eq("room_id", room_id)
      .or("is_muted.is.null,is_muted.eq.false");
    receiverIds = (members ?? [])
      .map((m: { user_id: string }) => m.user_id)
      .filter((uid: string) => uid !== sender_id);

    const { count } = await supabase
      .from("dm_messages")
      .select("id", { count: "exact", head: true })
      .eq("room_id", room_id);

    const { data: lastMsg } = await supabase
      .from("dm_messages")
      .select("content")
      .eq("room_id", room_id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    title = "DMが届きました";
    if (count === 1) {
      messageBody = `${actorName} さんから通知が来ました`;
    } else {
      messageBody = `${actorName} さん: ${truncate(lastMsg?.content ?? "")}`;
    }
  } else {
    const { data: room } = await supabase
      .from("open_chat_rooms")
      .select("name")
      .eq("id", room_id)
      .maybeSingle();
    const { data: members } = await supabase
      .from("open_chat_members")
      .select("user_id")
      .eq("room_id", room_id)
      .or("is_muted.is.null,is_muted.eq.false");
    const { data: lastMsg } = await supabase
      .from("open_chat_messages")
      .select("content")
      .eq("room_id", room_id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    receiverIds = (members ?? [])
      .map((m: { user_id: string }) => m.user_id)
      .filter((uid: string) => uid !== sender_id);
    title = room?.name ?? "オープンチャット";
    messageBody = `${actorName} さん: ${truncate(lastMsg?.content ?? "")}`;
  }

  if (receiverIds.length === 0) {
    return { message: "No targets." };
  }

  // ★ 送信者をブロックしている受信者(ブロックした人の視界からだけ消す)はプッシュ対象から除外
  const blockedReceiverIds = await getBlockedReceiverIds(
    supabase,
    sender_id,
    receiverIds
  );
  receiverIds = receiverIds.filter((uid: string) => !blockedReceiverIds.has(uid));
  if (receiverIds.length === 0) {
    return { message: "No targets (blocked)." };
  }

  const { data: targetUsers, error: usersError } = await supabase
    .from("users")
    .select("id, fcm_token, notification_settings(is_notification_enabled, dm_enabled, open_chat_enabled)")
    .in("id", receiverIds)
    .not("fcm_token", "is", null);
  if (usersError) throw usersError;
  if (!targetUsers || targetUsers.length === 0) {
    return { message: "No targets (disabled or no token)." };
  }

  const filteredUsers = targetUsers.filter((u: { id: string; fcm_token: string | null; notification_settings?: NotificationSettings[] }) => {
    if (!u.fcm_token || u.fcm_token.trim() === "") return false;
    const settingsList = u.notification_settings as unknown as NotificationSettings[] | null;
    const s = settingsList?.[0];
    if (s?.is_notification_enabled === false) return false;
    if (type === "dm") return s?.dm_enabled !== false;
    return s?.open_chat_enabled !== false;
  });
  if (filteredUsers.length === 0) {
    return { message: "No targets (category disabled)." };
  }

  const accessToken = await getAccessToken();

  const uniqueTokens = new Set<string>();
  const sendTargets: { user: { id: string; fcm_token: string | null }; token: string }[] = [];

  for (const user of filteredUsers) {
    if (!user.fcm_token || uniqueTokens.has(user.fcm_token)) continue;
    uniqueTokens.add(user.fcm_token);
    sendTargets.push({ user, token: user.fcm_token });
  }

  // Promise.allSettled で全員へ並行して一斉送信
  const results = await Promise.allSettled(
    sendTargets.map(({ user, token }) =>
      sendFcm(supabase, user.id, accessToken, token, title, messageBody, type)
    )
  );

  const successCount = results.filter(
    (r) => r.status === "fulfilled" && r.value === true
  ).length;

  return {
    message: "Success",
    title,
    body: messageBody,
    counts: { success: successCount, total: uniqueTokens.size },
  };
}

/**
 * 送信者をブロックしている受信者IDを返す(ブロックした人の視界からだけ消す)
 */
async function getBlockedReceiverIds(
  supabase: SupabaseClient,
  senderId: string,
  receiverIds: string[]
): Promise<Set<string>> {
  const blocked = new Set<string>();
  if (!senderId || receiverIds.length === 0) return blocked;

  // 受信者が送信者をブロックしている
  const { data: receiverBlocks } = await supabase
    .from("brock_user")
    .select("user_id")
    .eq("block_user_id", senderId)
    .in("user_id", receiverIds);
  for (const r of receiverBlocks ?? []) {
    if (r.user_id) blocked.add(r.user_id as string);
  }

  return blocked;
}

function isPushEnabled(type: string, settings?: NotificationSettings): boolean {
  if (!settings) return true;
  if (settings.is_notification_enabled === false) return false;
  switch (type) {
    case "like_post":
    case "like_comment":
      return settings.like_enabled !== false;
    case "comment":
    case "reply_comment":
      return settings.comment_enabled !== false;
    case "follow":
      return settings.follow_enabled !== false;
    case "resba_invite":
      return settings.dm_enabled !== false || settings.match_waiting_enabled !== false;
    default:
      return true;
  }
}

function buildMessage(type: string, actorName: string): { title: string; body: string } {
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
    case "comment":
      return {
        title: "コメントが来ました",
        body: `${actorName} さんがあなたのポストにコメントしました`,
      };
    case "resba_invite":
      return {
        title: "レスバの対戦申し込みが届きました！",
        body: `${actorName} さんからレスバの対戦申し込みが届きました`,
      };
    case "resba_accepted":
      return {
        title: "レスバの申し込みが承諾されました！",
        body: `${actorName} さんが対戦申し込みを承諾しました`,
      };
    case "resba_declined":
      return {
        title: "レスバの申し込みが辞退されました",
        body: `${actorName} さんが対戦申し込みを辞退しました`,
      };
    default:
      return { title: "新しい通知", body: actorName };
  }
}

async function sendFcm(
  supabase: SupabaseClient,
  userId: string,
  accessToken: string,
  fcmToken: string,
  title: string,
  body: string,
  type: string,
  inviteId?: string
): Promise<boolean> {
  try {
    const fcmData: Record<string, string> = { type };
    if (inviteId) {
      fcmData.invite_id = inviteId;
    }

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
            apns: { payload: { aps: { sound: "default" } } },
            android: {
              priority: "high",
              notification: { channel_id: "high_importance_channel_v4" },
            },
            data: fcmData,
          },
        }),
      }
    );
    if (!res.ok) {
      const resData = await res.json().catch(() => ({}));
      console.error(`FCM send failed for user ${userId}:`, JSON.stringify(resData));

      const errorCode = resData?.error?.details?.[0]?.errorCode;
      const status = resData?.error?.status;
      if (
        res.status === 404 ||
        status === "NOT_FOUND" ||
        errorCode === "UNREGISTERED" ||
        errorCode === "INVALID_ARGUMENT" ||
        res.status === 400
      ) {
        console.log(`Clearing invalid FCM token for user ${userId}`);
        await supabase.from("users").update({ fcm_token: null }).eq("id", userId);
      }
      return false;
    }
    return true;
  } catch (e: unknown) {
    const errorMsg = e instanceof Error ? e.message : String(e);
    console.error(`FCM send error for user ${userId}:`, errorMsg);
    return false;
  }
}

function truncate(text: string, length = 30): string {
  if (!text) return "";
  return text.length > length ? text.substring(0, length) + "…" : text;
}

// Google OAuth アクセストークンのモジュールスコープキャッシュ（ウォームスタンバイ中に再利用）
let cachedAccessToken: string | null = null;
let tokenExpiresAt = 0; // UNIXミリ秒

function getAccessToken(): Promise<string> {
  const now = Date.now();
  // 有効期限内（余裕を見て5分前の55分間）であればキャッシュトークンを即返却
  if (cachedAccessToken && now < tokenExpiresAt - 5 * 60 * 1000) {
    return Promise.resolve(cachedAccessToken);
  }

  return new Promise((resolve, reject) => {
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
      if (tokens?.access_token) {
        cachedAccessToken = tokens.access_token;
        // 有効期限を設定（デフォルト1時間 = 3600秒）
        tokenExpiresAt = Date.now() + 3600 * 1000;
        resolve(tokens.access_token);
      } else {
        reject(new Error("No access token returned"));
      }
    });
  });
}
