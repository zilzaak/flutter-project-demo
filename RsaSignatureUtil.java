package bd.edu.diu.derpcore.utility;

import lombok.extern.slf4j.Slf4j;

import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;

@Slf4j
public class RsaSignatureUtil {

    /**
     * Verifies that the digital signature is valid for the payload using the Base64 X.509 RSA public key.
     *
     * @param payload         The raw payload or canonical string that was signed
     * @param signatureBase64 The Base64 encoded signature from X-Signature header
     * @param publicKeyBase64 The Base64 encoded X.509 RSA public key from database UsersEnrollment table
     * @return true if signature is valid, false otherwise
     */
    public static boolean verifySignature(String payload, String signatureBase64, String publicKeyBase64) {
        if (payload == null || signatureBase64 == null || signatureBase64.isBlank() || publicKeyBase64 == null || publicKeyBase64.isBlank()) {
            log.warn("RSA verification skipped: Missing payload, signature, or public key");
            return false;
        }

        try {
            String cleanPublicKey = publicKeyBase64
                    .replaceAll("-----BEGIN PUBLIC KEY-----", "")
                    .replaceAll("-----END PUBLIC KEY-----", "")
                    .replaceAll("-----BEGIN RSA PUBLIC KEY-----", "")
                    .replaceAll("-----END RSA PUBLIC KEY-----", "")
                    .replaceAll("\\s+", "");

            byte[] keyBytes = Base64.getDecoder().decode(cleanPublicKey);
            X509EncodedKeySpec keySpec = new X509EncodedKeySpec(keyBytes);
            KeyFactory keyFactory = KeyFactory.getInstance("RSA");
            PublicKey publicKey = keyFactory.generatePublic(keySpec);

            Signature sig = Signature.getInstance("SHA256withRSA");
            sig.initVerify(publicKey);
            sig.update(payload.getBytes(StandardCharsets.UTF_8));

            byte[] signatureBytes = Base64.getDecoder().decode(signatureBase64.trim());
            boolean verified = sig.verify(signatureBytes);

            if (!verified) {
                log.warn("RSA signature verification failed for payload: {}", payload);
            }
            return verified;
        } catch (Exception e) {
            log.error("RSA signature verification exception: {}", e.getMessage());
            return false;
        }
    }
}
