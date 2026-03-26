import { NotificationService } from './notification_service.ts';
import { NotificationRequest } from './types.ts';

/**
 * Supabase Edge Function: Notification Trigger
 * FCMでのプッシュ通知送信
 * 
 * MVVMのController(Entry Point)の役割を担います。
 */
Deno.serve(async (req: Request) => {
  try {
    const { room_id, user_id }: NotificationRequest = await req.json();
    console.log(`Notification requested from room_id: ${room_id}, by user: ${user_id}`);

    const service = new NotificationService();

    // 1. 連投制限チェック
    const rateLimit = await service.handleRateLimit(user_id);
    if (rateLimit.skipped) {
      return new Response(JSON.stringify({ message: rateLimit.message }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 2. 通知送信処理
    const { successCount, targetCount } = await service.sendMatchWaitingNotification(room_id, user_id);

    if (targetCount === 0) {
      return new Response(JSON.stringify({ message: "No targets." }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ 
      message: "Success",
      counts: { success: successCount, total: targetCount }
    }), {
      headers: { 'Content-Type': 'application/json' },
    });

  } catch (error) {
    const errInfo = error as Error;
    console.error("Function error:", errInfo.message);
    return new Response(JSON.stringify({ error: errInfo.message }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
});
