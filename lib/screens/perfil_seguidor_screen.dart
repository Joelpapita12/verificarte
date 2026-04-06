import 'package:flutter/material.dart';

import '../constants/app_colors.dart' as profile_colors;
import '../services/auth_api.dart';
import '../services/current_user_store.dart';
import 'edit_profile_screen.dart';
import '../widgets/profile_top_section.dart';
import '../widgets/side_menu.dart';

class PerfilSeguidorScreen extends StatefulWidget {
  const PerfilSeguidorScreen({super.key});

  static const String routeName = '/perfil-seguidor';

  @override
  State<PerfilSeguidorScreen> createState() => _PerfilSeguidorScreenState();
}

class _PerfilSeguidorScreenState extends State<PerfilSeguidorScreen> {
  final AuthApi _authApi = AuthApi();
  String _accountName = '[Nombre de la cuenta]';
  String _description = '[Descripción]';
  String? _accountCode;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    CurrentUserStore.profileRevision.addListener(_onProfileChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    CurrentUserStore.profileRevision.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    final result = await _authApi.fetchMe(userId: userId);
    if (!mounted || !result.ok || result.profile == null) return;
    setState(() {
      _accountName = result.profile!.publicName;
      _description = result.profile!.description;
      _accountCode = result.profile!.transferCode;
      _photoUrl = result.profile!.photoUrl;
    });
  }

  void _openAvatarActions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar perfil'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  this.context,
                ).pushNamed(EditProfileScreen.routeName);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const SideMenu(),
      appBar: AppBar(
        backgroundColor: profile_colors.AppColors.azulProfundo,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'verificARTE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ProfileTopSection(
              accountName: _accountName,
              description: _description,
              accountCode: _accountCode,
              photoUrl: _photoUrl,
              showMessageButton: false,
              onAvatarTap: _openAvatarActions,
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 800,
              child: ColoredBox(color: Color(0xFF1C355A)),
            ),
          ),
        ],
      ),
    );
  }
}

