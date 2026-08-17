import 'package:flutter/material.dart';

class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const MentionText({super.key, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Text(text, style: style);
    }

    final List<TextSpan> children = [];
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

    return RichText(
      text: TextSpan(style: style, children: children),
    );
  }
}
