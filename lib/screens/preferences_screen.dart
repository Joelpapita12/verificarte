import 'package:flutter/material.dart';

import '../services/auth_api.dart';
import '../services/current_user_store.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  static const String routeName = '/preferences';

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final AuthApi _authApi = AuthApi();
  bool _loading = true;
  bool _saving = false;
  String _preference = 'todo';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final pref = await _authApi.fetchContentPreference(userId: userId);
    if (!mounted) return;
    setState(() {
      _preference = pref;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) return;
    setState(() => _saving = true);
    final result = await _authApi.saveContentPreference(
      userId: userId,
      preference: _preference,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? 'Preferencias guardadas'
              : (result.message ?? 'No se pudo guardar'),
        ),
      ),
    );
  }

  Widget _tile({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _preference == value;
    return ListTile(
      onTap: () => setState(() => _preference = value),
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preferencias de contenido')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _tile(
                        value: 'todo',
                        title: 'Mostrar todo el contenido',
                        subtitle:
                            'Incluye contenido para todas las edades y +18.',
                      ),
                      _tile(
                        value: 'sin_18',
                        title: 'Excluir contenido +18',
                        subtitle: 'Oculta publicaciones marcadas como +18.',
                      ),
                      _tile(
                        value: 'solo_18',
                        title: 'Mostrar solo contenido +18',
                        subtitle: 'Solo se mostrarán publicaciones +18.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Contenido +18: contenido sexual o sugestivo, gore o no deseado a la vista.',
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Guardando...' : 'Guardar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

