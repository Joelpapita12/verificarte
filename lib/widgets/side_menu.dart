import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../screens/create_account_screen.dart';
import '../screens/certificates_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/firma_digital_screen.dart';
import '../screens/login_screen.dart';
import '../screens/perfil_artista_screen.dart';
import '../screens/perfil_seguidor_screen.dart';
import '../screens/preferences_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/stats_dashboard_screen.dart';
import '../screens/transfers_screen.dart';
import '../services/auth_api.dart';
import '../services/current_user_store.dart';

const String _feedRouteName = '/feed';
const String _createPostRouteName = '/create-post';
const String _adminPanelRouteName = '/admin-panel';

class SideMenu extends StatefulWidget {
  const SideMenu({super.key});

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  final AuthApi _authApi = AuthApi();
  String _accountName = '[Nombre de la cuenta]';
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    CurrentUserStore.profileRevision.addListener(_onProfileRevision);
    _accountName = CurrentUserStore.publicName ?? _accountName;
    _photoUrl = CurrentUserStore.photoUrl;
    _loadProfile();
  }

  @override
  void dispose() {
    CurrentUserStore.profileRevision.removeListener(_onProfileRevision);
    super.dispose();
  }

  void _onProfileRevision() {
    if (!mounted) return;
    setState(() {
      _accountName = CurrentUserStore.publicName ?? _accountName;
      _photoUrl = CurrentUserStore.photoUrl;
    });
  }

  Future<void> _loadProfile() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;

    final result = await _authApi.fetchMe(userId: userId);
    if (!mounted || !result.ok || result.profile == null) return;

    setState(() {
      _accountName = result.profile!.publicName.trim().isEmpty
          ? result.profile!.username
          : result.profile!.publicName;
      _photoUrl = result.profile!.photoUrl.trim().isEmpty
          ? null
          : result.profile!.photoUrl;
    });

    CurrentUserStore.setProfile(publicName: _accountName, photoUrl: _photoUrl);
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = CurrentUserStore.userId == null;
    final role = CurrentUserStore.role ?? 'seguidor';

    return Drawer(
      width: 280,
      backgroundColor: AppColors.azulProfundo,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),
            _buildHeader(role),
            const Divider(color: Color.fromARGB(60, 255, 255, 255)),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _menuItem(
                      Icons.home,
                      'Inicio',
                      onTap: () =>
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            _feedRouteName,
                            (_) => false,
                          ),
                    ),
                    if (isGuest) ...[
                      _menuItem(
                        Icons.login,
                        'Iniciar sesi\u00f3n',
                        onTap: () {
                          ScaffoldMessenger.maybeOf(
                            context,
                          )?.hideCurrentSnackBar();
                          Navigator.of(
                            context,
                          ).pushNamed(LoginScreen.routeName);
                        },
                      ),
                      _menuItem(
                        Icons.person_add_alt_1,
                        'Crear cuenta',
                        onTap: () {
                          ScaffoldMessenger.maybeOf(
                            context,
                          )?.hideCurrentSnackBar();
                          Navigator.of(
                            context,
                          ).pushNamed(CreateAccountScreen.routeName);
                        },
                      ),
                    ] else ...[
                      _menuItem(
                        Icons.person_outline,
                        'Mi perfil',
                        onTap: () => Navigator.of(context).pushNamed(
                          role == 'artista'
                              ? PerfilArtistaScreen.routeName
                              : PerfilSeguidorScreen.routeName,
                        ),
                      ),
                    ],
                    if (!isGuest &&
                        (role == 'artista' || role == 'administrador')) ...[
                      _menuItem(
                        Icons.upload,
                        'Subir obra',
                        onTap: () async {
                          Navigator.of(context).pop();
                          await Navigator.of(context).pushNamed(
                            _createPostRouteName,
                          );
                        },
                      ),
                    ],
                    if (!isGuest && role == 'artista') ...[
                      _menuItem(
                        Icons.bar_chart,
                        'Estad\u00edsticas',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(StatsDashboardScreen.routeName),
                      ),
                      _menuItem(
                        Icons.draw,
                        'Firma digital',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(FirmaDigitalScreen.routeName),
                      ),
                    ],
                    if (!isGuest) ...[
                      if (role != 'administrador')
                        _menuItem(
                          Icons.flag_outlined,
                          'Denuncias',
                          onTap: () => Navigator.of(
                            context,
                          ).pushNamed(ReportsScreen.routeName),
                        ),
                      _menuItem(
                        Icons.bookmark,
                        'Favoritos',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(FavoritesScreen.routeName),
                      ),
                      _menuItem(
                        Icons.verified_outlined,
                        'Certificados',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(CertificatesScreen.routeName),
                      ),
                      _menuItem(
                        Icons.swap_horiz,
                        'Transferencias',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(TransfersScreen.routeName),
                      ),
                      _menuItem(
                        Icons.chat_bubble_outline,
                        'Chat',
                        onTap: () => Navigator.of(context).pushNamed('/chats'),
                      ),
                      if (role == 'administrador')
                        _menuItem(
                          Icons.admin_panel_settings_outlined,
                          'Panel administrador',
                          onTap: () => Navigator.of(
                            context,
                          ).pushNamed(_adminPanelRouteName),
                        ),
                      _menuItem(
                        Icons.settings,
                        'Configuraci\u00f3n',
                        onTap: () {
                          Navigator.of(context).pop();
                          _openSettingsPanel(context);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(color: Color.fromARGB(60, 255, 255, 255)),
            if (!isGuest)
              _menuItem(
                Icons.logout,
                'Cerrar sesi\u00f3n',
                onTap: () {
                  CurrentUserStore.clear();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    _feedRouteName,
                    (_) => false,
                  );
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String role) {
    return Column(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: const Color(0xFF4D6B95),
          backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
          child: _photoUrl == null
              ? const Icon(Icons.person, color: Colors.white, size: 34)
              : null,
        ),
        const SizedBox(height: 10),
        Text(
          _accountName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          CurrentUserStore.userId == null
              ? 'Invitado'
              : role == 'artista'
              ? 'Artista'
              : role == 'seguidor'
              ? 'Seguidor del arte'
              : 'Administrador',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _menuItem(IconData icon, String text, {VoidCallback? onTap}) {
    return _MenuHover(
      child: ListTile(
        onTap: onTap ?? () {},
        contentPadding: const EdgeInsets.only(left: 34, right: 16),
        minLeadingWidth: 16,
        horizontalTitleGap: 10,
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }

  void _openSettingsPanel(BuildContext context) {
    final media = MediaQuery.of(context);
    final topOffset = media.padding.top + kToolbarHeight;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final role = CurrentUserStore.role ?? 'seguidor';
    final isArtist = role == 'artista';

    showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Cerrar configuración',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, _) {
        Widget item({
          required IconData icon,
          required String title,
          required Future<void> Function() onTap,
        }) {
          return _MenuHover(
            child: ListTile(
              leading: Icon(icon, color: Colors.white),
              title: Text(title, style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.of(dialogContext, rootNavigator: true).pop();
                await onTap();
              },
            ),
          );
        }

        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(top: topOffset),
            child: SizedBox(
              width: 280,
              height: media.size.height - topOffset,
              child: Material(
                color: const Color(0xFF0B2150),
                child: ListView(
                  padding: const EdgeInsets.only(top: 24),
                  children: [
                    item(
                      icon: Icons.edit,
                      title: 'Editar perfil',
                      onTap: () async =>
                          rootNavigator.pushNamed(EditProfileScreen.routeName),
                    ),
                    item(
                      icon: Icons.tune,
                      title: 'Preferencias',
                      onTap: () async =>
                          rootNavigator.pushNamed(PreferencesScreen.routeName),
                    ),
                    if (isArtist)
                      item(
                        icon: Icons.draw,
                        title: 'Firma digital',
                        onTap: () async => rootNavigator.pushNamed(
                          FirmaDigitalScreen.routeName,
                        ),
                      ),
                    if (isArtist)
                      item(
                        icon: Icons.bar_chart,
                        title: 'Estadísticas',
                        onTap: () async => rootNavigator.pushNamed(
                          StatsDashboardScreen.routeName,
                        ),
                      ),
                    item(
                      icon: Icons.delete_outline,
                      title: 'Eliminar cuenta',
                      onTap: () async {
                        final userId = CurrentUserStore.userId;
                        if (userId == null) return;
                        final reasonController = TextEditingController();
                        final reason = await showDialog<String>(
                          context: rootNavigator.context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Eliminar cuenta'),
                            content: TextField(
                              controller: reasonController,
                              decoration: const InputDecoration(
                                labelText: 'Motivo (opcional)',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(
                                  ctx,
                                ).pop(reasonController.text.trim()),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (reason == null) return;

                        final result = await _authApi.deleteAccount(
                          userId: userId,
                          reason: reason,
                        );
                        if (!result.ok) return;

                        CurrentUserStore.clear();
                        rootNavigator.pushNamedAndRemoveUntil(
                          _feedRouteName,
                          (_) => false,
                        );
                      },
                    ),
                    item(
                      icon: Icons.logout,
                      title: 'Cerrar sesión',
                      onTap: () async {
                        CurrentUserStore.clear();
                        rootNavigator.pushNamedAndRemoveUntil(
                          LoginScreen.routeName,
                          (_) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuHover extends StatefulWidget {
  const _MenuHover({required this.child});

  final Widget child;

  @override
  State<_MenuHover> createState() => _MenuHoverState();
}

class _MenuHoverState extends State<_MenuHover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.015 : 1,
        duration: const Duration(milliseconds: 140),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x112E62C5) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}


