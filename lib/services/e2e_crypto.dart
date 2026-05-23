import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Servicio de criptografía extremo a extremo.
///
/// Diseño:
///   - Derivación de clave: PBKDF2-SHA256 (password + salt fija por usuario) → semilla de 32 bytes.
///   - Keypair:  semilla → escalar P-256 privado determinista; clave pública = dG.
///   - Cifrado de mensajes: ECIES — efímero ECDH + AES-256-GCM.
///   - Firma de certificados: ECDSA-SHA256, firma codificada como base64(r‖s) (64 bytes).
class E2eCrypto {
  static final ECDomainParameters _curve = ECDomainParameters('prime256v1');

  // ─── Derivación de keypair ──────────────────────────────────────────────────

  /// Deriva un keypair P-256 determinista a partir de la contraseña del usuario.
  /// Misma contraseña + mismo userId → misma clave siempre (sin necesidad de
  /// almacenar la clave privada en el servidor).
  static E2eKeyPair deriveKeyPair({
    required String password,
    required int userId,
    required String email,
  }) {
    final salt = 'verificarte-e2e-v1:$userId:${email.toLowerCase().trim()}';
    final seed = _pbkdf2(password, salt, iterations: 100000, keyLen: 32);

    final n = _curve.n;
    // Interpretar seed como BigInt y recortar al rango [1, n-1]
    var d = _bytesToBigInt(seed);
    d = (d % (n - BigInt.one)) + BigInt.one;

    final Q = (_curve.G * d)!;
    final privateKey = ECPrivateKey(d, _curve);
    final publicKey = ECPublicKey(Q, _curve);
    final publicKeyB64 = base64Encode(Q.getEncoded(false));

    return E2eKeyPair(
      privateKey: privateKey,
      publicKey: publicKey,
      publicKeyB64: publicKeyB64,
    );
  }

  // ─── Cifrado de mensajes (ECIES) ────────────────────────────────────────────

  /// Cifra [plaintext] para un receptor identificado por [recipientPublicKeyB64].
  ///
  /// Formato de salida (JSON):
  ///   `{"v":1,"e":"ephPubB64","n":"ivB64","c":"ciphertextB64"}`
  static String encryptMessage({
    required String plaintext,
    required String recipientPublicKeyB64,
  }) {
    final recipPubBytes = base64Decode(recipientPublicKeyB64);
    final recipPub = ECPublicKey(_curve.curve.decodePoint(recipPubBytes), _curve);

    // Keypair efímero para esta operación
    final rng = Random.secure();
    final ephSeed = Uint8List.fromList(
      List.generate(32, (_) => rng.nextInt(256)),
    );
    var ephD = (_bytesToBigInt(ephSeed) % (_curve.n - BigInt.one)) + BigInt.one;
    final ephQ = (_curve.G * ephD)!;
    final ephPubBytes = ephQ.getEncoded(false);

    // ECDH: punto compartido = ephD × recipPub
    final sharedPoint = (recipPub.Q! * ephD)!;
    final sharedX = _bigIntToBytes(sharedPoint.x!.toBigInteger()!, 32);
    final aesKey = _sha256(sharedX);

    // AES-256-GCM
    final iv = Uint8List.fromList(List.generate(12, (_) => rng.nextInt(256)));
    final ct = _gcmEncrypt(aesKey, iv, Uint8List.fromList(utf8.encode(plaintext)));

    return jsonEncode({
      'v': 1,
      'e': base64Encode(ephPubBytes),
      'n': base64Encode(iv),
      'c': base64Encode(ct),
    });
  }

  /// Descifra un mensaje ECIES con la clave privada del receptor.
  /// Devuelve null si el descifrado falla (clave incorrecta, datos corruptos).
  static String? decryptMessage({
    required String encryptedJson,
    required ECPrivateKey privateKey,
  }) {
    try {
      final map = jsonDecode(encryptedJson) as Map<String, dynamic>;
      final ephPubBytes = base64Decode(map['e'] as String);
      final iv = base64Decode(map['n'] as String);
      final ct = base64Decode(map['c'] as String);

      final ephPub = ECPublicKey(_curve.curve.decodePoint(ephPubBytes), _curve);
      final sharedPoint = (ephPub.Q! * privateKey.d!)!;
      final sharedX = _bigIntToBytes(sharedPoint.x!.toBigInteger()!, 32);
      final aesKey = _sha256(sharedX);

      final plainBytes = _gcmDecrypt(aesKey, iv, ct);
      return utf8.decode(plainBytes);
    } catch (_) {
      return null;
    }
  }

  // ─── Firma ECDSA ────────────────────────────────────────────────────────────

  /// Firma [payload] con ECDSA-SHA256. Devuelve base64(r‖s) (64 bytes).
  static String signPayload({
    required Uint8List payload,
    required ECPrivateKey privateKey,
  }) {
    final fortuna = FortunaRandom()
      ..seed(KeyParameter(Uint8List.fromList(
        List.generate(32, (_) => Random.secure().nextInt(256)),
      )));

    final signer = Signer('SHA-256/ECDSA')
      ..init(
        true,
        ParametersWithRandom(
          PrivateKeyParameter<ECPrivateKey>(privateKey),
          fortuna,
        ),
      );

    final sig = signer.generateSignature(payload) as ECSignature;
    final r = _bigIntToBytes(sig.r, 32);
    final s = _bigIntToBytes(sig.s, 32);
    return base64Encode(Uint8List(64)
      ..setRange(0, 32, r)
      ..setRange(32, 64, s));
  }

  /// Verifica una firma ECDSA-SHA256. Devuelve false ante cualquier error.
  static bool verifySignature({
    required Uint8List payload,
    required String signatureB64,
    required String publicKeyB64,
  }) {
    try {
      final sigBytes = base64Decode(signatureB64);
      if (sigBytes.length != 64) return false;
      final pubBytes = base64Decode(publicKeyB64);
      final r = _bytesToBigInt(sigBytes.sublist(0, 32));
      final s = _bytesToBigInt(sigBytes.sublist(32));
      final pubKey = ECPublicKey(_curve.curve.decodePoint(pubBytes), _curve);

      final verifier = Signer('SHA-256/ECDSA')
        ..init(false, PublicKeyParameter<ECPublicKey>(pubKey));
      return verifier.verifySignature(payload, ECSignature(r, s));
    } catch (_) {
      return false;
    }
  }

  // ─── Utilidades públicas ────────────────────────────────────────────────────

  /// SHA-256 de [input] como cadena hexadecimal.
  static String sha256Hex(Uint8List input) {
    return _sha256(input)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// SHA-256 de texto plano como cadena hexadecimal.
  static String sha256HexStr(String input) =>
      sha256Hex(Uint8List.fromList(utf8.encode(input)));

  // ─── Helpers privados ───────────────────────────────────────────────────────

  static Uint8List _pbkdf2(
    String password,
    String salt, {
    required int iterations,
    required int keyLen,
  }) {
    final kdf = KeyDerivator('SHA-256/HMAC/PBKDF2')
      ..init(Pbkdf2Parameters(
        Uint8List.fromList(utf8.encode(salt)),
        iterations,
        keyLen,
      ));
    return kdf.process(Uint8List.fromList(utf8.encode(password)));
  }

  static Uint8List _sha256(Uint8List input) =>
      Digest('SHA-256').process(input);

  static Uint8List _gcmEncrypt(Uint8List key, Uint8List iv, Uint8List pt) {
    final gcm = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    final out = Uint8List(gcm.getOutputSize(pt.length));
    int n = gcm.processBytes(pt, 0, pt.length, out, 0);
    n += gcm.doFinal(out, n);
    return out.sublist(0, n);
  }

  static Uint8List _gcmDecrypt(Uint8List key, Uint8List iv, Uint8List ct) {
    final gcm = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    final out = Uint8List(gcm.getOutputSize(ct.length));
    int n = gcm.processBytes(ct, 0, ct.length, out, 0);
    n += gcm.doFinal(out, n);
    return out.sublist(0, n);
  }

  static BigInt _bytesToBigInt(List<int> bytes) =>
      bytes.fold(BigInt.zero, (acc, b) => (acc << 8) | BigInt.from(b));

  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final hex = value.toRadixString(16).padLeft(length * 2, '0');
    return Uint8List.fromList(
      List.generate(length, (i) {
        return int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }),
    );
  }
}

/// Par de claves EC para el usuario actual (almacenado en memoria).
class E2eKeyPair {
  const E2eKeyPair({
    required this.privateKey,
    required this.publicKey,
    required this.publicKeyB64,
  });

  final ECPrivateKey privateKey;
  final ECPublicKey publicKey;

  /// Clave pública codificada en base64 (punto sin comprimir, 65 bytes: 0x04‖x‖y).
  final String publicKeyB64;
}
