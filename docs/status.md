# Estado do projeto

- **Atualizado em:** 2026-09-24
- **Fase:** 1 (Primeira fatia vertical concluída: Login OTP → Lista de Despesas)
- **Contrato OpenAPI:** `docs/api/openapi.json` e `Pexpense/API/openapi.json` (sha `043ca2a`)
- **Repositório do backend:** `/Users/silva/Documents/repositories-dev/devpexpense` (fora deste workspace).

## O que existe e está pronto nesta fatia

- **OpenAPI Integration:**
  - `docs/api/openapi.json` e `Pexpense/API/openapi.json` com `openapi-generator-config.yaml` (`types` e `client`).
  - Geração de código ativa via `swift-openapi-generator` plug-in.
- **Configuração e Ambiente:**
  - `Config/Local.xcconfig` com `API_BASE_URL = https:/$()/devpexpense.local`.
  - `Utilities/AppConfiguration.swift` fornecendo a base URL configurada.
  - `App/AppEnvironment.swift` como composition root injetando serviços e estado observável (`@Observable` + `@MainActor`).
- **Segurança e Armazenamento:**
  - `Services/KeychainService.swift` implementando `TokenStore` com `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- **Camada de Rede e Autenticação:**
  - `Services/AuthMiddleware.swift` (interceptor OpenAPI):
    - Injeta header `Authorization: Bearer <accessToken>`.
    - No status `401 Unauthorized`, realiza exatamente **um** refresh token (`POST /api/v1/auth/token/refresh`) e **um** retry da requisição. Se falhar, limpa os tokens e invalida a sessão.
  - `Services/NetworkServices.swift` (`RemoteAuthService`, `RemoteExpenseService`):
    - `requestOTP`: trata `RESEND_COOLDOWN` (retorna cooldown de 60s) e erros `ApiError` estruturados.
    - `verifyOTP`: troca OTP + email por `TokenPair` (status 201), persiste no Keychain e retorna tokens.
    - `fetchExpenses`: consome `GET /api/v1/expenses` devolvendo lista tipada gerada do spec.
- **Telas e Interface de Usuário:**
  - `Views/Auth/OTPLoginView.swift`: fluxo em 2 passos (e-mail → código), com timer regressivo de cooldown, design limpo, tipografia monospaced para números e sem botões vermelhos.
  - `Views/ExpenseListView.swift`: lista com descrição, data, categoria e valor formatado em CHF/EUR com `CurrencyFormatter` (`de-CH`, `'`).
  - `Views/RootView.swift`: roteamento reativo entre fluxo autenticado e login baseado em `AppEnvironment.isAuthenticated`.
- **Testes:**
  - `CurrencyFormatterTests`: 6 testes unitários validando code point `U+0027` do separador e formatação.
  - `IntegrationTests`: 2 testes validando comunicação HTTPS com `/api/v1/health` e persistência no Keychain.

## O que NÃO foi feito (ficou para as próximas fatias)

- **Charts:** visualização gráfica de `ExpenseCharts` não é exibida nesta primeira fatia (conforme escopo da tarefa).
- **Criação e edição de despesas:** telas de formulário e upload de recibos.
- **Categorias e Regras Recorrentes:** rotas `/api/v1/categories` e `/api/v1/recurring`.

## Próximos passos

1. Validação do fluxo interativo de login e listagem de dados reais via simulador.
2. Criação de despesas (`POST /api/v1/expenses`) com anexação de comprovantes/OCR.
3. Navegação por período e gráficos de resumo.