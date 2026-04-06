import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/current_user_store.dart';
import '../services/feed_api.dart';
import '../services/local_image_picker.dart';
import '../theme/app_colors.dart';

class CreatePostFlowScreen extends StatefulWidget {
  const CreatePostFlowScreen({super.key});

  static const String routeName = '/create-post';

  @override
  State<CreatePostFlowScreen> createState() => _CreatePostFlowScreenState();
}

class _CreatePostFlowScreenState extends State<CreatePostFlowScreen> {
  final _feedApi = FeedApi();
  bool get _isAdmin => (CurrentUserStore.role ?? '') == 'administrador';
  bool get _canPublish {
    final role = (CurrentUserStore.role ?? '').trim();
    return role == 'artista' || role == 'administrador';
  }

  int _step = 0;
  bool _publishing = false;
  bool _checkingSignature = true;
  bool _hasStoredSignature = false;

  final _tituloObraController = TextEditingController();
  final _tecnicaController = TextEditingController();
  final _anioController = TextEditingController();
  final _dimensionesController = TextEditingController();
  final _descripcionCortaController = TextEditingController();

  String _estadoObra = 'disponible';
  bool _esMayor18 = false;
  final _propietarioCuentaController = TextEditingController();
  bool _propietarioAnonimo = false;

  final _nombreAutorController = TextEditingController();
  final _pseudonimoController = TextEditingController();
  final _edicionController = TextEditingController();
  final _declaracionController = TextEditingController();

  final List<Uint8List> _fotosObraBytes = [];
  final List<String> _fotosObraNames = [];

  Uint8List? _firmaBytes;
  String? _firmaName;

  @override
  void initState() {
    super.initState();
    if (_canPublish) {
      _loadSignatureStatus();
    } else {
      _checkingSignature = false;
    }
  }

  @override
  void dispose() {
    _tituloObraController.dispose();
    _tecnicaController.dispose();
    _anioController.dispose();
    _dimensionesController.dispose();
    _descripcionCortaController.dispose();
    _propietarioCuentaController.dispose();
    _nombreAutorController.dispose();
    _pseudonimoController.dispose();
    _edicionController.dispose();
    _declaracionController.dispose();
    super.dispose();
  }

  Future<void> _pickFotoObra() async {
    final image = await pickLocalImage();
    if (image == null) return;
    setState(() {
      _fotosObraBytes.add(image.bytes);
      _fotosObraNames.add(image.fileName);
    });
  }

  Future<void> _pickFirmaDigital() async {
    final image = await pickLocalImage();
    if (image == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se seleccionó ninguna imagen de firma'),
        ),
      );
      return;
    }
    setState(() {
      _firmaBytes = image.bytes;
      _firmaName = image.fileName;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Firma seleccionada: ${image.fileName}')),
    );
  }

  bool _validateStepObra() {
    final anio = int.tryParse(_anioController.text.trim());
    final obraConPropietario = _estadoObra == 'con_propietario';
    final propietarioOk =
        !obraConPropietario ||
        _propietarioAnonimo ||
        _propietarioCuentaController.text.trim().isNotEmpty;

    return _tituloObraController.text.trim().isNotEmpty &&
        _tecnicaController.text.trim().isNotEmpty &&
        anio != null &&
        anio > 0 &&
        _dimensionesController.text.trim().isNotEmpty &&
        _descripcionCortaController.text.trim().isNotEmpty &&
        propietarioOk;
  }

  bool _validateStepCertificado() {
    if (_isAdmin) return true;
    final signatureOk = _hasStoredSignature || _firmaBytes != null;
    return _nombreAutorController.text.trim().isNotEmpty &&
        _declaracionController.text.trim().isNotEmpty &&
        signatureOk;
  }

  Future<void> _loadSignatureStatus() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) {
      setState(() {
        _checkingSignature = false;
      });
      return;
    }
    try {
      final hasSignature = await _feedApi.hasUserSignature(userId: userId);
      if (!mounted) return;
      setState(() {
        _hasStoredSignature = hasSignature;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasStoredSignature = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingSignature = false;
        });
      }
    }
  }

  Future<void> _publish() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para publicar')),
      );
      return;
    }

    setState(() {
      _publishing = true;
    });

    try {
      final uploadedImageUrls = <String>[];
      for (var i = 0; i < _fotosObraBytes.length; i += 1) {
        final imageUrl = await _feedApi.uploadPostImage(
          bytes: _fotosObraBytes[i],
          fileName: _fotosObraNames[i],
        );
        if (imageUrl.trim().isNotEmpty) {
          uploadedImageUrls.add(imageUrl.trim());
        }
      }
      final fotoObraUrl = uploadedImageUrls.isEmpty
          ? null
          : uploadedImageUrls.first;

      if (!_isAdmin && !_hasStoredSignature && _firmaBytes != null) {
        await _feedApi.uploadUserSignature(
          userId: userId,
          bytes: _firmaBytes!,
          fileName: _firmaName ?? 'firma.png',
        );
      }

      final nombreAutor = _isAdmin
          ? (_nombreAutorController.text.trim().isEmpty
                ? 'Administrador VerificArte'
                : _nombreAutorController.text.trim())
          : _nombreAutorController.text.trim();
      final declaracion = _isAdmin
          ? (_declaracionController.text.trim().isEmpty
                ? 'Publicación administrativa'
                : _declaracionController.text.trim())
          : _declaracionController.text.trim();

      await _feedApi.createPost(
        artistId: userId,
        title: _tituloObraController.text.trim(),
        description: _descripcionCortaController.text.trim(),
        imageUrl: fotoObraUrl,
        imageUrls: uploadedImageUrls,
        tecnicaMateriales: _tecnicaController.text.trim(),
        anioCreacion: int.parse(_anioController.text.trim()),
        dimensiones: _dimensionesController.text.trim(),
        estadoObra: _estadoObra,
        esMayor18: _esMayor18,
        propietarioCuenta: _propietarioCuentaController.text.trim().isEmpty
            ? null
            : _propietarioCuentaController.text.trim(),
        propietarioAnonimo: _propietarioAnonimo,
        nombreAutorCompleto: nombreAutor,
        pseudonimo: _pseudonimoController.text.trim().isEmpty
            ? null
            : _pseudonimoController.text.trim(),
        edicion: _edicionController.text.trim().isEmpty
            ? null
            : _edicionController.text.trim(),
        declaracionAutenticidad: declaracion,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceFirst('Exception: ', '').trim();
      final message = raw.isEmpty ? 'No se pudo publicar la obra.' : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canPublish) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subir obra')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Solo las cuentas de artista o administrador pueden publicar obras.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step == 0
              ? 'Publicar nueva obra'
              : _step == 1
              ? 'Crear certificado'
              : 'Revisi\u00f3n de datos',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _step == 0
            ? _buildStepObra()
            : _step == 1
            ? _buildStepCertificado()
            : _buildStepRevision(),
      ),
    );
  }

  Widget _buildStepObra() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _pickFotoObra,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Agregar imagen de la obra (opcional)'),
        ),
        if (_fotosObraNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Imágenes seleccionadas: ${_fotosObraNames.length}'),
        ],
        if (_fotosObraBytes.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _fotosObraBytes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _fotosObraBytes[index],
                        width: 150,
                        height: 118,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _fotosObraBytes.removeAt(index);
                            _fotosObraNames.removeAt(index);
                          });
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black54,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _tituloObraController,
          decoration: const InputDecoration(labelText: 'T\u00edtulo de la obra'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tecnicaController,
          decoration: const InputDecoration(
            labelText: 'T\u00e9cnica o materiales',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _anioController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'A\u00f1o de creaci\u00f3n'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dimensionesController,
          decoration: const InputDecoration(labelText: 'Dimensiones'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descripcionCortaController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Descripci\u00f3n corta'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _estadoObra,
          decoration: const InputDecoration(labelText: 'Estado de la obra'),
          items: const [
            DropdownMenuItem(value: 'disponible', child: Text('Disponible')),
            DropdownMenuItem(
              value: 'con_propietario',
              child: Text('Con propietario'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _estadoObra = value;
            });
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _esMayor18,
          onChanged: (value) {
            setState(() {
              _esMayor18 = value;
            });
          },
          title: const Text('Tu contenido es +18'),
          subtitle: const Text(
            'El contenido +18 abarca contenido sexual o sugestivo, gore o contenido no deseado a la vista.',
          ),
        ),
        if (_estadoObra == 'con_propietario') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _propietarioCuentaController,
            decoration: const InputDecoration(
              labelText: 'Nombre de cuenta del propietario',
            ),
          ),
          SwitchListTile(
            value: _propietarioAnonimo,
            onChanged: (value) {
              setState(() {
                _propietarioAnonimo = value;
              });
            },
            title: const Text('Mostrar propietario como an\u00f3nimo'),
          ),
        ],
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: () {
            if (!_validateStepObra()) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Completa t\u00edtulo, t\u00e9cnica, a\u00f1o, dimensiones y descripci\u00f3n',
                  ),
                ),
              );
              return;
            }
            if (_isAdmin) {
              _publish();
              return;
            }
            setState(() {
              _step = 1;
            });
          },
          child: Text(_isAdmin ? 'Publicar' : 'Ir a certificado'),
        ),
      ],
    );
  }

  Widget _buildStepCertificado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nombreAutorController,
          decoration: const InputDecoration(
            labelText: 'Nombre del autor (completo)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pseudonimoController,
          decoration: const InputDecoration(labelText: 'Pseud\u00f3nimo'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _edicionController,
          decoration: const InputDecoration(labelText: 'Edici\u00f3n (x/y)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _declaracionController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Declaraci\u00f3n de autenticidad',
          ),
        ),
        const SizedBox(height: 12),
        if (_checkingSignature)
          const LinearProgressIndicator()
        else ...[
          if (_hasStoredSignature)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Text(
                'Ya tienes firma digital registrada. Se usar\u00e1 autom\u00e1ticamente.',
              ),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: _pickFirmaDigital,
              icon: const Icon(Icons.brush_outlined),
              label: const Text(
                'Subir firma digital (obligatoria primera vez)',
              ),
            ),
            if (_firmaName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Firma: $_firmaName (${_firmaBytes?.lengthInBytes ?? 0} bytes)',
              ),
            ],
          ],
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _step = 0;
                  });
                },
                child: const Text('Regresar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (!_validateStepCertificado()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Completa datos del certificado y registra firma digital',
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _step = 2;
                  });
                },
                child: const Text('Revisi\u00f3n de datos'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepRevision() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reviewCard('T\u00edtulo obra', _tituloObraController.text.trim()),
        _reviewCard('T\u00e9cnica o materiales', _tecnicaController.text.trim()),
        _reviewCard('A\u00f1o de creaci\u00f3n', _anioController.text.trim()),
        _reviewCard('Dimensiones', _dimensionesController.text.trim()),
        _reviewCard(
          'Descripci\u00f3n corta',
          _descripcionCortaController.text.trim(),
        ),
        _reviewCard('Estado de la obra', _estadoObra),
        _reviewCard('Contenido +18', _esMayor18 ? 'Si' : 'No'),
        if (_estadoObra == 'con_propietario')
          _reviewCard(
            'Propietario',
            _propietarioAnonimo
                ? 'An\u00f3nimo'
                : _propietarioCuentaController.text.trim(),
          ),
        _reviewCard('Nombre autor', _nombreAutorController.text.trim()),
        _reviewCard('Pseud\u00f3nimo', _pseudonimoController.text.trim()),
        _reviewCard('Edici\u00f3n', _edicionController.text.trim()),
        _reviewCard('Declaraci\u00f3n', _declaracionController.text.trim()),
        const SizedBox(height: 16),
        const Text(
          'Foto de la obra con marca de agua',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.deepNavy,
          ),
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 1.2,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.mistBlue),
              color: AppColors.softWhite,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_fotosObraBytes.isNotEmpty)
                  PageView.builder(
                    itemCount: _fotosObraBytes.length,
                    itemBuilder: (_, index) =>
                        Image.memory(_fotosObraBytes[index], fit: BoxFit.cover),
                  )
                else
                  const Center(
                    child: Text(
                      'Sin foto de obra',
                      style: TextStyle(color: AppColors.slateBlue),
                    ),
                  ),
                IgnorePointer(
                  child: Opacity(
                    opacity: 0.28,
                      child:
// Optimización: para mejorar el rendimiento, la imagen
// 'marcaagua.png' debe tener un tamaño preajustado
// (por ejemplo, 512x512) y estar comprimida.
// Cargar imágenes grandes y redimensionarlas en la app
// consume memoria innecesaria.
                        Image.asset(
                      'assets/marcaagua.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _publishing
                    ? null
                    : () {
                        setState(() {
                          _step = 1;
                        });
                      },
                child: const Text('Regresar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _publishing ? null : _publish,
                child: Text(_publishing ? 'Publicando...' : 'Publicar'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reviewCard(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.mistBlue),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}



