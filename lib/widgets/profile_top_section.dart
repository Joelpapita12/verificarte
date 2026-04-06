import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class ProfileTopSection extends StatelessWidget {
  const ProfileTopSection({
    super.key,
    required this.accountName,
    required this.description,
    this.accountCode,
    this.photoUrl,
    this.showMessageButton = true,
    this.onMessageTap,
    this.onAvatarTap,
  });

  final String accountName;
  final String description;
  final String? accountCode;
  final String? photoUrl;
  final bool showMessageButton;
  final VoidCallback? onMessageTap;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      color: AppColors.azulMarino,
      child: Column(
        children: [
          if ((accountCode ?? '').trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                'Código: ${accountCode!.trim()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          GestureDetector(
            onTap: onAvatarTap,
            child: _HoverScale(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFF46608F),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  image: photoUrl != null && photoUrl!.trim().isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: photoUrl == null || photoUrl!.trim().isEmpty
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            accountName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description.trim().isEmpty ? 'Sin descripción' : description,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link, size: 16, color: AppColors.colorEnlace),
              SizedBox(width: 6),
              Text(
                'Enlaces',
                style: TextStyle(
                  color: AppColors.colorEnlace,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
          if (showMessageButton) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onMessageTap,
              child: _HoverScale(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Enviar mensaje',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.azulProfundo,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HoverScale extends StatefulWidget {
  const _HoverScale({required this.child});

  final Widget child;

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.04 : 1,
        duration: const Duration(milliseconds: 140),
        child: widget.child,
      ),
    );
  }
}

