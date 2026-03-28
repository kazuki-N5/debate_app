import { NotificationService } from './notification_service.ts';

/**
 * Supabase Edge Function: Notification Trigger
 * FCMでのプッシュ通知送信
 * 
 * MVVMのController(Entry Point)の役割を担います。
 */
Deno.serve(async (_req: Request) => {
  try {
    console.log(`Test notification requested.`);

    const service = new NotificationService();

    // 1. テスト通知送信処理 (ターゲットIDはサービス内で固定)
    const { successCount, targetCount } = await service.sendTestNotification();

    if (targetCount === 0) {
      return new Response(JSON.stringify({ message: "No targets found for the specified IDs." }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ 
      message: "Test Success",
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
