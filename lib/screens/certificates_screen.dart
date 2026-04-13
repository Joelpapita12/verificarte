import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/api_models.dart';
import '../services/auth_api.dart';
import '../services/current_user_store.dart';
import '../services/file_download.dart';
import '../services/feed_api.dart';
import '../utils/certificate_pdf.dart';
import '../widgets/certificate_template_view.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  static const String routeName = '/certificados';

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final FeedApi _feedApi = FeedApi();
  final AuthApi _authApi = AuthApi();
  final Map<int, GlobalKey> _certificateKeys = <int, GlobalKey>{};
  final Map<int, bool> _isDownloading = <int, bool>{};
  final Map<int, bool> _isPrinting = <int, bool>{};

  bool _loading = true;
  String? _transferCode;
  List<MyCertificateDto> _certificates = <MyCertificateDto>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _certificates = <MyCertificateDto>[];
        });
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final me = await _authApi.fetchMe(userId: userId);
      final certs = await _feedApi.fetchMyCertificates(userId: userId);
      if (!mounted) return;

      final keys = <int, GlobalKey>{};
      final downloading = <int, bool>{};
      final printing = <int, bool>{};
      for (final certificate in certs) {
        keys[certificate.certificateId] =
            _certificateKeys[certificate.certificateId] ?? GlobalKey();
        downloading[certificate.certificateId] =
            _isDownloading[certificate.certificateId] ?? false;
        printing[certificate.certificateId] =
            _isPrinting[certificate.certificateId] ?? false;
      }

      setState(() {
        _transferCode = me.profile?.transferCode;
        _certificates = certs;
        _certificateKeys
          ..clear()
          ..addAll(keys);
        _isDownloading
          ..clear()
          ..addAll(downloading);
        _isPrinting
          ..clear()
          ..addAll(printing);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _downloadCertificate(MyCertificateDto certificate) async {
    final key = _certificateKeys[certificate.certificateId];
    if (key == null) return;

    setState(() => _isDownloading[certificate.certificateId] = true);
    try {
      final pdfBytes = await buildCertificatePdfFromBoundary(key);
      downloadFile(
        pdfBytes,
        'certificado-${certificate.certificateId}-${certificate.edicionLabel.replaceAll('/', '-')}.pdf',
        'application/pdf',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ocurrió un error al generar el PDF. Por favor, inténtalo de nuevo.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading[certificate.certificateId] = false);
      }
    }
  }

  Future<void> _printCertificate(MyCertificateDto certificate) async {
    final key = _certificateKeys[certificate.certificateId];
    if (key == null) return;

    setState(() => _isPrinting[certificate.certificateId] = true);
    try {
      final pdfBytes = await buildCertificatePdfFromBoundary(key);
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ocurrió un error al imprimir. Por favor, inténtalo de nuevo.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPrinting[certificate.certificateId] = false);
      }
    }
  }

  CertificateTemplateData _templateDataFor(MyCertificateDto certificate) {
    final artistDisplayName =
        (certificate.artistName ?? certificate.artistPublicName).trim().isEmpty
        ? certificate.artistUsername
        : (certificate.artistName ?? certificate.artistPublicName);

    final technique = (certificate.tecnicaMateriales ?? '').trim();
    final dimensions = (certificate.dimensions ?? '').trim();
    final qrValue = (certificate.qrCode ?? '').trim();
    final registrationTimestamp = (certificate.registrationTimestamp ?? '')
        .trim();
    final certificateTimestamp = (certificate.certificateCreatedAt ?? '').trim();
    final certificateSignature = (certificate.certificateSignatureB64 ?? '')
        .trim();
    final signatureHash = (certificate.signatureHash ?? '').trim();
    final encryptedSignature = (certificate.signatureEncrypted ?? '').trim();
    final artworkHash = (certificate.artworkHash ?? '').trim();

    return CertificateTemplateData(
      title: certificate.postTitle,
      artistName: artistDisplayName,
      technique: technique.isEmpty ? '-' : technique,
      dimensions: dimensions.isEmpty ? '-' : dimensions,
      creationDate: certificate.creationYear?.toString() ?? '-',
      editionLabel: certificate.edicionLabel,
      issueDate: certificate.createdAt.toLocal().toString().substring(0, 19),
      digitalSignature: certificateSignature.isNotEmpty
          ? certificateSignature
          : signatureHash.isNotEmpty
          ? signatureHash
          : encryptedSignature.isNotEmpty
          ? encryptedSignature
          : '-',
      artworkHash: artworkHash.isEmpty ? '-' : artworkHash,
      folio: '#${certificate.certificateId}',
      qrValue: qrValue.isEmpty ? '-' : qrValue,
      registrationTimestamp: registrationTimestamp.isEmpty
          ? '-'
          : registrationTimestamp,
      certificateTimestamp: certificateTimestamp.isEmpty
          ? '-'
          : certificateTimestamp,
      artImageUrl: certificate.postImageUrl,
      authorFullName: certificate.authorFullName,
      signatureImageUrl: certificate.signatureImageUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final transferCodeLabel = (_transferCode ?? '').trim().isEmpty
        ? 'No asignado.'
        : _transferCode!;

    return Scaffold(
      appBar: AppBar(title: const Text('Certificados')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2150),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Tu código: $transferCodeLabel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_certificates.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text('No tienes certificados activos.'),
                      ),
                    ),
                  ..._certificates.map((certificate) {
                    final key = _certificateKeys[certificate.certificateId];
                    final isDownloading =
                        _isDownloading[certificate.certificateId] == true;
                    final isPrinting =
                        _isPrinting[certificate.certificateId] == true;

                    return Card(
                      child: ExpansionTile(
                        title: Text(
                          certificate.postTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('Edición ${certificate.edicionLabel}'),
                        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        children: <Widget>[
                          Column(
                            children: <Widget>[
                              if (key != null)
                                RepaintBoundary(
                                  key: key,
                                  child: CertificateTemplateView(
                                    showDebugGrid: false,
                                    data: _templateDataFor(certificate),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: <Widget>[
                                  if (isPrinting)
                                    const CircularProgressIndicator()
                                  else
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _printCertificate(certificate),
                                      icon: const Icon(Icons.print_outlined),
                                      label: const Text('Imprimir'),
                                    ),
                                  if (isDownloading)
                                    const CircularProgressIndicator()
                                  else
                                    ElevatedButton(
                                      onPressed: () =>
                                          _downloadCertificate(certificate),
                                      child: const Text('Descargar PDF'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
