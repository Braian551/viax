import 'package:flutter/material.dart';
import 'package:viax/src/features/company/presentation/widgets/company_logo.dart' as global_logo;

class CompanyLogo extends StatelessWidget {
  const CompanyLogo({
    super.key,
    required this.logoUrl,
    this.size = 50.0,
    this.borderRadius = 12.0,
    this.backgroundColor,
    this.iconColor,
  });

  final String? logoUrl;
  final double size;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: global_logo.CompanyLogo(
          logoKey: logoUrl,
          nombreEmpresa: '',
          size: size,
          fontSize: size * 0.5,
          enableCacheBusting: true,
        ),
      ),
    );
  }
}
