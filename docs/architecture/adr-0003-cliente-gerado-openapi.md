# ADR-0003 — Contrato gerado, não digitado

- **Status:** aceito — implementação no backend pendente
- **Data:** 2026-09-22

## Contexto

Não existe `/api/v1` nem OpenAPI no backend. A validação já está centralizada em zod **v3**
(`packages/shared/src/schemas/index.ts`) — ou seja, a fonte única de verdade dos schemas
já existe, apenas não está exposta como contrato. Confirmado: `zod ^3.24.3` em
`packages/shared` e `packages/bot`.

## Decisão

- Gerar o spec a partir dos schemas zod existentes com `@asteasolutions/zod-to-openapi`
  (compatível com zod v3 — confirmar a versão do pacote no momento da instalação) e servir
  em `/api/v1/openapi.json`.
- Versionar as rotas em `/api/v1/*`, mantendo re-export fino nos caminhos antigos, porque o
  web está em produção no mesmo contrato.
- No iOS: `swift-openapi-generator` + `swift-openapi-urlsession`. Tipos e transporte são
  gerados; nenhum `Codable` manual espelhando o servidor.
- O `openapi.json` é commitado no repo iOS e pinado pelo sha do backend que o gerou.
- CI falha se o spec gerado divergir do commitado.

## Consequências

- Cliente de loja tem release lenta; `/api/v1` é o que permite evoluir a API depois sem
  quebrar apps já instalados.
- Mudança de schema no backend vira diff visível no repo iOS. Desalinhamento silencioso
  deixa de existir.
- Mudanças na primeira passada devem ser **aditivas**: adicionar campos, remover só depois
  que todos os clientes migraram.