import 'package:flutter/material.dart';

class AppBrandTitle extends StatelessWidget {
  final String text;

  const AppBrandTitle({
    super.key,
    this.text = 'Multi-chat',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'chat.png',
          width: 26,
          height: 26,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
