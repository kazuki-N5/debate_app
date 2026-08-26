import 'package:flutter/material.dart';
import 'package:debate_project/utils/date_formatter.dart';
import 'package:debate_project/widgets/app_text_styles.dart';

/// チャットの日付区切りラベル（LINE風）。
/// 「日付が変わった」メッセージの直上に中央寄せで表示し、
/// 今日→「今日」、昨日→「昨日」、それ以前→「M月D日 / YYYY年M月D日」と表示する。
class ChatDateSeparator extends StatelessWidget {
  final DateTime date;

  const ChatDateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            DateFormatter.formatChatDateDivider(date),
            style: AppTextStyles.notoSans(
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// メッセージ一覧を表示するための1アイテム（reverse:true の ListView 用）
sealed class ChatListEntry {
  const ChatListEntry();
}

/// 通常のメッセージ1件。[index] は元の messages リストの添字（0 = 最新）
class ChatListMessageEntry extends ChatListEntry {
  final int index;
  const ChatListMessageEntry(this.index);
}

/// 日付区切りラベル1枚
class ChatListDateDividerEntry extends ChatListEntry {
  final DateTime date;
  const ChatListDateDividerEntry(this.date);
}

/// メッセージ一覧（新しい順・index 0 = 最新）から、
/// 日付区切りを挟んだ表示用アイテム列を組み立てる（index 0 = 最新 = 画面下）。
///
/// - ラベルは「実際にメッセージがある日」の先頭（その日で最も古いメッセージ）の
///   直上にだけ挟む。間の日（メッセージが無い日）には何も出さない。
/// - [isSkipped] を返すメッセージ（削除済みなど表示されないもの）は日付判定の
///   対象から除外し、その直上にもラベルを置かない。
List<ChatListEntry> buildChatListEntries<T>(
  List<T> messages,
  DateTime Function(T) dateOf, {
  bool Function(T)? isSkipped,
}) {
  final entries = <ChatListEntry>[];
  for (var i = 0; i < messages.length; i++) {
    entries.add(ChatListMessageEntry(i));
    if (isSkipped?.call(messages[i]) ?? false) continue;

    // 自分より古い側で「表示される」直近のメッセージを探す
    var j = i + 1;
    while (j < messages.length && (isSkipped?.call(messages[j]) ?? false)) {
      j++;
    }
    final isDayStart = j == messages.length ||
        !DateFormatter.isSameDay(dateOf(messages[i]), dateOf(messages[j]));
    if (isDayStart) {
      entries.add(ChatListDateDividerEntry(dateOf(messages[i])));
    }
  }
  return entries;
}
