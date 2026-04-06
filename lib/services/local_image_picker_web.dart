// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'local_image_picker.dart';

Future<PickedImage?> pickLocalImage() async {
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.style.display = 'none';
  html.document.body?.append(input);

  final completer = Completer<PickedImage?>();

  input.onChange.first.then((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      input.remove();
      return;
    }

    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    reader.onLoadEnd.first.then((_) {
      try {
        final result = (reader.result ?? '').toString();
        final commaIndex = result.indexOf(',');
        if (commaIndex <= 0) {
          if (!completer.isCompleted) completer.complete(null);
          input.remove();
          return;
        }
        final base64Data = result.substring(commaIndex + 1);
        final bytes = base64Decode(base64Data);
        if (!completer.isCompleted) {
          completer.complete(PickedImage(bytes: bytes, fileName: file.name));
        }
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      } finally {
        input.remove();
      }
    });
  });

  input.click();
  return completer.future.timeout(
    const Duration(minutes: 1),
    onTimeout: () {
      input.remove();
      return null;
    },
  );
}
