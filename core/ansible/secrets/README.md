# secrets/README.md

`vault.yml` must be encrypted with `ansible-vault` before it contains any
real values. Until the Proxmox API token exists, the placeholder file is
safe to commit as-is (no real secrets).

## One-time setup

```bash
# Create a vault password file (NOT committed — see .gitignore)
echo "<a-strong-password>" > ~/.vault_pass.txt
chmod 600 ~/.vault_pass.txt
```

Reference it in `ansible.cfg`:

```ini
[defaults]
vault_password_file = ~/.vault_pass.txt
```

## After creating the Proxmox API token

```bash
ansible-vault encrypt secrets/vault.yml
```

To edit later:

```bash
ansible-vault edit secrets/vault.yml
```

## Sanity check before every commit

```bash
git diff secrets/vault.yml   # should show ciphertext (or no change), never plaintext secrets
```
