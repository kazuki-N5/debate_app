// ignore_for_file: file_names, avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:debate_project/widgets/app_text_styles.dart';
import 'package:popover/popover.dart';

void showCustomPopover({
  required BuildContext context,
  required List<Widget> children,
  required double height,
}) {
  showPopover(
    context: context,
    bodyBuilder: (context) => Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      ),
    ),
    direction: PopoverDirection.bottom,
    backgroundColor: Colors.white,
    barrierColor: Colors.transparent,
    width: 100,
    height: height,
    arrowHeight: 10,
    arrowWidth: 20,
    transitionDuration: const Duration(milliseconds: 150),
  );
}

class PopoverButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const PopoverButton({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              text,
              style: AppTextStyles.bold(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
