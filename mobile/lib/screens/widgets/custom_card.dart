// lib/widgets/custom_card.dart
import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Gradient? gradient;  // ✅ ADDED
  final double? elevation;
  final BorderRadius? borderRadius;
  final Border? border;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.gradient,  // ✅ ADDED
    this.elevation,
    this.borderRadius,
    this.border,
    this.onTap,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Material(
        color: gradient != null ? Colors.transparent : (backgroundColor ?? AppColors.white),  // ✅ Handle gradient
        borderRadius: borderRadius ?? BorderRadius.circular(16.0),
        elevation: elevation ?? 0,
        shadowColor: AppColors.shadowLight,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(16.0),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              borderRadius: borderRadius ?? BorderRadius.circular(16.0),
              border: border,
              gradient: gradient,  // ✅ Use gradient if provided
              color: gradient != null ? null : Colors.transparent,  // ✅ Transparent when gradient is used
              boxShadow: boxShadow ??
                  (elevation != null
                      ? [
                          const BoxShadow(
                            color: AppColors.shadowLight,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}