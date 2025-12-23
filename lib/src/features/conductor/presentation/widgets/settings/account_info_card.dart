import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Card de información de cuenta
class AccountInfoCard extends StatefulWidget {
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final VoidCallback? onEditProfile;

  const AccountInfoCard({
    super.key,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.onEditProfile,
  });

  @override
  State<AccountInfoCard> createState() => _AccountInfoCardState();
}

class _AccountInfoCardState extends State<AccountInfoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    isDark
                        ? AppColors.darkCard.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: widget.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              widget.avatarUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.person_rounded,
                            size: 36,
                            color: AppColors.primary,
                          ),
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white70
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        if (widget.phone != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.phone!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Edit button
                  if (widget.onEditProfile != null)
                    IconButton(
                      onPressed: widget.onEditProfile,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
