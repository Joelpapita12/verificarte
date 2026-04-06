import 'package:flutter/material.dart';

import '../services/current_user_store.dart';
import '../services/feed_api.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  static const String routeName = '/reports';

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FeedApi _feedApi = FeedApi();
  final TextEditingController _descriptionController = TextEditingController();
  String _reasonType = 'obra_plagiada';
  bool _saving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para enviar denuncia')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _feedApi.createSupportReport(
        userId: userId,
        reasonType: _reasonType,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      _descriptionController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tu mensaje se ha enviado')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la denuncia')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Denuncias')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona el tipo de denuncia',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _reasonType,
                  items: const [
                    DropdownMenuItem(
                      value: 'obra_plagiada',
                      child: Text('Obra plagiada'),
                    ),
                    DropdownMenuItem(
                      value: 'contenido_no_deseado',
                      child: Text('Contenido no deseado o explícito'),
                    ),
                    DropdownMenuItem(value: 'otro', child: Text('Otro')),
                  ],
                  onChanged: (value) {
                    setState(() => _reasonType = value ?? 'obra_plagiada');
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Describe tu problema',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _send,
                    child: Text(_saving ? 'Enviando...' : 'Enviar denuncia'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

