import 'dart:typed_data';

import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart' as impl;

void downloadFile(Uint8List bytes, String fileName, String mimeType) {
  impl.downloadFile(bytes, fileName, mimeType);
}
