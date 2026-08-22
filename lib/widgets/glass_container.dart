import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;
  final VoidCallback? onTap;

  const GlassContainer({
    Key? key,
    required this.child,
    this.blur = 15.0,
    this.opacity = 0.12,
    this.borderRadius = 16.0,
    this.padding,
    this.margin,
    this.border,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: Colors.white.withOpacity(0.18), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );

    Widget clip = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: clip,
      );
    }
    return clip;
  }
}
