import 'dart:async';

import 'package:flutter/material.dart';

import '../services/current_user_store.dart';
import '../theme/app_colors.dart';

const String _feedRouteName = '/feed';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  static const String routeName = '/loading';

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      // El inicio principal siempre es feed.
      // El rol se usa para habilitar opciones en el menú lateral.
      final _ = CurrentUserStore.role;
      Navigator.of(context).pushReplacementNamed(_feedRouteName);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/gifs/Y3il.gif',
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'La seguridad de tu arte es lo más importante para nosotros',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.deepNavy),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
