

import 'package:pointycastle/asymmetric/api.dart';

class RsaKeyPairResult {
  final RSAPublicKey publicKey;
  final RSAPrivateKey privateKey;
  final String publicKeyBase64;
  final String privateKeyPem;

  const RsaKeyPairResult({
    required this.publicKey,
    required this.privateKey,
    required this.publicKeyBase64,
    required this.privateKeyPem,
  });
}