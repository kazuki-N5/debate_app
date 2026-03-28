import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { JWT } from 'npm:google-auth-library@9';
import { UserRecord } from './types.ts';
import serviceAccount from '../service-account.json' with { type: 'json' };

/**
 * FCM送信および通知関連のビジネスロジックを管理するクラス (ViewModel/Service役割)
 * push_notification_v2 (テスト用シンプル版)
 */
export class NotificationService {
  private supabase: SupabaseClient;

  // ここに通知を送る対象のユーザーIDを列挙してください。
  private readonly TARGET_IDS = [
    'USER_ID_1',
    'USER_ID_2',
  ];

  constructor() {
    this.supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
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
        scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
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
   * テスト用に指定された全対象ユーザーに通知を送信
   */
  async sendTestNotification(): Promise<{ successCount: number; targetCount: number }> {
    // 指定したIDのユーザーを取得
    const { data: targetUsers, error: usersError } = await this.supabase
      .from('users')
      .select('id, fcm_token')
      .in('id', this.TARGET_IDS) // 特定のIDに限定
      .not('fcm_token', 'is', null);

    if (usersError) throw usersError;

    if (!targetUsers || targetUsers.length === 0) {
      console.log("No valid users found for the specified IDs.");
      return { successCount: 0, targetCount: 0 };
    }

    // アクセストークン取得
    const accessToken = await this.getAccessToken();

    // FCM送信
    const fcmPromises = (targetUsers as UserRecord[]).map(async (user) => {
      try {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: user.fcm_token,
                notification: {
                  title: 'ディベート相手を探しています！',
                  body: '対戦待ちをしている人がいます。今すぐ参加しましょう！',
                },
                // iOS用の音・バイブレーション設定
                apns: {
                  payload: {
                    aps: {
                      sound: "default",
                    },
                  },
                },
                data: {
                  roomId: 'test_room', // 引数がないため固定値またはダミー
                  type: 'match_waiting',
                },
              },
            }),
          }
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
