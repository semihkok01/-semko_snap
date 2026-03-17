import 'package:flutter/material.dart';

import 'app_logo.dart';

class BrandAppBarTitle extends StatelessWidget {
  const BrandAppBarTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogo(
          size: 28,
          radius: 8,
          padding: EdgeInsets.all(2),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

