import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 96,
    this.radius = 24,
    this.showBackground = false,
    this.padding = const EdgeInsets.all(0),
  });

  final double size;
  final double radius;
  final bool showBackground;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final logo = Padding(
      padding: padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );

    if (!showBackground) {
      return logo;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: logo,
    );
  }
}
