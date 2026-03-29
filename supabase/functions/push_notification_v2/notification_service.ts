import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { JWT } from 'npm:google-auth-library@9';
import serviceAccount from '../service-account.json' with { type: 'json' };

/**
 * FCM送信および通知関連のビジネスロジックを管理するクラス (ViewModel/Service役割)
 * push_notification_v2 (テスト用シンプル版)
 */
export class NotificationService {
  private supabase: SupabaseClient;

  // テスト送信先のFCMトークンをここに直接記述します（指示により追加）
  private readonly TARGET_TOKENS = [
    'cWJG3DvkNEyKhV1c7wbktr:APA91bGuzIUvqxvjMw_HRF_HXqDzO7zgaX4qceXfNytG-se1whzqIa-DNn63fOcpawvcir3aPJoWShGgFW7DHu13Zi4uwSUYtIJ137vB8YKvdyBMFJfYM0w',
    'f3XnUQmlTO-4PfMt23m_AL:APA91bFncbvBL4XgQN_Fx5nB7t-1VHMiMdbc9nQZpQJf0QxlsKg6k2eRkUv0rPidqdhGXuc-C0PmPMKCpyIvJPTG6s6W7931wsoE1i0QlMcVPH1u_J0URa0',
    'eTgkZQJ7Q_6LAbnZ8Dd0v9:APA91bG46Ork5K-JXWss4DcqwTj5357doCEA_540I11drKdonTCJZdfEocVvlPFJW9ct1Y4Ap8aer_18jVy9buXz6s9lWug-ja4C3Y5sXe2N_sd_ycPkmlA'
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
   * テスト用に指定された全対象トークンに通知を送信
   */
  async sendTestNotification(): Promise<{ successCount: number; targetCount: number }> {
    // アクセストークン取得
    const accessToken = await this.getAccessToken();

    // FCM送信
    const fcmPromises = this.TARGET_TOKENS.map(async (token) => {
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
                token: token,
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
                // Android用のポップアップ通知（Heads-up）設定
                android: {
                  priority: 'high',
                  notification: {
                    channel_id: 'high_importance_channel_v4',
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
          console.error(`FCM error for token:`, resData);
          return false;
        }
        return true;
      } catch (e) {
        console.error(`Failed to send to token:`, e);
        return false;
      }
    });

    const results = await Promise.all(fcmPromises);
    const successCount = results.filter(Boolean).length;

    return { successCount, targetCount: this.TARGET_TOKENS.length };
  }
}
