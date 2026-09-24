# ADR-0007 — Concorrência e Tipos Gerados (OpenAPI)

- **Status:** aceito
- **Data:** 2026-09-24

## Contexto

O projeto adotou Swift 6 com strict concurrency desde o início (ADR-0005).

Com a integração do `swift-openapi-generator` e do `swift-openapi-runtime` na Fase 1, surgiu um conflito de isolamento causado pela funcionalidade de *Approachable Concurrency* do Xcode (`SWIFT_APPROACHABLE_CONCURRENCY = YES` e `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`):

1. **Incompatibilidade no `ClientMiddleware`:** O protocolo `ClientMiddleware` do `swift-openapi-runtime` define o parâmetro `next` com a assinatura `@Sendable` concorrente (`(HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)`). Quando `SWIFT_APPROACHABLE_CONCURRENCY` está ativo, o compilador infere `nonisolated(nonsending)` para closures assíncronas, resultando em erro de assinatura incompatível no método `intercept`.
2. **Incompatibilidade com tipos gerados do OpenAPI:** Com `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, o compilador atribui isolamento implícito ao `@MainActor` a todas as declarações não anotadas do módulo, incluindo a `struct Client` e tipos de requisição/resposta gerados em build. Como o runtime do OpenAPI processa serialização JSON e chamadas de rede em threads concorrentes de background, o isolamento implícito ao `@MainActor` causa falhas de compilação por violação de isolamento de ator.

## Decisão

Configuração explícita dos build settings no target `Pexpense`:

| Setting | Valor | Motivo |
|---|---|---|
| `SWIFT_VERSION` | `6.0` | Linguagem Swift 6 nativa. |
| `SWIFT_STRICT_CONCURRENCY` | `complete` | **Declarado explicitamente.** Com `SWIFT_VERSION = 6.0` a checagem estrita vale hoje por padrão, mas de forma implícita. Se a versão da linguagem for alterada ou rebaixada no projeto, a checagem cairia para `minimal` sem aviso e o projeto perderia a garantia de segurança de concorrência em silêncio. Declarar `complete` trava a regra de forma independente. |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `NO` | Desativa a inferência que transforma closures `@Sendable` em `nonisolated(nonsending)`, restaurando a compatibilidade estrita com `ClientMiddleware`. |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | *(ausente / padrão)* | Não definir isolamento implícito global. Tipos de infraestrutura, rede e modelos gerados permanecem não-isolados. |

Regras de isolamento no código:

1. **Isolamento explícito de UI:** Todo estado observável de interface declara `@MainActor` de forma explícita na própria definição da classe (`AppEnvironment`, `AuthViewModel`, `ExpenseListViewModel`).
2. **Infraestrutura concorrente:** Serviços de transporte, `KeychainService` e `AuthMiddleware` mantêm conformidade com `Sendable` e operam em contextos concorrentes sem assumir `MainActor`.

## Consequências

- O gerador de código oficial da Apple (`swift-openapi-generator`) compila sem erros de isolamento de ator.
- A garantia de concorrência estrita do ADR-0005 permanece protegida contra rebaixamentos acidentais da versão do Swift.
- O isolamento ao `@MainActor` é sempre visível e auditável no próprio código-fonte de cada componente de UI, eliminando comportamentos implícitos do compilador.
