import java.io.FileInputStream;
import java.security.KeyStore;
import java.security.cert.Certificate;
import java.security.MessageDigest;
import java.util.Enumeration;

public class CheckCerts {
    public static void main(String[] args) throws Exception {
        String[] keystores = {
            "keystore/emiplay.keystore",
            "user.keystore",
            "beauty.keystore",
            "userGP_for_total_war.keystore"
        };
        
        for (String ksFile : keystores) {
            try {
                KeyStore ks = KeyStore.getInstance("JKS");
                ks.load(new FileInputStream(ksFile), null); // null password bypasses check for certs
                System.out.println("Loaded " + ksFile + " with null password.");
                Enumeration<String> aliases = ks.aliases();
                while (aliases.hasMoreElements()) {
                    String alias = aliases.nextElement();
                    Certificate cert = ks.getCertificate(alias);
                    if (cert != null) {
                        MessageDigest md = MessageDigest.getInstance("SHA-1");
                        byte[] der = cert.getEncoded();
                        md.update(der);
                        byte[] digest = md.digest();
                        System.out.print("  Alias: " + alias + " -> SHA1: ");
                        for (byte b : digest) {
                            System.out.printf("%02X:", b);
                        }
                        System.out.println();
                    }
                }
            } catch (Exception e) {
                System.out.println("Failed to load " + ksFile + " as JKS: " + e.getMessage());
                try {
                    KeyStore ks = KeyStore.getInstance("PKCS12");
                    ks.load(new FileInputStream(ksFile), null);
                    System.out.println("Loaded " + ksFile + " as PKCS12 with null password.");
                    Enumeration<String> aliases = ks.aliases();
                    while (aliases.hasMoreElements()) {
                        String alias = aliases.nextElement();
                        Certificate cert = ks.getCertificate(alias);
                        if (cert != null) {
                            MessageDigest md = MessageDigest.getInstance("SHA-1");
                            byte[] der = cert.getEncoded();
                            md.update(der);
                            byte[] digest = md.digest();
                            System.out.print("  Alias: " + alias + " -> SHA1: ");
                            for (byte b : digest) {
                                System.out.printf("%02X:", b);
                            }
                            System.out.println();
                        }
                    }
                } catch (Exception e2) {
                    System.out.println("Failed to load " + ksFile + " as PKCS12: " + e2.getMessage());
                }
            }
        }
    }
}
