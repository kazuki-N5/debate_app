class DateFormatter {
  /// チャット吹き出し横に表示する時刻ラベル。
  /// 日付に関わらず常に HH:MM を返す。
  static String formatChatTime(DateTime date) {
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// チャットの日付区切りラベル（LINE風）。
  /// 今日→「今日」、昨日→「昨日」、同じ年→「M月D日」、それ以外→「YYYY年M月D日」
  /// [now] を指定するとその日時基準で判定できる（テスト用）。
  static String formatChatDateDivider(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    // UTC の深夜同士で比較することで時差・サマータイムの影響を排除し、
    // 「何日前の暦日か」を正確に求める
    final diffDays = DateTime.utc(current.year, current.month, current.day)
        .difference(DateTime.utc(date.year, date.month, date.day))
        .inDays;
    if (diffDays == 0) return '今日';
    if (diffDays == 1) return '昨日';
    if (date.year == current.year) return '${date.month}月${date.day}日';
    return '${date.year}年${date.month}月${date.day}日';
  }

  /// 2つの日付が同じ暦日（年・月・日）かどうか
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String formatBbsDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0 && diff.inHours < 24) {
      // 24時間以内
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;

      if (hours > 0) {
        if (minutes > 0) {
          return '$hours時間$minutes分前';
        } else {
          return '$hours時間前';
        }
      } else {
        if (minutes > 0) {
          return '$minutes分前';
        } else {
          return 'たった今';
        }
      }
    } else if (diff.inDays < 30) {
      // 24時間以降 〜 30日未満
      return '${diff.inDays}日前';
    } else {
      // 30日以上
      final month = date.month;
      final day = date.day;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$month/$day $hour:$minute';
    }
  }
}
