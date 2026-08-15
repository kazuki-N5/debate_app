// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';

class MatchErrorMessage extends StatelessWidget {
  final String message;

  const MatchErrorMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        message,
        style: AppTextStyles.bold(color: Colors.white, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }
}
