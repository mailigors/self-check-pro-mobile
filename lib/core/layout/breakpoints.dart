import 'package:flutter/material.dart';

abstract final class Breakpoints {
  static const tablet = 600.0;
  static const desktop = 1024.0;
}

enum AppFormFactor { mobile, tablet, desktop }

AppFormFactor formFactorOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= Breakpoints.desktop) return AppFormFactor.desktop;
  if (width >= Breakpoints.tablet) return AppFormFactor.tablet;
  return AppFormFactor.mobile;
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.child,
    this.maxWidth = 840,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final factor = formFactorOf(context);
    final horizontal = switch (factor) {
      AppFormFactor.mobile => 0.0,
      AppFormFactor.tablet => 24.0,
      AppFormFactor.desktop => 48.0,
    };
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: child,
        ),
      ),
    );
  }
}
