import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";
import serviceAccount from "./service-account.json" with {
  type: "json"
};

interface NotificationSettings {
  is_notification_enabled?: boolean;
  match_waiting_enabled?: boolean;
}

interface TargetUser {
  id: string;
  fcm_token: string | null;
  notification_settings?: NotificationSettings[];
}

/**
 * FCM送信および通知関連のビジネスロジックを管理するクラス (ViewModel/Service役割)
 */
export class NotificationService {
  supabase: SupabaseClient;

  constructor() {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    this.supabase = createClient(supabaseUrl, supabaseServiceKey);
  }

  /**
   * Google Authを使用してFCMのアクセストークンを取得
   */
  getAccessToken(): Promise<string> {
    return new Promise((resolve, reject) => {
      const privateKey = serviceAccount.private_key.replace(/\\n/g, "\n");
      const jwtClient = new JWT({
        email: serviceAccount.client_email,
        key: privateKey,
        scopes: [
          "https://www.googleapis.com/auth/firebase.messaging"
        ]
      });
      jwtClient.authorize((err, tokens) => {
        if (err) {
          reject(err);
          return;
        }
        if (tokens?.access_token) {
          resolve(tokens.access_token);
        } else {
          reject(new Error("No access token returned"));
        }
      });
    });
  }

  /**
   * 通知の連投制限をチェック (60秒間間隔を空ける)
   */
  async handleRateLimit(userId: string): Promise<{ skipped: boolean; message?: string }> {
    const { data: lastLog, error: logFetchError } = await this.supabase
      .from("notification_logs")
      .select("created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(1);

    if (logFetchError) {
      console.error("Error fetching logs:", logFetchError);
    } else if (lastLog && lastLog.length > 0) {
      const now = new Date();
      const lastTime = new Date(lastLog[0].created_at);
      const diffSeconds = (now.getTime() - lastTime.getTime()) / 1000;
      if (diffSeconds < 60) {
        console.log(`Rate limit: user ${userId} sent last notification ${diffSeconds}s ago. Skipping.`);
        return {
          skipped: true,
          message: "Skipped: Rate limited (60s rule)."
        };
      }
    }

    // 制限をクリアしたのでログを記録
    const { error: logInsertError } = await this.supabase
      .from("notification_logs")
      .insert([{ user_id: userId }]);
    if (logInsertError) {
      console.error("Failed to insert log:", logInsertError);
    }
    return {
      skipped: false
    };
  }

  /**
   * 通知を全対象ユーザーに送信
   */
  async sendMatchWaitingNotification(roomId: string, hostUserId: string): Promise<{ successCount: number; targetCount: number }> {
    // 送信先ユーザーを取得 (自分以外、FCMトークンあり。マスター+カテゴリは下のフィルタで判定)
    const { data: targetUsers, error: usersError } = await this.supabase
      .from("users")
      .select("id, fcm_token, notification_settings(is_notification_enabled, match_waiting_enabled)")
      .neq("id", hostUserId)
      .not("fcm_token", "is", null);

    if (usersError) throw usersError;
    if (!targetUsers || targetUsers.length === 0) {
      return {
        successCount: 0,
        targetCount: 0
      };
    }

    // アクセストークン取得
    const accessToken = await this.getAccessToken();

    // FCMトークンの重複排除 (マスターOFF・カテゴリ設定OFFのユーザーは除外)
    const uniqueTokens = new Set<string>();
    const uniqueTargetUsers = (targetUsers as unknown as TargetUser[]).filter((u) => {
      if (!u.fcm_token || u.fcm_token.trim() === "") {
        return false;
      }
      const s = u.notification_settings?.[0];
      if (s?.is_notification_enabled === false) {
        return false;
      }
      if (s?.match_waiting_enabled === false) {
        return false;
      }
      if (uniqueTokens.has(u.fcm_token)) {
        return false;
      }
      uniqueTokens.add(u.fcm_token);
      return true;
    });

    // FCM送信
    const fcmPromises = uniqueTargetUsers.map(async (user) => {
      try {
        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`
          },
          body: JSON.stringify({
            message: {
              token: user.fcm_token,
              notification: {
                title: "ディベート相手を探しています！",
                body: "対戦待ちをしている人がいます。今すぐ参加しましょう！"
              },
              // iOS用の音・バイブレーション設定
              apns: {
                payload: {
                  aps: {
                    sound: "default"
                  }
                }
              },
              // Android用のポップアップ通知（Heads-up）設定
              android: {
                priority: "high",
                notification: {
                  channel_id: "high_importance_channel_v4"
                }
              },
              data: {
                roomId: roomId,
                type: "match_waiting"
              }
            }
          })
        });

        if (!res.ok) {
          const resData = await res.json().catch(() => ({}));
          console.error(`FCM error for ${user.id}:`, resData);

          // UNREGISTERED (アンインストール済み) や INVALID_ARGUMENT (無効トークン) の場合はDBのトークンをnullに更新
          const errorCode = resData?.error?.details?.[0]?.errorCode;
          const status = resData?.error?.status;
          if (
            res.status === 404 ||
            status === "NOT_FOUND" ||
            errorCode === "UNREGISTERED" ||
            errorCode === "INVALID_ARGUMENT" ||
            res.status === 400
          ) {
            console.log(`Clearing invalid FCM token for user ${user.id}`);
            await this.supabase.from("users").update({ fcm_token: null }).eq("id", user.id);
          }
          return false;
        }
        return true;
      } catch (e: unknown) {
        const errorMsg = e instanceof Error ? e.message : String(e);
        console.error(`Failed to send to ${user.id}:`, errorMsg);
        return false;
      }
    });

    const results = await Promise.all(fcmPromises);
    const successCount = results.filter(Boolean).length;
    return {
      successCount,
      targetCount: uniqueTargetUsers.length
    };
  }
}
