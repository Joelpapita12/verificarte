import 'package:flutter/material.dart';

import '../constants/app_colors.dart' as profile_colors;
import '../models/post.dart';
import '../services/auth_api.dart';
import '../services/current_user_store.dart';
import '../services/feed_api.dart';
import 'chats_screen.dart';
import 'edit_profile_screen.dart';
import '../widgets/post_card.dart';
import '../widgets/profile_top_section.dart';
import '../widgets/side_menu.dart';

class PerfilArtistaScreen extends StatefulWidget {
  const PerfilArtistaScreen({super.key, this.userId});

  static const String routeName = '/perfil-artista';
  final int? userId;

  @override
  State<PerfilArtistaScreen> createState() => _PerfilArtistaScreenState();
}

class _PerfilArtistaScreenState extends State<PerfilArtistaScreen> {
  final FeedApi _feedApi = FeedApi();
  final AuthApi _authApi = AuthApi();

  bool _loading = true;
  List<Post> _posts = [];
  String _accountName = '[Nombre de la cuenta]';
  String _description = '[Descripción]';
  String? _accountCode;
  String? _photoUrl;
  int? _profileUserId;

  @override
  void initState() {
    super.initState();
    CurrentUserStore.profileRevision.addListener(_onProfileChanged);
    _loadData();
  }

  @override
  void dispose() {
    CurrentUserStore.profileRevision.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final currentUserId = CurrentUserStore.userId;
      _profileUserId = widget.userId ?? currentUserId;
      if (_profileUserId == null) {
        if (!mounted) return;
        setState(() {
          _posts = [];
          _loading = false;
        });
        return;
      }

      final profileResult = await _authApi.fetchMe(userId: _profileUserId!);
      if (profileResult.ok && profileResult.profile != null) {
        _accountName = profileResult.profile!.publicName;
        _description = profileResult.profile!.description;
        _photoUrl = profileResult.profile!.photoUrl;
        _accountCode = profileResult.profile!.transferCode;
      }

      final dto = await _feedApi.fetchPosts(artistId: _profileUserId);
      final filtered = dto
          .map(
            (p) => Post(
              id: p.id,
              ownerId: p.artistId,
              title: p.title,
              description: p.description,
              imageUrl: p.imageUrl,
              available:
                  p.propietarioCuenta == null || p.propietarioCuenta!.isEmpty,
              hasOwner:
                  p.propietarioCuenta != null &&
                  p.propietarioCuenta!.isNotEmpty,
              likeCount: p.likeCount,
              commentCount: p.commentCount,
              edicion: p.edicion,
              medidas: p.dimensiones,
              autor: p.nombreAutorCompleto,
              hasPropietario:
                  p.propietarioCuenta != null &&
                  p.propietarioCuenta!.isNotEmpty,
              propietarioAnonimo: p.propietarioAnonimo,
              propietarioCuenta: p.propietarioCuenta,
              tecnicaMateriales: p.tecnicaMateriales,
              anioCreacion: p.anioCreacion,
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _posts = filtered;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _deletePost(Post post) async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: const Text('¿Seguro que deseas eliminar esta publicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _feedApi.deletePost(userId: userId, postId: post.id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Publicación eliminada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _editPost(Post post) async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;

    final titleController = TextEditingController(text: post.title);
    final descriptionController = TextEditingController(text: post.description);
    final edicionController = TextEditingController(text: post.edicion ?? '');
    final medidasController = TextEditingController(text: post.medidas ?? '');
    final autorController = TextEditingController(text: post.autor ?? '');
    final tecnicaController = TextEditingController(
      text: post.tecnicaMateriales ?? '',
    );
    final anioController = TextEditingController(
      text: post.anioCreacion?.toString() ?? '',
    );
    final propietarioController = TextEditingController(
      text: post.propietarioCuenta ?? '',
    );

    String estadoObra = post.hasPropietario ? 'con_propietario' : 'disponible';
    bool propietarioAnonimo = post.propietarioAnonimo;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Modificar publicación'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: edicionController,
                    decoration: const InputDecoration(labelText: 'Edición'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: medidasController,
                    decoration: const InputDecoration(labelText: 'Medidas'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: autorController,
                    decoration: const InputDecoration(labelText: 'Autor'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tecnicaController,
                    decoration: const InputDecoration(
                      labelText: 'Técnica/materiales',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: anioController,
                    decoration: const InputDecoration(
                      labelText: 'Año de creación',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: estadoObra,
                    items: const [
                      DropdownMenuItem(
                        value: 'disponible',
                        child: Text('Sin propietario'),
                      ),
                      DropdownMenuItem(
                        value: 'con_propietario',
                        child: Text('Con propietario'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setModalState(() => estadoObra = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Estado de obra',
                    ),
                  ),
                  if (estadoObra == 'con_propietario') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: propietarioController,
                      decoration: const InputDecoration(
                        labelText: 'Cuenta propietaria',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: propietarioAnonimo,
                      onChanged: (v) =>
                          setModalState(() => propietarioAnonimo = v),
                      title: const Text('Propietario anónimo'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop({
                'title': titleController.text.trim(),
                'description': descriptionController.text.trim(),
                'edicion': edicionController.text.trim(),
                'medidas': medidasController.text.trim(),
                'autor': autorController.text.trim(),
                'tecnica': tecnicaController.text.trim(),
                'anio': anioController.text.trim(),
                'estadoObra': estadoObra,
                'propietarioCuenta': propietarioController.text.trim(),
                'propietarioAnonimo': propietarioAnonimo,
              }),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (payload == null) return;
    if ((payload['title'] ?? '').toString().isEmpty) return;

    try {
      await _feedApi.updatePost(
        userId: userId,
        postId: post.id,
        title: (payload['title'] ?? '').toString(),
        description: (payload['description'] ?? '').toString(),
        imageUrl: post.imageUrl,
        estadoObra: (payload['estadoObra'] ?? 'disponible').toString(),
        tecnicaMateriales: (payload['tecnica'] ?? '').toString().isEmpty
            ? null
            : (payload['tecnica'] ?? '').toString(),
        anioCreacion: int.tryParse((payload['anio'] ?? '').toString()),
        dimensiones: (payload['medidas'] ?? '').toString().isEmpty
            ? null
            : (payload['medidas'] ?? '').toString(),
        edicion: (payload['edicion'] ?? '').toString().isEmpty
            ? null
            : (payload['edicion'] ?? '').toString(),
        nombreAutorCompleto: (payload['autor'] ?? '').toString().isEmpty
            ? null
            : (payload['autor'] ?? '').toString(),
        propietarioCuenta:
            (payload['propietarioCuenta'] ?? '').toString().isEmpty
            ? null
            : (payload['propietarioCuenta'] ?? '').toString(),
        propietarioAnonimo: payload['propietarioAnonimo'] == true,
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Publicación modificada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _openAvatarActions(bool isOwnProfile) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (isOwnProfile)
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
            if (!isOwnProfile)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Enviar mensaje'),
                onTap: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }

  void _openMessageToProfile() {
    final currentUserId = CurrentUserStore.userId;
    final targetId = widget.userId ?? _profileUserId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para enviar mensajes')),
      );
      return;
    }
    if (targetId == null || targetId == currentUserId) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatsScreen(initialOtherUserId: targetId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = CurrentUserStore.userId;
    final targetProfileId = widget.userId ?? _profileUserId ?? currentUserId;
    final isOwnProfile =
        currentUserId != null &&
        targetProfileId != null &&
        currentUserId == targetProfileId;

    return Scaffold(
      drawer: const SideMenu(),
      backgroundColor: profile_colors.AppColors.azulMarino,
      appBar: AppBar(
        backgroundColor: const Color(0xFF071330),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'verificARTE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ProfileTopSection(
              accountName: _accountName,
              description: _description,
              accountCode: _accountCode,
              photoUrl: _photoUrl,
              showMessageButton: !isOwnProfile,
              onMessageTap: !isOwnProfile ? _openMessageToProfile : null,
              onAvatarTap: () => _openAvatarActions(isOwnProfile),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (!_loading && _posts.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Este artista aún no ha publicado obras.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ),
            ),
          if (_posts.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: PostCard(
                          post: _posts[index],
                          currentUserId: currentUserId,
                          forceOwnOptions: isOwnProfile,
                          onEditPost: isOwnProfile ? _editPost : null,
                          onDeletePost: isOwnProfile ? _deletePost : null,
                        ),
                      ),
                    ),
                  ),
                  childCount: _posts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

