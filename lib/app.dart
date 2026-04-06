import 'package:flutter/material.dart';

import 'screens/admin_panel_screen.dart';
import 'screens/certificates_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/create_account_screen.dart';
import 'screens/create_post_flow_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/feed_placeholder_screen.dart';
import 'screens/firma_digital_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/login_screen.dart';
import 'screens/perfil_artista_screen.dart';
import 'screens/perfil_seguidor_screen.dart';
import 'screens/preferences_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/stats_dashboard_screen.dart';
import 'screens/transfers_screen.dart';
import 'screens/two_factor_screen.dart';
import 'theme/app_theme.dart';

class VerificarteApp extends StatelessWidget {
  const VerificarteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verificarte',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: FeedPlaceholderScreen.routeName,
      routes: {
        AdminPanelScreen.routeName: (context) => const AdminPanelScreen(),
        CertificatesScreen.routeName: (context) => const CertificatesScreen(),
        ChatsScreen.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final initialOtherUserId = args is int ? args : null;
          return ChatsScreen(initialOtherUserId: initialOtherUserId);
        },
        CreateAccountScreen.routeName: (context) => const CreateAccountScreen(),
        CreatePostFlowScreen.routeName: (context) =>
            const CreatePostFlowScreen(),
        EditProfileScreen.routeName: (context) => const EditProfileScreen(),
        FavoritesScreen.routeName: (context) => const FavoritesScreen(),
        FeedPlaceholderScreen.routeName: (context) =>
            const FeedPlaceholderScreen(),
        FirmaDigitalScreen.routeName: (context) => const FirmaDigitalScreen(),
        LoadingScreen.routeName: (context) => const LoadingScreen(),
        LoginScreen.routeName: (context) => const LoginScreen(),
        PerfilArtistaScreen.routeName: (context) => const PerfilArtistaScreen(),
        PerfilSeguidorScreen.routeName: (context) =>
            const PerfilSeguidorScreen(),
        PreferencesScreen.routeName: (context) => const PreferencesScreen(),
        ReportsScreen.routeName: (context) => const ReportsScreen(),
        ResetPasswordScreen.routeName: (context) => const ResetPasswordScreen(),
        StatsDashboardScreen.routeName: (context) =>
            const StatsDashboardScreen(),
        TransfersScreen.routeName: (context) => const TransfersScreen(),
        TwoFactorScreen.routeName: (context) => const TwoFactorScreen(),
      },
    );
  }
}

