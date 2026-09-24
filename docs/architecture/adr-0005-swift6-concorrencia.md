# ADR-0005 — Swift 6 e concorrência estrita

- **Status:** aceito
- **Data:** 2026-09-22

## Contexto

O custo real de Swift 6 não é a sintaxe de MVVM, e sim o isolamento: `Sendable`,
`@MainActor` e diagnósticos de concorrência. Decidir isso depois significa migrar todo o
código.

## Decisão

- Alvo mínimo iOS 17. Swift 6 com strict concurrency desde o início.
- Estado de UI com `@Observable` + `@MainActor`; I/O com `async/await`.
- Proibido Combine, `@StateObject` e `@ObservedObject`.
- Modelos gerados do spec já são `Sendable`. Mutação de estado observável só em `@MainActor`.

## Consequências

- Mais atrito nas primeiras horas (diagnósticos de isolamento), zero retrabalho de migração.
- Previews exigem `AppEnvironment` com dependências de protocolo — motivo pelo qual a DI é
  por protocolo e não por singleton.