import 'package:flutter/material.dart';

class RightView extends StatelessWidget {
  const RightView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: const SafeArea(child: Center(child: Text("this is the right"))));
  }
}
