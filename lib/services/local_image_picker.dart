import 'dart:typed_data';

import 'local_image_picker_stub.dart'
    if (dart.library.html) 'local_image_picker_web.dart'
    as impl;

class PickedImage {
  PickedImage({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

Future<PickedImage?> pickLocalImage() => impl.pickLocalImage();
