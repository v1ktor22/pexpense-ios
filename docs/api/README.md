# Contrato da API

`openapi.json` é **gerado** do backend `devpexpense` a partir dos schemas zod em
`packages/shared/src/schemas`. Não edite este arquivo à mão.

## Estado

**Spec integrado.** Proveniente do backend `devpexpense@043ca2a` e servido ao vivo em
`GET /api/v1/openapi.json`. Cópias em `docs/api/openapi.json` e `Pexpense/API/openapi.json`.

## Por que está aqui

O app consome os tipos gerados deste spec (`swift-openapi-generator`). Commitá-lo no repo
iOS deixa o diff de contrato visível: se o backend muda, aparece aqui antes de quebrar o app.

## Como regenerar (quando a Fase 1 existir)

1. No repo do backend, gere o spec: **script a criar na Fase 1**
   (`pnpm --filter @pexpense/web openapi:generate` — ainda não existe).
2. Copie o resultado para `docs/api/openapi.json`.
3. Atualize a linha do sha aqui e no `AGENTS.md`.
4. Regenere os tipos Swift e rode o build.

## Proveniência

- Backend: `devpexpense@043ca2a`
- Gerado em: `2026-09-24`

## Testes com backend vivo

Os testes de integração HTTPS contra `devpexpense.local` são pulados por padrão na suíte
unitária. Para executá-los: `PEXPENSE_LIVE_TESTS=1 xcodebuild test -scheme Pexpense -destination 'platform=iOS Simulator,name=<device>'`.