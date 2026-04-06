import 'package:flutter/material.dart';

class CertificateTemplateData {
  const CertificateTemplateData({
    required this.title,
    required this.artistName,
    required this.technique,
    required this.dimensions,
    required this.creationDate,
    required this.editionLabel,
    required this.issueDate,
    required this.digitalSignature,
    required this.artworkHash,
    required this.folio,
    required this.qrValue,
    required this.registrationTimestamp,
    required this.certificateTimestamp,
    this.artImageUrl,
    this.authorFullName,
    this.signatureImageUrl,
  });

  final String title;
  final String artistName;
  final String technique;
  final String dimensions;
  final String creationDate;
  final String editionLabel;
  final String issueDate;
  final String digitalSignature;
  final String artworkHash;
  final String folio;
  final String qrValue;
  final String registrationTimestamp;
  final String certificateTimestamp;
  final String? artImageUrl;
  final String? authorFullName;
  final String? signatureImageUrl;
}

class CertificateTemplateView extends StatelessWidget {
  const CertificateTemplateView({
    super.key,
    required this.data,
    this.showDebugGrid = false,
  });

  final CertificateTemplateData data;
  final bool showDebugGrid;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1024 / 1448,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final textColor = const Color(0xFF1E2740);
          final fieldValueStyle = TextStyle(
            color: textColor,
            fontSize: w * 0.0186,
            fontWeight: FontWeight.w600,
            height: 1.0,
          );
          final cryptoStyle = TextStyle(
            color: textColor,
            fontSize: w * 0.0076,
            fontWeight: FontWeight.w600,
            height: 1.15,
          );
          final issueStyle = TextStyle(
            color: textColor,
            fontSize: w * 0.0171,
            fontWeight: FontWeight.w600,
          );
          final folioStyle = TextStyle(
            color: textColor,
            fontSize: w * 0.0148,
            fontWeight: FontWeight.w700,
            height: 1.0,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  // Critico para el rendimiento, sobre todo al generar PDFs.
                  // Asegurate de que 'certificado_template.png' este comprimida
                  child: Image.asset(
                    'assets/certificates/certificado_template.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) =>
                        Container(color: const Color(0xFFF6F3EA)),
                  ),
                ),
              ),
              if (showDebugGrid) ..._debugGrid(w, h),
              _field(
                left: w * 0.488,
                top: h * 0.431,
                width: w * 0.385,
                text: _safe(data.title),
                style: fieldValueStyle,
                textAlign: TextAlign.center,
              ),
              _field(
                left: w * 0.488,
                top: h * 0.466,
                width: w * 0.385,
                text: _safe(data.artistName),
                style: fieldValueStyle,
                textAlign: TextAlign.center,
              ),
              _field(
                left: w * 0.488,
                top: h * 0.501,
                width: w * 0.385,
                text: _safe(data.technique),
                style: fieldValueStyle,
                textAlign: TextAlign.center,
              ),
              _field(
                left: w * 0.488,
                top: h * 0.530,
                width: w * 0.385,
                text: _safe(data.dimensions),
                style: fieldValueStyle,
                textAlign: TextAlign.center,
              ),
              _field(
                left: w * 0.488,
                top: h * 0.559,
                width: w * 0.385,
                text: _safe(data.creationDate),
                style: fieldValueStyle,
                textAlign: TextAlign.center,
              ),
              _field(
                left: w * 0.488,
                top: h * 0.594,
                width: w * 0.385,
                text: _safe(data.editionLabel),
                style: fieldValueStyle,
                textAlign: TextAlign.center,
              ),
              Positioned(
                left: w * 0.558,
                top: h * 0.278,
                width: w * 0.282,
                height: h * 0.152,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: (data.artImageUrl ?? '').trim().isEmpty
                      ? Container(color: Colors.transparent)
                      : Container(
                          color: Colors.transparent,
                          alignment: Alignment.center,
                          child: Image.network(
                            data.artImageUrl!,
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
              ),
              Positioned(
                left: w * 0.178,
                top: h * 0.652,
                width: w * 0.242,
                height: h * 0.050,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: (data.signatureImageUrl ?? '').trim().isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                          color: Colors.transparent,
                          alignment: Alignment.center,
                          child: Image.network(
                            data.signatureImageUrl!,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                          ),
                        ),
                ),
              ),
              _field(
                left: w * 0.145,
                top: h * 0.780,
                width: w * 0.326,
                text: _short(data.digitalSignature, 84),
                style: cryptoStyle,
                maxLines: 2,
              ),
              _field(
                left: w * 0.145,
                top: h * 0.850,
                width: w * 0.326,
                text: _short(data.artworkHash, 74),
                style: cryptoStyle,
                maxLines: 2,
              ),
              _field(
                left: w * 0.120,
                top: h * 0.872,
                width: w * 0.360,
                text: _safe(data.folio),
                style: folioStyle,
                textAlign: TextAlign.center,
              ),
              _field(
                left: w * 0.573,
                top: h * 0.675,
                width: w * 0.247,
                text: _short(_safe(data.issueDate), 20),
                style: issueStyle,
              ),
              _field(
                left: w * 0.113,
                top: h * 0.985,
                width: w * 0.74,
                text:
                    'Registro: ${_safe(data.registrationTimestamp)} | Certificado: ${_safe(data.certificateTimestamp)} | Autor: ${_safe(data.authorFullName ?? '-')}.',
                style: TextStyle(
                  color: textColor,
                  fontSize: w * 0.0062,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
              ),
              Positioned(
                left: w * 0.567,
                top: h * 0.764,
                width: w * 0.125,
                height: w * 0.125,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  color: Colors.white,
                  child: Image.network(
                    'https://api.qrserver.com/v1/create-qr-code/?size=260x260&data=${Uri.encodeComponent(data.qrValue)}',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _safe(String value) {
    final v = value.trim();
    return v.isEmpty ? '-' : v;
  }

  Widget _field({
    required double left,
    required double top,
    required double width,
    required String text,
    required TextStyle style,
    int maxLines = 1,
    TextAlign textAlign = TextAlign.left,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: Text(
        text,
        textAlign: textAlign,
        style: style,
        maxLines: maxLines,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static String _short(String raw, int max) {
    final v = raw.trim();
    if (v.isEmpty) return '-';
    if (v.length <= max) return v;
    final keep = (max / 2).floor();
    return '${v.substring(0, keep)}...${v.substring(v.length - keep)}';
  }

  List<Widget> _debugGrid(double w, double h) {
    final lines = <Widget>[];
    for (int i = 1; i < 10; i++) {
      lines.add(
        Positioned(
          left: w * (i / 10),
          top: 0,
          bottom: 0,
          child: Container(width: 1, color: const Color(0x55FF0000)),
        ),
      );
      lines.add(
        Positioned(
          top: h * (i / 10),
          left: 0,
          right: 0,
          child: Container(height: 1, color: const Color(0x5500AAFF)),
        ),
      );
    }
    return lines;
  }
}
