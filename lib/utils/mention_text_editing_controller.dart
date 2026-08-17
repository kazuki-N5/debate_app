import 'package:flutter/material.dart';

class MentionTextEditingController extends TextEditingController {
  MentionTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    if (text.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    final List<TextSpan> children = [];
    
    // @から始まり空白や改行までをメンションとみなす正規表現
    final RegExp mentionRegex = RegExp(r'(@[^\s]+)');
    
    int lastMatchEnd = 0;
    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: style));
      }
      children.add(TextSpan(
        text: match.group(0),
        style: style?.copyWith(color: Colors.blueAccent, fontWeight: FontWeight.bold),
      ));
      lastMatchEnd = match.end;
    }
    
    if (lastMatchEnd < text.length) {
      children.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
    }

    return TextSpan(style: style, children: children);
  }
}
