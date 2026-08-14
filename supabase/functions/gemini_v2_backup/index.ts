import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
// 1. CORS設定（Flutterアプリからの呼び出しに必須）
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};
Deno.serve(async (req)=>{
  // CORS プレフライトリクエストの処理
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  let room_id = null;
  try {
    console.log("Function triggered");
    // リクエスト解析
    const body = await req.json();
    const { room_id: req_room_id, theme, player1_choice, player2_choice } = body;
    room_id = req_room_id;
    if (!room_id) throw new Error("Missing room_id");
    // Supabase クライアント初期化
    const supabase = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
    // 2. 二重判定防止チェック
    const { data: room, error: roomError } = await supabase.from("rooms_v2").select("winner, reason, player1_id, player2_id").eq("id", room_id).single();
    if (roomError) {
      console.error("roomError details:", roomError);
      throw roomError;
    }
    // winner がすでに存在していれば終了（二重実行防止）
    if (room?.winner) {
      console.log(`Room ${room_id} already has a judgment: winner=${room?.winner}`);
      return new Response(JSON.stringify({
        success: true,
        message: "Judgment already exists."
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // 3. メッセージ取得
    const { data: messages, error: mError } = await supabase.from("messages").select("sender_id, content").eq("room_id", room_id).order("created_at", {
      ascending: true
    });
    if (mError) throw mError;
    const formattedChat = messages?.map((m)=>{
      const label = m.sender_id === room.player1_id ? "A" : "B";
      return `${label}: ${m.content}`;
    }).join("\n");
    // 4. DeepSeek API 呼び出し
    const apiKey = Deno.env.get("DEEPSEEK_API_KEY") || "sk-bd1aabc030804428acdc91a9f85b8507";
    if (!apiKey) throw new Error("DEEPSEEK_API_KEY is not defined");
    console.log("Calling DeepSeek API for room:", room_id);
    const userPrompt = `テーマ: ${theme}\nAの立場: ${player1_choice}\nBの立場: ${player2_choice}\n\n[チャットログ]\n${formattedChat}`;
    console.log("==== DeepSeek Prompt ====");
    console.log(userPrompt);
    console.log("=========================");
    const response = await fetch("https://api.deepseek.com/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        messages: [
          {
            role: "system",
            content: "あなたはディベートの厳正な審判です。議論の内容を論理的に評価し、勝利した立場(AまたはB)とその理由を判定してください。必ず以下のJSONフォーマット形式のみで返答してください。余計な文字列やマークダウン装飾(例: ```json)は一切含めないでください。\n\n{\"winner\": \"A\", \"reason\": \"勝敗の理由説明\"}"
          },
          {
            role: "user",
            content: userPrompt
          }
        ],
        response_format: {
          type: "json_object"
        },
        temperature: 0.3
      })
    });
    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`DeepSeek API Error (${response.status}): ${errText}`);
    }
    const resJson = await response.json();
    const content = resJson.choices?.[0]?.message?.content;
    if (!content) throw new Error("DeepSeek API returned empty content.");
    let winner = "C";
    let reason = "エラーが発生しました";
    try {
      const parsed = JSON.parse(content);
      winner = parsed.winner === "A" || parsed.winner === "B" ? parsed.winner : "A";
      reason = parsed.reason || "判定完了";
    } catch (_e) {
      console.error("Failed to parse DeepSeek JSON response:", content);
      throw new Error("JSON parse error from DeepSeek response");
    }
    console.log(`DeepSeek judgment: winner=${winner}`);
    // 5. DB保存
    const { error: updateError } = await supabase.from("rooms_v2").update({
      winner,
      reason
    }).eq("id", room_id);
    if (updateError) {
      // トリガーによる例外(P0001)は、並列リクエストが先に処理を終えただけなので成功扱いとする
      if (updateError.code === "P0001" || updateError.message.includes("Judgment results cannot be updated")) {
        console.log("Handled race condition on update.");
        return new Response(JSON.stringify({
          success: true,
          message: "Concurrent update handled."
        }), {
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          }
        });
      }
      throw updateError;
    }
    return new Response(JSON.stringify({
      success: true,
      winner,
      reason
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      },
      status: 200
    });
  } catch (err) {
    // Supabase由来のエラーか標準Errorかに関わらず生のエラー内容も出力する
    console.error("Critical Function Error Details:", err);
    console.error("Stringified Error:", JSON.stringify(err));
    const error = err instanceof Error ? err : new Error(String(err));
    // すでに他のリクエストで処理済み（レースコンディション）の場合は何もしない
    if (error.message.includes("Judgment results cannot be updated")) {
      return new Response(JSON.stringify({
        success: true,
        message: "Handled by concurrent worker."
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // 【追加】Geminiの応答失敗やその他のエラー時に "C: エラーが発生しました" をDBに記録
    if (room_id) {
      try {
        const supabase = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
        console.log(`Recording failure state (C) for room: ${room_id}`);
        await supabase.from("rooms_v2").update({
          winner: "C",
          reason: "エラーが発生しました"
        }).eq("id", room_id);
      } catch (dbErr) {
        console.error("Failed to record error state to DB:", dbErr);
      // ここでの失敗はさらに上位のcatchには回さずログのみ
      }
    }
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
