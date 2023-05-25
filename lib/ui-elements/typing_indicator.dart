import 'package:flutter/material.dart';

class Dot extends StatelessWidget {
  final Color? color;
  final double? radius;

  const Dot({super.key, this.color, this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        height: radius,
        width: radius);
  }
}

const number = 3;
const duration = Duration(milliseconds: 200);
const double offset = -7;
const delay = 500;

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  List<AnimationController>? _controllers;
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
        number, (i) => AnimationController(vsync: this, duration: duration));

    for (int i = 0; i < number; i++) {
      _animations.add(Tween<double>(begin: 0, end: -offset.abs())
          .animate(_controllers![i]));
    }
    for (int i = 0; i < number; i++) {
      _controllers![i].addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controllers![i].reverse();
          if (i != number - 1) {
            _controllers![i + 1].forward();
          }
        }
        if (i == number - 1 && status == AnimationStatus.dismissed) {
          if (delay == 0) {
            _controllers![0].forward();
          } else {
            Future.delayed(const Duration(milliseconds: delay), () {
              if (mounted) _controllers![0].forward();
            });
          }
        }
      });
    }
    _controllers!.first.forward();
  }

  @override
  void dispose() {
    for (var controller in _controllers!) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(number, (i) {
            return AnimatedBuilder(
                animation: _controllers![i],
                builder: (context, child) {
                  return Container(
                      padding: const EdgeInsets.all(2.5),
                      child: Transform.translate(
                          offset: Offset(0, _animations[i].value),
                          child: const Dot(color: Colors.grey, radius: 4)));
                });
          })),
    );
  }
}
