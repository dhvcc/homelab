# Encrypted bootstrap secrets

Files in this directory are encrypted to the operator SSH public key with
`age`. They are safe to commit; the matching private key must stay outside the
repository.

Apply the Longhorn R2 credentials:

```bash
ANSIBLE_STDOUT_CALLBACK=default \
uvx --from ansible-core ansible-playbook \
  playbooks/apply-longhorn-r2-secret.yml \
  -i inventory/hosts.yml
```
