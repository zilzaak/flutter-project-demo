import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_demo_project/services/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  test('RSA Key Pair generation, PEM parsing, and SHA256withRSA signing test', () async {
    final securityService = SecurityService();

    // 1. Generate 1024-bit RSA key pair for quick test
    final keyPair = await securityService.generateRsaKeyPair(bitStrength: 1024);

    expect(keyPair.publicKeyBase64.isNotEmpty, true);
    expect(keyPair.privateKeyPem.contains('BEGIN RSA PRIVATE KEY'), true);

    // 2. Store in secure storage
    await securityService.storePrivateKey(keyPair.privateKeyPem);
    await securityService.storePublicKey(keyPair.publicKeyBase64);

    expect(await securityService.hasStoredPrivateKey(), true);
    expect(await securityService.getStoredPrivateKeyPem(), keyPair.privateKeyPem);

    // 4. Test getOrCreateDevicePublicKey reuse
    final reusedPublicKey = await securityService.getOrCreateDevicePublicKey();
    expect(reusedPublicKey, keyPair.publicKeyBase64);

    // 5. Test canonical signing
    const canonicalPayload = '123|90.399|23.777';
    final canonicalSignature = await securityService.signPayload(canonicalPayload);
    expect(canonicalSignature, isNotNull);
    expect(canonicalSignature!.isNotEmpty, true);
  });
}
