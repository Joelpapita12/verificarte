import 'package:flutter/material.dart';

import '../models/api_models.dart';
import '../services/auth_api.dart';
import '../services/current_user_store.dart';
import '../services/feed_api.dart';

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  static const String routeName = '/transferencias';

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  final FeedApi _feedApi = FeedApi();
  final AuthApi _authApi = AuthApi();
  final TextEditingController _targetCodeController = TextEditingController();

  bool _loading = true;
  bool _verifying = false;
  bool _sending = false;
  String? _myCode;
  List<MyCertificateDto> _certificates = [];
  MyCertificateDto? _selected;
  TransferCodeUser? _targetUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _targetCodeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      final me = await _authApi.fetchMe(userId: userId);
      final certs = await _feedApi.fetchMyCertificates(userId: userId);
      if (!mounted) return;
      setState(() {
        _myCode = me.profile?.transferCode;
        _certificates = certs;
        if (_selected != null) {
          final matches = certs
              .where((e) => e.certificateId == _selected!.certificateId)
              .toList();
          _selected = matches.isEmpty ? null : matches.first;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _targetCodeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _verifying = true;
      _targetUser = null;
    });
    final result = await _authApi.resolveTransferCode(code: code);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _targetUser = result.user;
    });
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Código no válido')),
      );
    }
  }

  Future<void> _sendTransfer() async {
    final userId = CurrentUserStore.userId;
    if (userId == null || _selected == null || _targetUser == null) return;
    setState(() => _sending = true);
    try {
      await _feedApi.transferCertificate(
        userId: userId,
        postId: _selected!.postId,
        certificateId: _selected!.certificateId,
        editionId: _selected!.editionId,
        targetCode: _targetCodeController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Envío exitoso')));
      _targetCodeController.clear();
      setState(() {
        _targetUser = null;
        _selected = null;
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        !_sending &&
        _selected != null &&
        _targetUser != null &&
        _targetCodeController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Transferencias')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B2150),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tu código: ${(_myCode ?? '').trim().isEmpty ? 'No asignado' : _myCode}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Selecciona el certificado a transferir',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (_certificates.isEmpty)
                  const Text(
                    'No tienes certificados disponibles para transferir',
                  ),
                ..._certificates.map(
                  (c) => ListTile(
                    onTap: () => setState(() => _selected = c),
                    leading: Icon(
                      _selected?.certificateId == c.certificateId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text('${c.postTitle} • Edición ${c.edicionLabel}'),
                    subtitle: Text(
                      'Certificado ${c.numeroEdicion <= 0 ? 1 : c.numeroEdicion} de ${c.totalEdiciones <= 0 ? 1 : c.totalEdiciones}',
                    ),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),
                TextField(
                  controller: _targetCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Código de la otra persona',
                    hintText: 'Ejemplo: A1B2C3D4E5',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() => _targetUser = null),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _verifying ? null : _verifyCode,
                      child: Text(
                        _verifying ? 'Validando...' : 'Validar código',
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_targetUser != null)
                      Expanded(
                        child: Text(
                          'Destino: ${_targetUser!.publicName.isEmpty ? _targetUser!.username : _targetUser!.publicName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: canSend ? _sendTransfer : null,
                  child: Text(_sending ? 'Enviando...' : 'Enviar certificado'),
                ),
              ],
            ),
    );
  }
}

