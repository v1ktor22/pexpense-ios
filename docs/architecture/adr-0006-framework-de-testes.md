# ADR-0006 — Framework de testes

- **Status:** aceito
- **Data:** 2026-09-22

## Decisão

- Testes unitários usam **Swift Testing** (`import Testing`, `@Test`, `#expect`).
- **XCTest** permanece para UI tests e testes de performance, onde é o único suportado.
- Não manter dois frameworks para o mesmo tipo de teste.

## Consequências

- Uma única forma de escrever teste unitário no projeto.
- Arquivos de template do Xcode que usem XCTest devem ser convertidos ou removidos.