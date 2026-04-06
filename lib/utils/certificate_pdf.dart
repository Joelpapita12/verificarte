import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> buildCertificatePdfFromBoundary(GlobalKey repaintKey) async {
  final boundary =
      repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    throw Exception('No se pudo preparar el certificado para exportar.');
  }

  final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw Exception('No se pudo convertir el certificado a imagen.');
  }

  final pngBytes = byteData.buffer.asUint8List();
  final doc = pw.Document();
  final memImage = pw.MemoryImage(pngBytes);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(16),
      build: (_) =>
          pw.Center(child: pw.Image(memImage, fit: pw.BoxFit.contain)),
    ),
  );

  return doc.save();
}
