#!/usr/bin/env python3

import argparse
import hashlib
import json
import os
import pathlib
import subprocess
import tempfile
import urllib.request


API_BASE = "https://api.cloudflare.com/client/v4"
DEFAULT_OUTPUT = pathlib.Path(__file__).parents[1] / "secrets/longhorn-r2-secret.json.age"


def cloudflare_get(path: str, token: str) -> dict:
    request = urllib.request.Request(
        API_BASE + path,
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    if not payload.get("success"):
        raise SystemExit(payload.get("errors") or "Cloudflare API request failed")
    return payload["result"]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Derive Longhorn S3 credentials from the Cloudflare API token and age-encrypt them."
    )
    parser.add_argument("--account-id", required=True)
    parser.add_argument("--recipient", default=str(pathlib.Path.home() / ".ssh/id_rsa.pub"))
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    token = os.environ.get("CLOUDFLARE_API_TOKEN")
    if not token:
        raise SystemExit("CLOUDFLARE_API_TOKEN is not set")

    token_info = cloudflare_get(f"/accounts/{args.account_id}/tokens/verify", token)
    cloudflare_get(f"/accounts/{args.account_id}/r2/buckets", token)

    manifest = {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {
            "name": "longhorn-r2-credentials",
            "namespace": "longhorn-system",
        },
        "type": "Opaque",
        "stringData": {
            "AWS_ACCESS_KEY_ID": token_info["id"],
            "AWS_SECRET_ACCESS_KEY": hashlib.sha256(token.encode()).hexdigest(),
            "AWS_ENDPOINTS": f"https://{args.account_id}.r2.cloudflarestorage.com",
        },
    }

    encrypted = subprocess.run(
        ["age", "--encrypt", "--recipients-file", args.recipient],
        input=json.dumps(manifest, separators=(",", ":")).encode(),
        check=True,
        capture_output=True,
    ).stdout

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=args.output.parent, delete=False) as temporary:
        temporary.write(encrypted)
        temporary_path = pathlib.Path(temporary.name)
    temporary_path.replace(args.output)
    print(f"Updated {args.output}")


if __name__ == "__main__":
    main()
