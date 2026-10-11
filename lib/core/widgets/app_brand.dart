import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class AppBrand extends StatelessWidget {
  const AppBrand({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 68,
        height: 68,
        decoration: const BoxDecoration(
          color: AppColors.text,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(17),
        child: SvgPicture.asset('assets/images/brand-mark.svg'),
      ),
      const SizedBox(height: 24),
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'SelfCheck'),
            const TextSpan(
              text: 'Pro',
              style: TextStyle(color: AppColors.brand),
            ),
          ],
        ),
        style: AppText.titleH1().copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Text(
        'Контроль качества · аудиты · чек-листы',
        textAlign: TextAlign.center,
        style: AppText.bodyH5(color: AppColors.text),
      ),
    ],
  );
}
