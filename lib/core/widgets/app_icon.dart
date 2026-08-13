import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(this.asset, {super.key, this.size = 24, this.color});

  final String asset;
  final double size;
  final Color? color;

  static const back = 'assets/icons/back.svg';
  static const camera = 'assets/icons/camera.svg';
  static const video = 'assets/icons/video.svg';
  static const paperclip = 'assets/icons/paperclip.svg';
  static const chevronUp = 'assets/icons/chevron_up.svg';
  static const chevronDown = 'assets/icons/chevron_down.svg';
  static const user = 'assets/icons/user.svg';
  static const calendar = 'assets/icons/calendar.svg';
  static const close = 'assets/icons/close.svg';
  static const warning = 'assets/icons/warning.svg';
  static const file = 'assets/icons/file.svg';
  static const search = 'assets/icons/search.svg';
  static const trash = 'assets/icons/trash.svg';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: OverflowBox(
        maxWidth: size,
        maxHeight: size,
        child: SvgPicture.asset(
          asset,
          width: size,
          height: size,
          colorFilter: color == null
              ? null
              : ColorFilter.mode(color!, BlendMode.srcIn),
        ),
      ),
    );
  }
}
