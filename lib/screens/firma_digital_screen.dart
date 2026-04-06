import 'package:flutter/material.dart';

import '../services/current_user_store.dart';
import '../services/feed_api.dart';
import '../services/local_image_picker.dart';

class FirmaDigitalScreen extends StatefulWidget {
  const FirmaDigitalScreen({super.key});

  static const String routeName = '/firma-digital';

  @override
  State<FirmaDigitalScreen> createState() => _FirmaDigitalScreenState();
}

class _FirmaDigitalScreenState extends State<FirmaDigitalScreen> {
  final FeedApi _feedApi = FeedApi();

  bool _loading = true;
  bool _hasSignature = false;
  String? _fileName;
  String? _updatedAt;

  @override
  void initState() {
    super.initState();
    _loadSignature();
  }

  Future<void> _loadSignature() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      final data = await _feedApi.getMySignature(userId: userId);
      if (!mounted) return;
      setState(() {
        _hasSignature = data.hasSignature;
        _fileName = data.fileName;
        _updatedAt = data.updatedAt;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasSignature = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadSignature() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    final image = await pickLocalImage();
    if (image == null) return;
    try {
      await _feedApi.uploadUserSignature(
        userId: userId,
        bytes: image.bytes,
        fileName: image.fileName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Firma digital guardada')));
      await _loadSignature();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la firma: $e')),
      );
    }
  }

  Future<void> _deleteSignature() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    try {
      await _feedApi.deleteMySignature(userId: userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Firma digital eliminada')));
      await _loadSignature();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la firma: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis firmas')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Firma digital registrada',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (_hasSignature) ...[
                    Text('Archivo: ${_fileName ?? "N/D"}'),
                    Text('Actualizada: ${_updatedAt ?? "N/D"}'),
                  ] else
                    const Text('No tienes firma registrada'),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _uploadSignature,
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          _hasSignature ? 'Subir otra firma' : 'Subir firma',
                        ),
                      ),
                      if (_hasSignature)
                        OutlinedButton.icon(
                          onPressed: _deleteSignature,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Eliminar firma'),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
