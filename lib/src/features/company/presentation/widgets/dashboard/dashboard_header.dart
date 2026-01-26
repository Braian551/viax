import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/features/company/presentation/widgets/company_logo.dart';
import 'package:viax/src/features/user/presentation/providers/user_provider.dart';
import 'package:viax/src/theme/app_colors.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = context.watch<UserProvider>();
    
    return Consumer<CompanyProvider>(
      builder: (context, provider, _) {
        final userName = userProvider.currentUser?.nombre ?? 
                        provider.company?['representante_nombre']?.toString().split(' ').first ??
                        'Usuario';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark 
                  ? [AppColors.darkSurface, AppColors.darkSurface.withAlpha(200)]
                  : [Colors.white, Colors.white.withAlpha(240)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bienvenido de nuevo,',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: CompanyLogo(
                      logoKey: provider.company?['logo_url'],
                      nombreEmpresa: provider.company?['nombre'] ?? 'Empresa',
                      size: 48,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
