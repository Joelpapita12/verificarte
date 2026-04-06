import 'package:flutter/material.dart';

import '../models/api_models.dart';
import '../services/admin_api.dart';
import '../services/current_user_store.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  static const String routeName = '/admin-panel';

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final AdminApi _api = AdminApi();
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _postSearchController = TextEditingController();
  final TextEditingController _certificateOwnerSearchController =
      TextEditingController();
  final TextEditingController _certificateTargetSearchController =
      TextEditingController();

  DateTime? _fromDate;
  DateTime? _toDate;
  bool _loading = true;
  bool _loadingCertificates = false;
  bool _reassigningCertificate = false;

  List<AdminReportDto> _reports = [];
  List<AdminUserDto> _users = [];
  List<AdminPostDto> _posts = [];
  List<AdminActionDto> _actions = [];
  List<AdminUserDto> _certificateOwnerResults = [];
  List<AdminUserDto> _certificateTargetResults = [];
  List<MyCertificateDto> _ownerCertificates = [];

  AdminUserDto? _selectedCertificateOwner;
  AdminUserDto? _selectedCertificateTarget;
  MyCertificateDto? _selectedCertificate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    _postSearchController.dispose();
    _certificateOwnerSearchController.dispose();
    _certificateTargetSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    var reports = <AdminReportDto>[];
    var users = <AdminUserDto>[];
    var posts = <AdminPostDto>[];
    var actions = <AdminActionDto>[];
    try {
      try {
        reports = await _api.fetchReports(userId: userId);
      } catch (_) {}
      try {
        users = await _api.fetchUsers(
          userId: userId,
          query: _userSearchController.text.trim(),
        );
      } catch (_) {}
      try {
        posts = await _api.fetchPosts(
          userId: userId,
          query: _postSearchController.text.trim(),
          fromDate: _fromDate,
          toDate: _toDate,
        );
      } catch (_) {}
      try {
        actions = await _api.fetchActions(userId: userId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _users = users;
        _posts = posts;
        _actions = actions;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchCertificateOwners() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    if (!mounted) return;
    setState(() => _loadingCertificates = true);
    try {
      final users = await _api.fetchUsers(
        userId: userId,
        query: _certificateOwnerSearchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _certificateOwnerResults = users;
      });
    } finally {
      if (mounted) setState(() => _loadingCertificates = false);
    }
  }

  Future<void> _searchCertificateTargets() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    if (!mounted) return;
    setState(() => _loadingCertificates = true);
    try {
      final users = await _api.fetchUsers(
        userId: userId,
        query: _certificateTargetSearchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _certificateTargetResults = users;
      });
    } finally {
      if (mounted) setState(() => _loadingCertificates = false);
    }
  }

  Future<void> _selectCertificateOwner(AdminUserDto user) async {
    final adminUserId = CurrentUserStore.userId;
    if (adminUserId == null) return;
    if (!mounted) return;
    setState(() {
      _selectedCertificateOwner = user;
      _selectedCertificate = null;
      _ownerCertificates = [];
      _loadingCertificates = true;
    });
    try {
      final certificates = await _api.fetchCertificatesByOwner(
        userId: adminUserId,
        ownerUserId: user.id,
      );
      if (!mounted) return;
      setState(() {
        _ownerCertificates = certificates;
      });
    } finally {
      if (mounted) setState(() => _loadingCertificates = false);
    }
  }

  Future<void> _reassignCertificate() async {
    final adminUserId = CurrentUserStore.userId;
    final certificate = _selectedCertificate;
    final target = _selectedCertificateTarget;
    final source = _selectedCertificateOwner;
    if (adminUserId == null ||
        certificate == null ||
        target == null ||
        source == null) {
      return;
    }
    if (!mounted) return;
    setState(() => _reassigningCertificate = true);
    try {
      await _api.reassignCertificate(
        userId: adminUserId,
        certificateId: certificate.certificateId,
        targetUserId: target.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Certificado ${certificate.edicionLabel} reasignado a @${target.username}',
          ),
        ),
      );
      await _selectCertificateOwner(source);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _reassigningCertificate = false);
    }
  }

  Future<void> _resolve(AdminReportDto report, String status) async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    await _api.resolveReport(
      userId: userId,
      reportId: report.id,
      status: status,
    );
    await _load();
  }

  Future<void> _strike(AdminReportDto report) async {
    final userId = CurrentUserStore.userId;
    if (userId == null || report.artistId == null) return;
    final result = await _api.addStrike(
      userId: userId,
      targetUserId: report.artistId!,
      postId: report.postId,
      reason: 'Strike por denuncia: ${report.type}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Strike nivel ${result.level} aplicado')),
    );
    await _load();
  }

  void _openReporterChat(AdminReportDto report) {
    if (report.reporterId == null) return;
    Navigator.of(context).pushNamed('/chats', arguments: report.reporterId);
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _fromDate = picked);
    await _load();
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _toDate = picked);
    await _load();
  }

  Future<void> _deletePost(AdminPostDto post) async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    await _api.deletePost(
      userId: userId,
      postId: post.id,
      reason: 'Eliminada por administrador',
    );
    await _load();
  }

  Future<void> _deleteUser(AdminUserDto user) async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    await _api.deleteUser(
      userId: userId,
      targetUserId: user.id,
      reason: 'Eliminada por administrador',
    );
    await _load();
  }

  Future<void> _suspendUser(AdminUserDto user, String mode) async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    await _api.suspendUser(
      userId: userId,
      targetUserId: user.id,
      mode: mode,
      reason: 'Suspensión aplicada por administrador',
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = CurrentUserStore.role == 'administrador';
    if (!isAdmin) {
      return const Scaffold(body: Center(child: Text('No autorizado')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Panel administrador')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 5,
              child: Column(
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Denuncias'),
                      Tab(text: 'Usuarios'),
                      Tab(text: 'Publicaciones'),
                      Tab(text: 'Certificados'),
                      Tab(text: 'Historial'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _reportsTab(),
                        _usersTab(),
                        _postsTab(),
                        _certificatesTab(),
                        _actionsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _reportsTab() {
    if (_reports.isEmpty) {
      return const Center(child: Text('Sin denuncias'));
    }
    return ListView.builder(
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final r = _reports[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ' - denunciante: @ · denunciado: @',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(r.postTitle),
                if (r.description.trim().isNotEmpty) ...[
                  Text(r.description),
                  const SizedBox(height: 4),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _resolve(r, 'revisada'),
                      child: const Text('Marcar revisada'),
                    ),
                    OutlinedButton(
                      onPressed: () => _resolve(r, 'rechazada'),
                      child: const Text('Rechazar'),
                    ),
                    ElevatedButton(
                      onPressed: r.artistId == null ? null : () => _strike(r),
                      child: const Text('Aplicar strike'),
                    ),
                    OutlinedButton(
                      onPressed: r.reporterId == null
                          ? null
                          : () => _openReporterChat(r),
                      child: const Text('Abrir chat denunciante'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _usersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userSearchController,
                  decoration: const InputDecoration(
                    hintText: 'Buscar usuario por nombre, correo o código',
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _load, child: const Text('Buscar')),
            ],
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? const Center(child: Text('Sin usuarios para este filtro'))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final u = _users[index];
                    return ListTile(
                      title: Text('${u.publicName} (@${u.username})'),
                      subtitle: Text(
                        '${u.email} ? ${u.role} ? ${u.accountStatus}\n'
                        'C?digo: ${u.transferCode.trim().isEmpty ? '-' : u.transferCode}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'week') _suspendUser(u, 'week');
                          if (value == 'month') _suspendUser(u, 'month');
                          if (value == 'indefinite') {
                            _suspendUser(u, 'indefinite');
                          }
                          if (value == 'active') _suspendUser(u, 'active');
                          if (value == 'delete') _deleteUser(u);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'week',
                            child: Text('Suspender 1 semana'),
                          ),
                          PopupMenuItem(
                            value: 'month',
                            child: Text('Suspender 1 mes'),
                          ),
                          PopupMenuItem(
                            value: 'indefinite',
                            child: Text('Suspender indefinido'),
                          ),
                          PopupMenuItem(
                            value: 'active',
                            child: Text('Activar cuenta'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar cuenta'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _postsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _postSearchController,
                      decoration: const InputDecoration(
                        hintText: 'Buscar publicación o cuenta',
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _load, child: const Text('Buscar')),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _pickFromDate,
                    child: Text(
                      _fromDate == null
                          ? 'Desde fecha'
                          : 'Desde ${_fromDate!.toIso8601String().substring(0, 10)}',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _pickToDate,
                    child: Text(
                      _toDate == null
                          ? 'Hasta fecha'
                          : 'Hasta ${_toDate!.toIso8601String().substring(0, 10)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _fromDate = null;
                        _toDate = null;
                      });
                      _load();
                    },
                    child: const Text('Limpiar fechas'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _posts.isEmpty
              ? const Center(child: Text('Sin publicaciones para este filtro'))
              : ListView.builder(
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final p = _posts[index];
                    return ListTile(
                      title: Text(p.title),
                      subtitle: Text(
                        '@ · ',
                      ),
                      trailing: OutlinedButton(
                        onPressed: p.active ? () => _deletePost(p) : null,
                        child: const Text('Eliminar'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _certificatesTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Reasignación de certificados',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _certificateOwnerSearchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar cuenta origen',
                  hintText: 'Nombre de usuario, nombre público o correo',
                ),
                onSubmitted: (_) => _searchCertificateOwners(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _searchCertificateOwners,
              child: const Text('Buscar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_certificateOwnerResults.isNotEmpty) ...[
          const Text('Resultados de cuenta origen'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _certificateOwnerResults
                .map(
                  (user) => ChoiceChip(
                    label: Text('${user.publicName} (@${user.username})'),
                    selected: _selectedCertificateOwner?.id == user.id,
                    onSelected: (_) => _selectCertificateOwner(user),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (_selectedCertificateOwner != null)
          Text(
            'Certificados de ${_selectedCertificateOwner!.publicName} (@${_selectedCertificateOwner!.username})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        if (_loadingCertificates)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_selectedCertificateOwner != null &&
            _ownerCertificates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Esta cuenta no tiene certificados activos.'),
          ),
        ..._ownerCertificates.map((certificate) {
          final isSelected =
              _selectedCertificate?.certificateId == certificate.certificateId;
          return Card(
            child: ListTile(
              onTap: () {
                setState(() => _selectedCertificate = certificate);
              },
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(certificate.postTitle),
              subtitle: Text(
                'Edición  · Folio # · Propietario actual #',
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _certificateTargetSearchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar cuenta destino',
                  hintText: 'Nombre de usuario, nombre público o correo',
                ),
                onSubmitted: (_) => _searchCertificateTargets(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _searchCertificateTargets,
              child: const Text('Buscar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_certificateTargetResults.isNotEmpty) ...[
          const Text('Resultados de cuenta destino'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _certificateTargetResults
                .map(
                  (user) => ChoiceChip(
                    label: Text('${user.publicName} (@${user.username})'),
                    selected: _selectedCertificateTarget?.id == user.id,
                    onSelected: (_) {
                      setState(() => _selectedCertificateTarget = user);
                    },
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed:
                _reassigningCertificate ||
                    _selectedCertificate == null ||
                    _selectedCertificateTarget == null
                ? null
                : _reassignCertificate,
            child: Text(
              _reassigningCertificate
                  ? 'Reasignando...'
                  : 'Reasignar certificado',
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionsTab() {
    if (_actions.isEmpty) {
      return const Center(child: Text('Sin acciones registradas'));
    }
    return ListView.separated(
      itemCount: _actions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final a = _actions[index];
        final objetivo = (a.targetUser ?? '').trim();
        final objetivoText = objetivo.isEmpty ? '' : ' ? Objetivo: @$objetivo';
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(a.type),
          subtitle: Text(
            'Admin: @${a.adminUser}$objetivoText\n'
            '${a.detail}\n'
            '${a.createdAt.toLocal()}',
          ),
          isThreeLine: true,
        );
      },
    );
  }
}

