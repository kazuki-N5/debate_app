import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import { JWT } from 'npm:google-auth-library@9';

// 公式ドキュメントの記載に従い、親フォルダにある service-account.json を読み込む
import serviceAccount from '../service-account.json' with { type: 'json' };

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

const getAccessToken = ({
  clientEmail,
  privateKey,
}: {
  clientEmail: string;
  privateKey: string;
}): Promise<string> => {
  return new Promise((resolve, reject) => {
    const jwtClient = new JWT({
      email: clientEmail,
      key: privateKey,
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
};

serve(async (req) => {
  try {
    const { room_id, user_id } = await req.json();
    console.log(`Notification requested from room_id: ${room_id}, by user: ${user_id}`);

    // --- 連投制限チェック (同一人物は30秒間間隔を空ける) ---
    const { data: lastLog, error: logFetchError } = await supabase
      .from('notification_logs')
      .select('created_at')
      .eq('user_id', user_id)
      .order('created_at', { ascending: false })
      .limit(10); // 直近10件ほど取得。最新1件だけでも良いが、安全のため。

    if (logFetchError) {
      console.error('Error fetching logs:', logFetchError);
      // ログ取得エラー時は、サービス継続のため制限をスルーする（またはエラーにするか検討）
    } else if (lastLog && lastLog.length > 0) {
      const now = new Date();
      const lastTime = new Date(lastLog[0].created_at);
      const diffSeconds = (now.getTime() - lastTime.getTime()) / 1000;

      if (diffSeconds < 60) {
        console.log(`Rate limit: user ${user_id} sent last notification ${diffSeconds}s ago. Skipping.`);
        return new Response(JSON.stringify({ message: 'Skipped: Rate limited (30s rule).' }), {
          headers: { 'Content-Type': 'application/json' },
        });
      }
    }

    // 制限をクリアしたのでログを記録
    const { error: logInsertError } = await supabase
      .from('notification_logs')
      .insert([{ user_id }]);
    if (logInsertError) console.error('Failed to insert log:', logInsertError);
    // --------------------------------------------------

    // 通知発火者の情報を取得
    const { data: hostUser, error: hostError } = await supabase
      .from('users')
      .select('name')
      .eq('id', user_id)
      .single();
    if (hostError) throw hostError;
    const hostName = hostUser?.name || '誰か';

    // 送信先を取得 (自分以外の users 全員で fcm_token を持ち、かつ通知許可している者)
    const { data: targetUsers, error: usersError } = await supabase
      .from('users')
      .select('id, fcm_token')
      .neq('id', user_id)
      .eq('is_notification_enabled', true)
      .not('fcm_token', 'is', null);
    if (usersError) throw usersError;

    if (!targetUsers || targetUsers.length === 0) {
      return new Response(JSON.stringify({ message: 'No targets.' }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // FCMのアクセストークンを取得
    const accessToken = await getAccessToken({
      clientEmail: serviceAccount.client_email,
      privateKey: serviceAccount.private_key,
    });

    const fcmPromises = targetUsers.map(async (user) => {
      try {
        if (!user.fcm_token) return;

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
                  body: `${hostName} さんが対戦待ちをしています。今すぐ参加しましょう！`,
                },
                data: {
                  roomId: room_id,
                  type: 'match_waiting',
                },
              },
            }),
          }
        );
        const resData = await res.json();
        console.log(`Notification sent to ${user.id}:`, resData);
      } catch (e) {
        console.error(`Failed to send to ${user.id}:`, e);
      }
    });

    await Promise.all(fcmPromises);

    return new Response(JSON.stringify({ message: 'Success' }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    const errInfo = error as Error;
    console.error('Function error:', errInfo.message);
    return new Response(JSON.stringify({ error: errInfo.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});

