import sys
import hashlib
from OpenSSL import crypto

def print_certs(filename):
    print("---", filename, "---")
    with open(filename, 'rb') as f:
        data = f.read()
    # Basic search for X.509 certs in the binary file
    # A cert often starts with sequence 0x30 0x82 ...
    # This is a hacky way to find certificates
    import os
    os.system(f"keytool -printcert -file <(strings {filename})")

