import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../constants/app_colors.dart';
import '../models/api_models.dart';
import '../models/feed_post.dart';
import '../screens/chats_screen.dart';
import 'package:verificarteweb/screens/create_post_flow_screen.dart';
import '../screens/login_screen.dart';
import '../screens/perfil_artista_screen.dart';
import '../services/current_user_store.dart';
import '../services/feed_api.dart';
import '../services/file_download.dart';
import '../utils/certificate_pdf.dart';
import '../widgets/certificate_template_view.dart';
import '../widgets/security_watermark.dart';
import '../widgets/side_menu.dart';

class FeedPlaceholderScreen extends StatefulWidget {
  const FeedPlaceholderScreen({super.key});

  static const String routeName = '/feed';

  @override
  State<FeedPlaceholderScreen> createState() => _FeedPlaceholderScreenState();
}

class _FeedPlaceholderScreenState extends State<FeedPlaceholderScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FeedApi _feedApi = FeedApi();
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  String? _errorMessage;
  bool _searchFiltered = false;

  List<FeedPostDto> _posts = <FeedPostDto>[];
  List<NotificationDto> _notifications = <NotificationDto>[];

  int? get _userId => CurrentUserStore.userId;
  String? get _role => CurrentUserStore.role;
  bool get _isGuest => _userId == null;
  bool get _canPublish => _role == 'artista' || _role == 'administrador';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({String? query}) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final List<FeedPostDto> posts = await _feedApi.fetchPosts(
        query: query?.trim().isEmpty == true ? null : query?.trim(),
        userId: _userId,
      );

      List<NotificationDto> notifications = <NotificationDto>[];
      if (_userId != null) {
        await _feedApi.fetchChatThreads(_userId!);
        notifications = await _feedApi.fetchNotifications(_userId!);
      }

      if (!mounted) return;
      setState(() {
        _posts = posts;
        _notifications = notifications;
        _searchFiltered = query != null && query.trim().isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo cargar la feed.';
        _loading = false;
      });
    }
  }

  void _showAuthRequiredMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Inicia sesión o crea una cuenta para interactuar.',
        ),
        action: SnackBarAction(
          label: 'Iniciar sesión',
          onPressed: () {
            Navigator.of(context).pushNamed(LoginScreen.routeName);
          },
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    final result = await showDialog<_SearchAction>(
      context: context,
      builder: (_) => _SearchDialog(feedApi: _feedApi),
    );
    if (!mounted || result == null) return;

    switch (result.type) {
      case _SearchActionType.feedQuery:
        await _loadData(query: result.query);
        break;
      case _SearchActionType.account:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PerfilArtistaScreen(userId: result.account!.userId),
          ),
        );
        break;
      case _SearchActionType.post:
        await _loadData(query: result.query);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToPost(result.postId);
        });
        break;
    }
  }

  void _scrollToPost(int? postId) {
    if (postId == null || !_scrollController.hasClients) return;
    final int index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) return;
    final double offset = index * 560.0;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openNotifications() async {
    final int? userId = _userId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => _NotificationsDialog(
        notifications: _notifications,
        onTapNotification: (notification) async {
          Navigator.of(context).pop();
          await _feedApi.markNotificationsRead(userId);
          if (!mounted) return;
          setState(() {
            _notifications = _notifications
                .map(
                  (item) => item == notification
                      ? NotificationDto(
                          type: item.type,
                          postId: item.postId,
                          otherUserId: item.otherUserId,
                          unread: false,
                          actorName: item.actorName,
                          actorAvatar: item.actorAvatar,
                          commentText: item.commentText,
                          createdAt: item.createdAt,
                        )
                      : item,
                )
                .toList();
          });

          if (notification.otherUserId != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatsScreen(
                  initialOtherUserId: notification.otherUserId,
                ),
              ),
            );
            return;
          }

          if (notification.postId != null) {
            _scrollToPost(notification.postId);
          }
        },
      ),
    );
  }

  Future<void> _openCreatePost() async {
    if (!_canPublish) {
      _showAuthRequiredMessage();
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreatePostFlowScreen()));
    await _loadData();
  }

  Future<void> _toggleLike(FeedPostDto post) async {
    final int? userId = _userId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }
    try {
      await _feedApi.toggleLike(userId: userId, postId: post.id);
      await _loadData(query: _searchFiltered ? post.title : null);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleFavorite(FeedPostDto post) async {
    final int? userId = _userId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }
    try {
      await _feedApi.toggleFavorite(userId: userId, postId: post.id);
      await _loadData(query: _searchFiltered ? post.title : null);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openComments(FeedPostDto post) async {
    final int? userId = _userId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.azulMarino,
      builder: (_) => _CommentsSheet(
        feedApi: _feedApi,
        postId: post.id,
        currentUserId: userId,
        requireAuth: _showAuthRequiredMessage,
      ),
    );
    await _loadData(query: _searchFiltered ? post.title : null);
  }

  Future<void> _sendMessageToArtist(FeedPostDto post) async {
    final int? userId = _userId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }
    if (userId == post.artistId) {
      Navigator.of(context).pushNamed(ChatsScreen.routeName);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatsScreen(initialOtherUserId: post.artistId),
      ),
    );
  }

  Future<void> _handlePostMenu(
    FeedPostDto post,
    FeedPostEditionDto? edition,
    String value,
  ) async {
    switch (value) {
      case 'edit':
        await _editPost(post);
        break;
      case 'delete':
        await _deletePost(post);
        break;
      case 'report':
        await _reportPost(post);
        break;
      case 'history':
        await _showOwnershipHistory(post, edition);
        break;
      case 'certificate':
        await _showCertificate(post, edition);
        break;
    }
  }

  Future<void> _editPost(FeedPostDto post) async {
    final int? userId = _userId;
    if (userId == null) return;

    final TextEditingController titleController = TextEditingController(
      text: post.title,
    );
    final TextEditingController descriptionController = TextEditingController(
      text: post.description,
    );
    final TextEditingController editionController = TextEditingController(
      text: post.edicion ?? '',
    );
    final TextEditingController dimensionsController = TextEditingController(
      text: post.dimensiones ?? '',
    );
    final TextEditingController authorController = TextEditingController(
      text: post.nombreAutorCompleto ?? '',
    );
    final TextEditingController techniqueController = TextEditingController(
      text: post.tecnicaMateriales ?? '',
    );
    final TextEditingController yearController = TextEditingController(
      text: post.anioCreacion?.toString() ?? '',
    );
    final TextEditingController ownerController = TextEditingController(
      text: post.propietarioCuenta ?? '',
    );

    String state = (post.propietarioCuenta?.trim().isNotEmpty ?? false) ||
            post.propietarioAnonimo
        ? 'con_propietario'
        : 'disponible';
    bool ownerAnonymous = post.propietarioAnonimo;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Modificar publicación'),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Título'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: editionController,
                      decoration: const InputDecoration(labelText: 'Edición'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dimensionsController,
                      decoration: const InputDecoration(
                        labelText: 'Dimensiones',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: authorController,
                      decoration: const InputDecoration(labelText: 'Autor'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: techniqueController,
                      decoration: const InputDecoration(
                        labelText: 'Técnica o materiales',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: yearController,
                      decoration: const InputDecoration(
                        labelText: 'Año de creación',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: state,
                      decoration: const InputDecoration(
                        labelText: 'Estado de la obra',
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'disponible',
                          child: Text('Disponible'),
                        ),
                        DropdownMenuItem(
                          value: 'con_propietario',
                          child: Text('Con propietario'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          state = value;
                        });
                      },
                    ),
                    if (state == 'con_propietario') ...<Widget>[
                      const SizedBox(height: 10),
                      TextField(
                        controller: ownerController,
                        decoration: const InputDecoration(
                          labelText: 'Cuenta propietaria',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Propietario anónimo'),
                        value: ownerAnonymous,
                        onChanged: (value) {
                          setModalState(() {
                            ownerAnonymous = value;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Guardar cambios'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    try {
      await _feedApi.updatePost(
        userId: userId,
        postId: post.id,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        imageUrl: post.imageUrl,
        estadoObra: state,
        tecnicaMateriales: techniqueController.text.trim(),
        anioCreacion: int.tryParse(yearController.text.trim()),
        dimensiones: dimensionsController.text.trim(),
        edicion: editionController.text.trim(),
        nombreAutorCompleto: authorController.text.trim(),
        propietarioCuenta: ownerController.text.trim().isEmpty
            ? null
            : ownerController.text.trim(),
        propietarioAnonimo: ownerAnonymous,
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación actualizada')),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deletePost(FeedPostDto post) async {
    final int? userId = _userId;
    if (userId == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: Text('¿Seguro que deseas eliminar "${post.title}"?'),
        actions: <Widget>[
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
    if (confirmed != true) return;

    try {
      await _feedApi.deletePost(userId: userId, postId: post.id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación eliminada')),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reportPost(FeedPostDto post) async {
    final int? userId = _userId;
    if (userId == null) {
      _showAuthRequiredMessage();
      return;
    }

    String selectedReason = 'plagio';
    final TextEditingController descriptionController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Denunciar publicación'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'plagio',
                        child: Text('Denunciar plagio'),
                      ),
                      DropdownMenuItem(
                        value: 'contenido_explicitio',
                        child: Text('Contenido no deseado o explícito'),
                      ),
                      DropdownMenuItem(
                        value: 'otro',
                        child: Text('Otro'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        selectedReason = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Motivo de denuncia',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Describe tu problema',
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    try {
      await _feedApi.createReport(
        userId: userId,
        postId: post.id,
        reportType: selectedReason,
        description: descriptionController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu denuncia fue enviada')),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showOwnershipHistory(
    FeedPostDto post,
    FeedPostEditionDto? edition,
  ) async {
    try {
      final List<OwnershipHistoryDto> history = await _feedApi
          .fetchOwnershipHistory(
            postId: post.id,
            editionId: edition?.idEdicion == 0 ? null : edition?.idEdicion,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            'Historial de ${edition?.edicionLabel ?? post.edicion ?? '"'"'1/1'"'"'}',
          ),
          content: SizedBox(
            width: 560,
            child: history.isEmpty
                ? const Text('Todavía no hay transferencias registradas.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final OwnershipHistoryDto item = history[index];
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text('${item.fromName} ? ${item.toName}'),
                        subtitle: Text(_formatDateTime(item.createdAt)),
                      );
                    },
                  ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _showCertificate(
    FeedPostDto post,
    FeedPostEditionDto? edition,
  ) async {
    try {
      final CertificateDto? certificate = await _feedApi.fetchCertificate(
        postId: post.id,
        editionId: edition?.idEdicion == 0 ? null : edition?.idEdicion,
      );
      if (!mounted) return;
      if (certificate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esta edición no tiene certificado.')),
        );
        return;
      }

      final CertificateTemplateData data = CertificateTemplateData(
        title: post.title,
        artistName: (certificate.artistName?.trim().isNotEmpty ?? false)
            ? certificate.artistName!.trim()
            : post.publicName.isNotEmpty
            ? post.publicName
            : post.artistName,
        technique: post.tecnicaMateriales ?? '-',
        dimensions: certificate.dimensions ?? post.dimensiones ?? '-',
        creationDate:
            '${certificate.creationYear ?? post.anioCreacion ?? '-'}',
        editionLabel: certificate.edicionLabel.trim().isNotEmpty
            ? certificate.edicionLabel
            : (edition?.edicionLabel ?? post.edicion ?? '"'"'1/1'"'"'),
        issueDate: _formatDate(certificate.createdAt),
        digitalSignature:
            certificate.certificateSignatureB64 ??
            certificate.signatureHash ??
            '-',
        artworkHash: certificate.artworkHash ?? '-',
        folio: '#${certificate.id}',
        qrValue: certificate.qrCode ?? certificate.link ?? '-',
        registrationTimestamp: certificate.registrationTimestamp ?? '-',
        certificateTimestamp:
            certificate.certificateCreatedAt ??
            certificate.signatureTimestamp ??
            '-',
        artImageUrl:
            edition?.imageUrl?.trim().isNotEmpty == true
            ? edition!.imageUrl
            : certificate.imageUrl ?? post.imageUrl,
        authorFullName:
            certificate.authorFullName ??
            certificate.artistName ??
            post.publicName,
        signatureImageUrl: certificate.signatureImageUrl,
      );

      final GlobalKey repaintKey = GlobalKey();

      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 860),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.azulMarino,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Certificado • ${data.editionLabel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: RepaintBoundary(
                      key: repaintKey,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 660),
                        child: CertificateTemplateView(data: data),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () async {
                        final Uint8List pdf = await buildCertificatePdfFromBoundary(
                          repaintKey,
                        );
                        if (!mounted) return;
                        await Printing.layoutPdf(onLayout: (_) async => pdf);
                      },
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Imprimir'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final Uint8List pdf = await buildCertificatePdfFromBoundary(
                          repaintKey,
                        );
                        downloadFile(
                          pdf,
                          'certificado-${certificate.id}.pdf',
                          'application/pdf',
                        );
                      },
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Descargar PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SideMenu(),
      backgroundColor: AppColors.azulMarino,
      appBar: AppBar(
        backgroundColor: AppColors.azulProfundo,
        elevation: 0,
        leading: IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu),
          tooltip: 'Menú',
        ),
        title: const Text('VerificArte'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _loadData(),
            tooltip: 'Inicio',
            icon: const Icon(Icons.home_outlined),
          ),
          IconButton(
            onPressed: _openSearch,
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () {
              if (_isGuest) {
                _showAuthRequiredMessage();
                return;
              }
              Navigator.of(context).pushNamed(ChatsScreen.routeName);
            },
            tooltip: 'Mensaje',
            icon: const Icon(Icons.send_outlined),
          ),
          if (_canPublish)
            IconButton(
              onPressed: _openCreatePost,
              tooltip: 'Subir obra',
              icon: const Icon(Icons.add_box_outlined),
            ),
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              IconButton(
                onPressed: _openNotifications,
                tooltip: 'Notificaciones',
                icon: const Icon(Icons.notifications_none_outlined),
              ),
              if (_notifications.any((item) => item.unread))
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ListView(
        children: <Widget>[
          SizedBox(
            height: 420,
            child: Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ),
          ),
        ],
      );
    }

    if (_posts.isEmpty) {
      return ListView(
        children: const <Widget>[
          SizedBox(
            height: 420,
            child: Center(
              child: Text(
                'No hay publicaciones para mostrar.',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
      itemCount: _posts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final FeedPostDto post = _posts[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: _FeedPostCard(
              post: post,
              isGuest: _isGuest,
              isOwner: _userId == post.artistId,
              canEdit: _userId == post.artistId || _role == 'administrador',
              timestampLabel: _formatDateTime(DateTime.now()),
              artistLabel: post.publicName.isNotEmpty
                  ? post.publicName
                  : post.artistName,
              onTapArtist: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PerfilArtistaScreen(userId: post.artistId),
                  ),
                );
              },
              onLike: () => _toggleLike(post),
              onFavorite: () => _toggleFavorite(post),
              onComment: () => _openComments(post),
              onMessage: () => _sendMessageToArtist(post),
              onMenuSelected: (edition, value) =>
                  _handlePostMenu(post, edition, value),
            ),
          ),
        );
      },
    );
  }
}

class _FeedPostCard extends StatefulWidget {
  const _FeedPostCard({
    required this.post,
    required this.isGuest,
    required this.isOwner,
    required this.canEdit,
    required this.timestampLabel,
    required this.artistLabel,
    required this.onTapArtist,
    required this.onLike,
    required this.onFavorite,
    required this.onComment,
    required this.onMessage,
    required this.onMenuSelected,
  });

  final FeedPostDto post;
  final bool isGuest;
  final bool isOwner;
  final bool canEdit;
  final String timestampLabel;
  final String artistLabel;
  final VoidCallback onTapArtist;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onComment;
  final VoidCallback onMessage;
  final void Function(FeedPostEditionDto? edition, String value) onMenuSelected;

  @override
  State<_FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<_FeedPostCard> {
  int _currentIndex = 0;

  List<FeedPostEditionDto> get _editions {
    if (widget.post.ediciones.isNotEmpty) return widget.post.ediciones;
    return <FeedPostEditionDto>[
      FeedPostEditionDto(
        idEdicion: 0,
        numeroEdicion: 1,
        totalEdiciones: 1,
        edicionLabel: widget.post.edicion?.trim().isNotEmpty == true
            ? widget.post.edicion!.trim()
            : '1/1',
        imageUrl: widget.post.imageUrl,
      ),
    ];
  }

  FeedPostEditionDto? get _selectedEdition {
    if (_editions.isEmpty) return null;
    return _editions[_currentIndex.clamp(0, _editions.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final FeedPostEditionDto? edition = _selectedEdition;
    final String imageUrl =
        edition?.imageUrl?.trim().isNotEmpty == true
        ? edition!.imageUrl!.trim()
        : widget.post.imageUrl?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.azulProfundo,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black38,
            blurRadius: 26,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.onTapArtist,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          child: Text(
                            widget.artistLabel.isEmpty
                                ? '?'
                                : widget.artistLabel.characters.first
                                      .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.artistLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.post.artistName,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.azulMarino,
                icon: const Icon(Icons.more_horiz, color: Colors.white),
                onSelected: (value) =>
                    widget.onMenuSelected(_selectedEdition, value),
                itemBuilder: (_) {
                  if (widget.canEdit) {
                    return const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text(
                          'Modificar publicación',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text(
                          'Eliminar publicación',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ];
                  }
                  return const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'report',
                      child: Text(
                        'Denunciar plagio',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'history',
                      child: Text(
                        'Historial de propietarios',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'certificate',
                      child: Text(
                        'Ver certificado',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:
                  (widget.post.propietarioCuenta?.trim().isEmpty ?? true) &&
                      !widget.post.propietarioAnonimo
                  ? AppColors.statusAvailable
                  : AppColors.statusUnavailable,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              ((widget.post.propietarioCuenta?.trim().isEmpty ?? true) &&
                      !widget.post.propietarioAnonimo)
                  ? 'Disponible'
                  : 'Con propietario',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1.14,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      child: imageUrl.isEmpty
                          ? const Center(
                              child: Text(
                                'Sin imagen',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : SecurityWatermark(
                              userLabel: widget.artistLabel,
                              timestampLabel: widget.timestampLabel,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stackTrace) => const Center(
                                  child: Text(
                                    'No se pudo cargar la imagen',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (_editions.length > 1)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          edition?.edicionLabel ?? '${_currentIndex + 1}/${_editions.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  if (_editions.length > 1)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List<Widget>.generate(_editions.length, (
                            index,
                          ) {
                            final bool selected = index == _currentIndex;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _currentIndex = index;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: selected ? 22 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white
                                      : Colors.white38,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_editions.length > 1) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: _currentIndex > 0
                      ? () {
                          setState(() {
                            _currentIndex--;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: Colors.white,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Edición ${edition?.edicionLabel ?? '"'"'1/1'"'"'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _currentIndex < _editions.length - 1
                      ? () {
                          setState(() {
                            _currentIndex++;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  color: Colors.white,
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            widget.post.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.post.description.isEmpty
                ? 'Sin descripción disponible.'
                : widget.post.description,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _MetaChip(
                label: 'Técnica',
                value: widget.post.tecnicaMateriales ?? '-',
              ),
              _MetaChip(
                label: 'Dimensiones',
                value: widget.post.dimensiones ?? '-',
              ),
              _MetaChip(
                label: 'Año',
                value: widget.post.anioCreacion?.toString() ?? '-',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _ActionChip(
                icon: Icons.favorite_border,
                label: '${widget.post.likeCount}',
                onTap: widget.onLike,
              ),
              const SizedBox(width: 10),
              _ActionChip(
                icon: Icons.comment_outlined,
                label: '${widget.post.commentCount}',
                onTap: widget.onComment,
              ),
              const SizedBox(width: 10),
              _ActionChip(
                icon: Icons.bookmark_border,
                label: '${widget.post.favoriteCount}',
                onTap: widget.onFavorite,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.onMessage,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Mensaje'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.feedApi,
    required this.postId,
    required this.currentUserId,
    required this.requireAuth,
  });

  final FeedApi feedApi;
  final int postId;
  final int? currentUserId;
  final VoidCallback requireAuth;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  List<PostCommentDto> _comments = <PostCommentDto>[];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await widget.feedApi.fetchComments(postId: widget.postId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final int? userId = widget.currentUserId;
    if (userId == null) {
      widget.requireAuth();
      return;
    }
    final String content = _controller.text.trim();
    if (content.isEmpty) return;
    setState(() {
      _saving = true;
    });
    try {
      await widget.feedApi.addComment(
        userId: userId,
        postId: widget.postId,
        content: content,
      );
      _controller.clear();
      await _loadComments();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo agregar el comentario')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _editComment(PostCommentDto comment) async {
    final int? userId = widget.currentUserId;
    if (userId == null) return;
    final TextEditingController controller = TextEditingController(
      text: comment.content,
    );
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modificar comentario'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Comentario'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.feedApi.updateComment(
        userId: userId,
        commentId: comment.commentId,
        content: controller.text.trim(),
      );
      await _loadComments();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo modificar el comentario')),
      );
    }
  }

  Future<void> _deleteComment(PostCommentDto comment) async {
    final int? userId = widget.currentUserId;
    if (userId == null) return;
    try {
      await widget.feedApi.deleteComment(
        userId: userId,
        commentId: comment.commentId,
      );
      await _loadComments();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el comentario')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets insets = MediaQuery.of(context).viewInsets;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 14),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Comentarios',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'Sé la primera persona en comentar.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _comments.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: Colors.white12),
                        itemBuilder: (context, index) {
                          final PostCommentDto comment = _comments[index];
                          final bool isMine =
                              comment.userId == widget.currentUserId;
                          return ListTile(
                            title: Text(
                              comment.publicName.isNotEmpty
                                  ? comment.publicName
                                  : comment.username,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              comment.content,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: isMine
                                ? PopupMenuButton<String>(
                                    color: AppColors.azulMarino,
                                    icon: const Icon(
                                      Icons.more_horiz,
                                      color: Colors.white70,
                                    ),
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editComment(comment);
                                      } else if (value == 'delete') {
                                        _deleteComment(comment);
                                      }
                                    },
                                    itemBuilder: (_) =>
                                        const <PopupMenuEntry<String>>[
                                          PopupMenuItem<String>(
                                            value: 'edit',
                                            child: Text(
                                              'Modificar',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Text(
                                              'Eliminar',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                  )
                                : null,
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Escribe un comentario',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saving ? null : _submitComment,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enviar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsDialog extends StatelessWidget {
  const _NotificationsDialog({
    required this.notifications,
    required this.onTapNotification,
  });

  final List<NotificationDto> notifications;
  final ValueChanged<NotificationDto> onTapNotification;

  String _timeAgo(DateTime date) {
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Notificaciones'),
      content: SizedBox(
        width: 520,
        child: notifications.isEmpty
            ? const Text('No tienes notificaciones nuevas.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final NotificationDto notification = notifications[index];
                  final String subtitle;
                  if (notification.type == 'like') {
                    subtitle = '${notification.actorName} dio like';
                  } else if (notification.type == 'comment' &&
                      (notification.commentText?.trim().isNotEmpty ?? false)) {
                    subtitle = notification.commentText!.trim();
                  } else {
                    subtitle = 'Nuevo mensaje';
                  }
                  return ListTile(
                    tileColor: notification.unread
                        ? Colors.blue.withValues(alpha: 0.08)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: CircleAvatar(
                      child: Text(
                        notification.actorName.isEmpty
                            ? '?'
                            : notification.actorName.characters.first
                                  .toUpperCase(),
                      ),
                    ),
                    title: Text(
                      notification.type == 'like'
                          ? 'Nuevo like'
                          : notification.type == 'comment'
                          ? 'Nuevo comentario'
                          : 'Nuevo mensaje',
                    ),
                    subtitle: Text('$subtitle\n${_timeAgo(notification.createdAt)}'),
                    isThreeLine: true,
                    onTap: () => onTapNotification(notification),
                  );
                },
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

enum _SearchActionType { feedQuery, account, post }

class _SearchAction {
  const _SearchAction._({
    required this.type,
    this.query,
    this.account,
    this.postId,
  });

  factory _SearchAction.feedQuery(String query) =>
      _SearchAction._(type: _SearchActionType.feedQuery, query: query);

  factory _SearchAction.account(AccountSearchDto account) =>
      _SearchAction._(type: _SearchActionType.account, account: account);

  factory _SearchAction.post(FeedPostDto post) =>
      _SearchAction._(
        type: _SearchActionType.post,
        query: post.title,
        postId: post.id,
      );

  final _SearchActionType type;
  final String? query;
  final AccountSearchDto? account;
  final int? postId;
}

class _SearchDialog extends StatefulWidget {
  const _SearchDialog({required this.feedApi});

  final FeedApi feedApi;

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late final TabController _tabController;

  bool _loading = false;
  List<FeedPostDto> _posts = <FeedPostDto>[];
  List<AccountSearchDto> _accounts = <AccountSearchDto>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final String query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
    });
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.feedApi.fetchPosts(query: query),
        widget.feedApi.fetchAccounts(query: query),
      ]);
      if (!mounted) return;
      setState(() {
        _posts = results[0] as List<FeedPostDto>;
        _accounts = results[1] as List<AccountSearchDto>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 720,
        height: 620,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _runSearch(),
                      decoration: InputDecoration(
                        hintText: 'Busca cuentas o publicaciones',
                        suffixIcon: IconButton(
                          onPressed: _runSearch,
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_controller.text.trim().isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(_SearchAction.feedQuery(_controller.text.trim()));
                      },
                      child: const Text('Filtrar feed'),
                    ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const <Tab>[
                Tab(text: 'Publicaciones'),
                Tab(text: 'Cuentas'),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: <Widget>[
                        _posts.isEmpty
                            ? const Center(
                                child: Text('No encontramos publicaciones.'),
                              )
                            : ListView.separated(
                                itemCount: _posts.length,
                                separatorBuilder: (_, _) => const Divider(),
                                itemBuilder: (context, index) {
                                  final FeedPostDto post = _posts[index];
                                  return ListTile(
                                    title: Text(post.title),
                                    subtitle: Text(
                                      post.publicName.isNotEmpty
                                          ? post.publicName
                                          : post.artistName,
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                    ),
                                    onTap: () => Navigator.of(
                                      context,
                                    ).pop(_SearchAction.post(post)),
                                  );
                                },
                              ),
                        _accounts.isEmpty
                            ? const Center(
                                child: Text('No encontramos cuentas.'),
                              )
                            : ListView.separated(
                                itemCount: _accounts.length,
                                separatorBuilder: (_, _) => const Divider(),
                                itemBuilder: (context, index) {
                                  final AccountSearchDto account =
                                      _accounts[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage:
                                          account.photoUrl?.trim().isNotEmpty ==
                                              true
                                          ? NetworkImage(account.photoUrl!)
                                          : null,
                                      child:
                                          account.photoUrl?.trim().isNotEmpty ==
                                              true
                                          ? null
                                          : Text(
                                              account.publicName.isEmpty
                                                  ? account.username
                                                        .characters
                                                        .first
                                                        .toUpperCase()
                                                  : account.publicName
                                                        .characters
                                                        .first
                                                        .toUpperCase(),
                                            ),
                                    ),
                                    title: Text(
                                      account.publicName.isNotEmpty
                                          ? account.publicName
                                          : account.username,
                                    ),
                                    subtitle: Text('@${account.username}'),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                    ),
                                    onTap: () => Navigator.of(
                                      context,
                                    ).pop(_SearchAction.account(account)),
                                  );
                                },
                              ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

