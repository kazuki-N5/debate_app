class DateFormatter {
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
