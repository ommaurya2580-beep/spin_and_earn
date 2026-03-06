import 'package:flutter/material.dart';

class AnimatedBalanceText extends StatefulWidget {
  final num targetValue;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  const AnimatedBalanceText({
    super.key,
    required this.targetValue,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedBalanceText> createState() => _AnimatedBalanceTextState();
}

class _AnimatedBalanceTextState extends State<AnimatedBalanceText> {
  @override
  Widget build(BuildContext context) {
    // On subsequent builds where targetValue changes, TweenAnimationBuilder
    // will animate from its current internal value to the new 'end'.
    // Providing widget.targetValue for 'begin' ensures it doesn't animate from 0
    // on the first ever frame, whilst also avoiding any stale _beginValue state cache.
    return TweenAnimationBuilder<num>(
      tween: Tween<num>(begin: widget.targetValue, end: widget.targetValue),
      duration: widget.duration,
      curve: Curves.easeOut,
      builder: (context, value, child) {
        String formattedValue;
        if (widget.targetValue is int) {
           // If target is int, treat as int
           formattedValue = value.toInt().toString();
        } else {
           // If target is double, keep decimals
           formattedValue = value.toStringAsFixed(2);
        }
        
        return Text(
          '${widget.prefix}$formattedValue${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}
