# Estado do projeto

- **Atualizado em:** 2026-09-25
- **Fase:** 2 (Fatia vertical de Criação de Despesas concluída com Idempotency-Key)
- **Contrato OpenAPI:** `docs/api/openapi.json` e `Pexpense/API/openapi.json` (sha `8053581`)
- **Repositório do backend:** `/Users/silva/Documents/repositories-dev/devpexpense` (fora deste workspace).

## O que existe e está pronto nesta fatia

- **OpenAPI Integration:**
  - `docs/api/openapi.json` e `Pexpense/API/openapi.json` atualizados para `devpexpense@8053581` (com suporte documentado a `Idempotency-Key` no header de `POST /api/v1/expenses`).
  - Geração de código ativa via `swift-openapi-generator` plug-in com suporte a `POST /api/v1/expenses` e `GET /api/v1/categories`.
- **Configuração e Ambiente:**
  - `Config/Local.xcconfig` com `API_BASE_URL = https:/$()/devpexpense.local`.
  - `Utilities/AppConfiguration.swift` fornecendo a base URL configurada.
  - `App/AppEnvironment.swift` composition root injetando serviços e estado observável (`@Observable` + `@MainActor`).
- **Segurança e Idempotência:**
  - `Services/KeychainService.swift` implementando `TokenStore` com `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
  - `Services/ExpenseSubmissionCoordinator.swift`:
    - Gera UUID como `Idempotency-Key` por operação no momento da confirmação.
    - Reusa a **mesma chave** em retries subsequentes daquela mesma operação.
    - Trata `409 IDEMPOTENCY_KEY_REUSED` invalidando a chave para gerar nova na próxima tentativa.
    - Trata `409 IDEMPOTENCY_IN_PROGRESS` mantendo a chave para retry.
    - Limpa a chave em caso de sucesso.
- **Camada de Rede e Autenticação:**
  - `Services/AuthMiddleware.swift`: Bearer token + 1 refresh no 401 + 1 retry.
  - `Services/NetworkServices.swift` (`RemoteExpenseService`):
    - `createExpense`: envia `amountInUnits` em unidades (ex.: `12.50`), com `Idempotency-Key` no header.
    - `fetchCategories`: busca categorias cadastradas via `GET /api/v1/categories`.
- **Telas e Interface de Usuário:**
  - `Views/CreateExpenseView.swift` e `ViewModels/CreateExpenseViewModel.swift`: formulário com descrição, valor (em unidades com separador local), moeda (CHF/EUR), data, seletor de categoria e recorrência. Destaque de erro por campo (`fieldErrors["description"]`, `fieldErrors["amount"]`).
  - `Views/ExpenseListView.swift`: botão `+` abre a folha de criação; ao salvar, fecha e recarrega a lista.
- **Modelos e Mapeamento:**
  - `Models/ExpenseDisplay.swift`: costura de apresentação desacoplando o modelo de tela da OpenAPI e garantindo formatação correta de centavos em CHF e EUR.
- **Testes:**
  - `CurrencyFormatterTests`: 8 testes unitários de formatação de moeda, separador `U+0027` e totais de resumo.
  - `ExpenseCreationTests`: 5 testes unitários validando:
    1. Reuso da mesma chave de idempotência em retry após falha de rede.
    2. Geração de chaves diferentes para operações distintas.
    3. Geração de chave nova após `409 IDEMPOTENCY_KEY_REUSED`.
    4. Mapeamento de centavos em CHF para `ExpenseDisplay`.
    5. Mapeamento de centavos em EUR para `ExpenseDisplay`.
  - `IntegrationTests`: 3 testes (Keychain + 2 testes de rede viva com gating).

## O que NÃO foi feito (ficou para as próximas fatias)

- **Comprovantes / Recibos:** upload de foto/câmera e OCR.
- **Edição e exclusão:** rotas de update e delete de despesas.
- **Charts:** visualização gráfica de `ExpenseCharts`.

## Próximos passos

1. Upload de comprovantes de despesa via câmera/galeria.
2. Filtros e gráficos do período.