# Task: Managing Secrets with Azure Key Vault
The Nautilus DevOps team is focusing on improving their data security by using Azure Key Vault. Your task is to create a Key Vault with a key and manage the encryption and decryption of a pre-existing sensitive file using this key.

## Task Details

1. Create a Key Vault:
    - Name the Key Vault `datacenter-22709`.
    - Set access policies to allow encryption and decryption operations.
    - Set Soft Delete retention to 7 days.
1. Create an RSA Key:
    - Create a key named `datacenter-key` within the Key Vault for encryption and decryption operations.
    - Key type: `RSA`
    - RSA key size `4096`
    - Leave all other settings as default.
1. Encrypt the Sensitive Data:
    - Use the key to encrypt the provided `SensitiveData.txt` file (located in `/root/`) on the `azure-client` host.
    - Base64 encode the ciphertext and save the encrypted version as `EncryptedData.bin` in the `/root/` directory.
1. Verify Decryption:
    - Attempt to decrypt `EncryptedData.bin` and verify that the decrypted data matches the original `SensitiveData.txt` file.
