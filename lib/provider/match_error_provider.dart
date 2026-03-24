import 'package:debate_project/main.dart';
import 'package:debate_project/widgets/match_error_message.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final matchErrorServiceProvider = Provider((ref) {
  return MatchErrorService(ref);
});

class MatchErrorService {
  final Ref _ref;

  MatchErrorService(this._ref);

  void showMatchEndMessage(String message, double bottomRatio) {
    final key = _ref.read(scaffoldMessengerKeyProvider);
    final context = key.currentContext;

    if (context != null) {
      final height = MediaQuery.of(context).size.height;

      key.currentState?.showSnackBar(
        SnackBar(
          content: MatchErrorMessage(message: message),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: height * bottomRatio,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
