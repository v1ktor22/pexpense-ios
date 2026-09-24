# Pexpense iOS

Cliente nativo iOS (SwiftUI) do Pexpense. Cliente fino sobre a API do backend
`devpexpense` — nenhuma regra de negócio vive aqui.

## Requisitos

- macOS com Xcode 16+ e Command Line Tools (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`)
- VS Code com as extensões **Swift** (SourceKit-LSP) e **SweetPad** (build/run/simulador no editor)
- Alvo mínimo: iOS 17. Linguagem: Swift 6 com strict concurrency.

## Setup local

Copie `Config/Local.xcconfig.example` para `Config/Local.xcconfig` e ajuste a `API_BASE_URL` para o seu ambiente.

## Como buildar e testar

```bash
xcrun simctl list devices available          # descubra o simulador antes
xcodebuild -scheme Pexpense -destination 'platform=iOS Simulator,name=<da lista>' build
xcodebuild -scheme Pexpense -destination 'platform=iOS Simulator,name=<da lista>' test
```

## Estrutura

```
Pexpense/
├── App/          # entrypoint, AppEnvironment, composição de dependências
├── Models/       # tipos gerados do OpenAPI (não editar à mão)
├── Services/     # protocolos + I/O: transporte, Keychain, refresh
├── ViewModels/   # @Observable + @MainActor
├── Views/        # telas e componentes
└── Utilities/    # formatadores, extensões
docs/
├── architecture/ # ADRs das decisões estruturais
└── api/          # openapi.json (gerado do backend)
```

## Documentos que você deve ler

- `AGENTS.md` — regras operacionais obrigatórias (o que pode e o que não pode).
- `docs/status.md` — em que fase o projeto está e o que pode ser feito agora.
- `docs/architecture/adr-*.md` — por que cada decisão foi tomada.
- `docs/api/README.md` — de onde vem o `openapi.json` e como regenerá-lo.