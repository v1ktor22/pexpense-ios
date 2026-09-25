#!/usr/bin/env bash
# Busca o contrato servido pelo backend de dev e atualiza AS DUAS copias do repo iOS.
# Uso:   ./scripts/sync-openapi.sh
# Nunca copie o openapi.json a mao: o spec e gerado no backend.
set -euo pipefail

BASE="${PEXPENSE_API:-https://devpexpense.local}"
DEST_A="docs/api/openapi.json"
DEST_B="Pexpense/API/openapi.json"

ANTES=$(shasum -a 256 "$DEST_A" 2>/dev/null | cut -d' ' -f1 || echo ausente)

curl -fsS "$BASE/api/v1/openapi.json" -o /tmp/openapi.novo.json
node -e "JSON.parse(require('fs').readFileSync('/tmp/openapi.novo.json','utf8'))"

cp /tmp/openapi.novo.json "$DEST_A"
cp /tmp/openapi.novo.json "$DEST_B"
rm -f /tmp/openapi.novo.json

DEPOIS=$(shasum -a 256 "$DEST_A" | cut -d' ' -f1)
diff -q "$DEST_A" "$DEST_B" >/dev/null || { echo "ERRO: as duas copias divergem"; exit 1; }
echo "as duas copias: iguais"
echo "sha256: $DEPOIS"
if [ "$ANTES" = "$DEPOIS" ]; then echo "spec ja estava atualizado"; else echo "spec ATUALIZADO (antes: $ANTES)"; fi
