import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  FunctionCallingMode,
  GoogleGenerativeAI,
  SchemaType,
} from "https://esm.sh/@google/generative-ai@0.21.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

// 1. CORS設定（Flutterアプリからの呼び出しに必須）
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  // CORS プレフライトリクエストの処理
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let room_id: string | null = null;

  try {
    console.log("Function triggered");

    // リクエスト解析
    const body = await req.json();
    const { room_id: req_room_id, theme, player1_choice, player2_choice } =
      body;
    room_id = req_room_id;

    if (!room_id) throw new Error("Missing room_id");

    // Supabase クライアント初期化
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // 2. 二重判定防止チェック
    const { data: room, error: roomError } = await supabase
      .from("rooms")
      .select("winner, reason, player1_id, player2_id")
      .eq("id", room_id)
      .single();

    if (roomError) {
      console.error("roomError details:", roomError);
      throw roomError;
    }

    // winner がすでに存在していれば終了（二重実行防止）
    if (room?.winner) {
      console.log(
        `Room ${room_id} already has a judgment: winner=${room?.winner}`,
      );
      return new Response(
        JSON.stringify({ success: true, message: "Judgment already exists." }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 3. メッセージ取得
    const { data: messages, error: mError } = await supabase
      .from("messages")
      .select("sender_id, content")
      .eq("room_id", room_id)
      .order("created_at", { ascending: true });

    if (mError) throw mError;

    const formattedChat = messages?.map((m) => {
      const label = m.sender_id === room.player1_id ? "A" : "B";
      return `${label}: ${m.content}`;
    }).join("\n");

    // 4. Gemini API 呼び出し
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) throw new Error("GEMINI_API_KEY is not defined");

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
      model: "gemini-2.5-flash",
      tools: [{
        functionDeclarations: [{
          name: "submit_debate_judgment",
          description:
            "ディベートの勝者を判定し、理由とともに結果を提出します。",
          parameters: {
            type: SchemaType.OBJECT,
            properties: {
              winner: { type: SchemaType.STRING, enum: ["A", "B"] },
              reason: { type: SchemaType.STRING },
            },
            required: ["winner", "reason"],
          },
        }],
      }],
      toolConfig: {
        functionCallingConfig: {
          mode: FunctionCallingMode.ANY,
          allowedFunctionNames: ["submit_debate_judgment"],
        },
      },
    });

    console.log("Calling Gemini for room:", room_id);
    const prompt =
      `テーマ: ${theme}\nAの立場: ${player1_choice}\nBの立場: ${player2_choice}\n\n[チャットログ]\n${formattedChat}`;

    // プロンプト文をそのままログに表示する
    console.log("==== Gemini Prompt ====");
    console.log(prompt);
    console.log("=======================");

    const result = await model.generateContent(prompt);
    const call = result.response.candidates?.[0]?.content?.parts?.[0]
      ?.functionCall;

    if (!call) throw new Error("AI did not return a function call judgment.");

    const { winner, reason } = call.args as { winner: string; reason: string };
    console.log(`AI judgment: winner=${winner}`);

    // 5. DB保存
    const { error: updateError } = await supabase
      .from("rooms")
      .update({ winner, reason })
      .eq("id", room_id);

    if (updateError) {
      // トリガーによる例外(P0001)は、並列リクエストが先に処理を終えただけなので成功扱いとする
      if (
        updateError.code === "P0001" ||
        updateError.message.includes("Judgment results cannot be updated")
      ) {
        console.log("Handled race condition on update.");
        return new Response(
          JSON.stringify({
            success: true,
            message: "Concurrent update handled.",
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
      throw updateError;
    }

    return new Response(JSON.stringify({ success: true, winner, reason }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    // Supabase由来のエラーか標準Errorかに関わらず生のエラー内容も出力する
    console.error("Critical Function Error Details:", err);
    console.error("Stringified Error:", JSON.stringify(err));

    const error = err instanceof Error ? err : new Error(String(err));

    // すでに他のリクエストで処理済み（レースコンディション）の場合は何もしない
    if (error.message.includes("Judgment results cannot be updated")) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "Handled by concurrent worker.",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 【追加】Geminiの応答失敗やその他のエラー時に "C: エラーが発生しました" をDBに記録
    if (room_id) {
      try {
        const supabase = createClient(
          Deno.env.get("SUPABASE_URL") ?? "",
          Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
        );
        console.log(`Recording failure state (C) for room: ${room_id}`);
        await supabase
          .from("rooms")
          .update({ winner: "C", reason: "エラーが発生しました" })
          .eq("id", room_id);
      } catch (dbErr) {
        console.error("Failed to record error state to DB:", dbErr);
        // ここでの失敗はさらに上位のcatchには回さずログのみ
      }
    }

    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
