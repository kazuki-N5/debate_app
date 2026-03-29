import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";
import { UserRecord } from "./types.ts";
import serviceAccount from "../service-account.json" with { type: "json" };

/**
 * FCM送信および通知関連のビジネスロジックを管理するクラス (ViewModel/Service役割)
 */
export class NotificationService {
  private supabase: SupabaseClient;

  constructor() {
    this.supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
  }

  /**
   * Google Authを使用してFCMのアクセストークンを取得
   */
  private getAccessToken(): Promise<string> {
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
        resolve(tokens!.access_token!);
      });
    });
  }

  /**
   * 通知の連投制限をチェック (60秒間間隔を空ける)
   */
  async handleRateLimit(
    userId: string,
  ): Promise<{ skipped: boolean; message?: string }> {
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
        console.log(
          `Rate limit: user ${userId} sent last notification ${diffSeconds}s ago. Skipping.`,
        );
        return { skipped: true, message: "Skipped: Rate limited (60s rule)." };
      }
    }

    // 制限をクリアしたのでログを記録
    const { error: logInsertError } = await this.supabase
      .from("notification_logs")
      .insert([{ user_id: userId }]);

    if (logInsertError) {
      console.error("Failed to insert log:", logInsertError);
    }

    return { skipped: false };
  }

  /**
   * 通知を全対象ユーザーに送信
   */
  async sendMatchWaitingNotification(
    roomId: string,
    hostUserId: string,
  ): Promise<{ successCount: number; targetCount: number }> {
    // 送信先ユーザーを取得 (自分以外、通知有効、FCMトークンあり)
    const { data: targetUsers, error: usersError } = await this.supabase
      .from("users")
      .select("id, fcm_token")
      .neq("id", hostUserId)
      .eq("is_notification_enabled", true)
      .not("fcm_token", "is", null);
    if (usersError) throw usersError;

    if (!targetUsers || targetUsers.length === 0) {
      return { successCount: 0, targetCount: 0 };
    }

    // アクセストークン取得
    const accessToken = await this.getAccessToken();

    // FCMトークンの重複排除
    const uniqueTokens = new Set<string>();
    const uniqueTargetUsers = (targetUsers as UserRecord[]).filter((u) => {
      if (!u.fcm_token || uniqueTokens.has(u.fcm_token)) {
        return false;
      }
      uniqueTokens.add(u.fcm_token);
      return true;
    });

    // FCM送信
    const fcmPromises = uniqueTargetUsers.map(async (user) => {
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
                token: user.fcm_token,
                notification: {
                  title: "ディベート相手を探しています！",
                  body: "対戦待ちをしている人がいます。今すぐ参加しましょう！",
                },
                // iOS用の音・バイブレーション設定
                apns: {
                  payload: {
                    aps: {
                      sound: "default",
                    },
                  },
                },
                // Android用のポップアップ通知（Heads-up）設定
                android: {
                  priority: "high",
                  notification: {
                    channel_id: "high_importance_channel_v4",
                  },
                },
                data: {
                  roomId: roomId,
                  type: "match_waiting",
                },
              },
            }),
          },
        );
        const resData = await res.json();
        if (res.status >= 400) {
          console.error(`FCM error for ${user.id}:`, resData);
          return false;
        }
        return true;
      } catch (e) {
        console.error(`Failed to send to ${user.id}:`, e);
        return false;
      }
    });

    const results = await Promise.all(fcmPromises);
    const successCount = results.filter(Boolean).length;

    return { successCount, targetCount: targetUsers.length };
  }
}
