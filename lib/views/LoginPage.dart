import 'package:debate_project/provider/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usernotifier = ref.read(userProvider.notifier);
    Future<void> _init(BuildContext context) async {
      try {
        await usernotifier.signinandname();
      } catch (e) {
        print('error');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init(context);
    });

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
