import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatefulWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlassContainer({
    Key? key,
    required this.child,
    this.blur = 15.0,
    this.opacity = 0.12,
    this.borderRadius = 16.0,
    this.padding,
    this.margin,
    this.border,
    this.gradient,
    this.boxShadow,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = widget.border ??
        Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.0,
        );

    final effectiveGradient = widget.gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(widget.opacity + 0.05),
            Colors.white.withOpacity(widget.opacity * 0.75),
          ],
        );

    final effectiveShadow = widget.boxShadow ??
        [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ];

    Widget content = Container(
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: effectiveBorder,
        boxShadow: effectiveShadow,
      ),
      child: widget.child,
    );

    Widget clip = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: widget.blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
              child: content,
            )
          : content,
    );

    if (widget.onTap != null || widget.onLongPress != null) {
      return GestureDetector(
        onTapDown: (_) {
          if (mounted) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (mounted) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (mounted) setState(() => _isPressed = false);
        },
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: clip,
        ),
      );
    }

    return clip;
  }
}
