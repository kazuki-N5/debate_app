import 'dart:developer';

import 'package:debate_project/provider/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final chatWithAiProvider = Provider<Chat_with_ai>((ref) {
  // Chat_with_aiのコンストラクタに、引数として`ref`を渡す
  return Chat_with_ai(ref);
});

class Chat_with_ai {
  Chat_with_ai(this._ref);
  final Ref _ref;
  SupabaseClient get supabase => _ref.read(supabaseProvider);
  Future<void> gemini(String my_Id, String roomId, String theme, String choice1,
      String choice2, bool player1_choice) async {
    for (int i = 0; i < 3; i++) {
      try {
        // player1_choiceがtrueならそのまま、falseなら選択肢を入れ替える
        final String playerChoice1 = player1_choice ? choice1 : choice2;
        final String playerChoice2 = player1_choice ? choice2 : choice1;

        log('gemini');

        await supabase.functions.invoke(
          'gemini',
          body: {
            'my_id': my_Id,
            'room_id': roomId,
            'theme': theme,
            'player1_choice': playerChoice1,
            'player2_choice': playerChoice2,
          },
        );
        return;
      } catch (e) {
        if (i < 2) {
          // 最後の試行でなければ、少し待ってからリトライ
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
  }
}
