import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('通知', style: AppTextStyles.bold(color: Colors.white)),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Text('通知画面（仮）', style: AppTextStyles.bold(fontSize: 20)),
      ),
    );
  }
}
