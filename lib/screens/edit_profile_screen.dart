import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/auth_api.dart';
import '../services/current_user_store.dart';
import '../services/feed_api.dart';
import '../services/local_image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  static const routeName = '/editar-perfil';

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthApi _authApi = AuthApi();
  final FeedApi _feedApi = FeedApi();
  final _formKey = GlobalKey<FormState>();
  final _publicNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linksController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _photoUrl;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _publicNameController.dispose();
    _descriptionController.dispose();
    _linksController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    final result = await _authApi.fetchMe(userId: userId);
    if (result.ok && result.profile != null) {
      _publicNameController.text = result.profile!.publicName;
      _descriptionController.text = result.profile!.description;
      _photoUrl = result.profile!.photoUrl.trim().isEmpty
          ? null
          : result.profile!.photoUrl;
      CurrentUserStore.setProfile(
        publicName: result.profile!.publicName,
        photoUrl: _photoUrl,
      );
      // Cargar enlaces externos desde perfilartista (separado para no romper login)
      final links = await _authApi.fetchExternalLinks(userId: userId);
      _linksController.text = links ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    final selected = await pickLocalImage();
    if (selected == null) return;
    try {
      final url = await _feedApi.uploadPostImage(
        bytes: selected.bytes,
        fileName: selected.fileName,
      );
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _pickedImageBytes = selected.bytes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto cargada. Presiona "Guardar cambios".')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _save() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final result = await _authApi.updateProfile(
      userId: userId,
      publicName: _publicNameController.text.trim(),
      description: _descriptionController.text.trim(),
      photoUrl: _photoUrl,
      externalLinks: _linksController.text.trim().isEmpty
          ? null
          : _linksController.text.trim(),
    );
    setState(() => _saving = false);

    if (!mounted) return;
    if (result.ok) {
      CurrentUserStore.setProfile(
        publicName: _publicNameController.text.trim(),
        photoUrl: _photoUrl,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? 'Perfil actualizado'
              : (result.message ?? 'No se pudo guardar'),
        ),
      ),
    );
    if (result.ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 42,
                backgroundImage: _pickedImageBytes != null
                    ? MemoryImage(_pickedImageBytes!) as ImageProvider
                    : _photoUrl != null
                        ? NetworkImage(_photoUrl!)
                        : null,
                child: _pickedImageBytes == null && _photoUrl == null
                    ? const Icon(Icons.person, size: 42)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: OutlinedButton(
                onPressed: _pickPhoto,
                child: const Text('Cambiar foto'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _publicNameController,
              decoration: const InputDecoration(labelText: 'Nombre público'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _linksController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Redes sociales / enlaces',
                hintText: 'Instagram: @usuario\nTikTok: @usuario\nhttps://tusitio.com',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}

