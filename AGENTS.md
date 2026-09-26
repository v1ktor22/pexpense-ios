# Pexpense iOS — instruções para agentes

Este repositório é o cliente nativo iOS (SwiftUI) do Pexpense.
Antes de escrever código, leia este arquivo **e** `docs/status.md`.

## 1. Regra de ouro: thin client

- 100% das regras de negócio, validação, cálculo e persistência vivem no backend
  (`devpexpense`: `packages/web` + `packages/shared`). Este app não reimplementa nada disso.
- Offline existe apenas como cache de leitura temporário — nunca fonte de verdade,
  nunca reconciliação bidirecional.
- Se você se pegar escrevendo regra de negócio em Swift: pare. Ela pertence ao backend.

## 2. Fonte da verdade da API

- **Contrato:** `docs/api/openapi.json`, obtido com `./scripts/sync-openapi.sh` (busca do
  backend de dev). **Nunca** edite o spec à mão nem copie entre as duas cópias manualmente:
  o script mantém `docs/api/openapi.json` e `Pexpense/API/openapi.json` idênticos.
- Spec atual: sha256 `a95d2842593666e09b3ad3aa829e656bb78ef64ad38230e0bea0ac50551abb20`. Última proveniência registrada: `devpexpense@54c122d`.
- O backend também serve o mesmo spec em `GET /api/v1/openapi.json`
  (dev: `http://devpexpense.local/api/v1/openapi.json`).
- **Nunca** escreva `Codable` à mão espelhando um modelo do servidor: os tipos vêm do spec
  (`swift-openapi-generator`). O spec usa `$ref` para os componentes, então os tipos saem
  nomeados (`Expense`, `ExpenseList`, `TokenPair`…).
- Se a operação ou o campo não está no spec: **pare e pergunte**. Não invente endpoint,
  nome de campo, formato de erro nem código HTTP.
- Não edite `docs/api/openapi.json` à mão. Ele é gerado.

### Fluxo de autenticação (2 chamadas, nesta ordem)

1. `POST /api/v1/auth/otp` com `{ email }` → pede o código por e-mail. Responde
   `{ ok: true }` e **não** revela se a conta existe.
   Se o reenvio estiver no cooldown de 60s, responde **429 com `code = RESEND_COOLDOWN`**:
   o envio NÃO aconteceu — o app deve mostrar contagem regressiva e dizer que o código
   anterior foi invalidado. Não trate 429 como falha de rede.
2. `POST /api/v1/auth/token` com `{ email, otp, deviceName?, platform? }` → **201** com
   `{ accessToken, refreshToken, expiresIn, tokenType: "Bearer" }`. O access dura 20 min.
3. `POST /api/v1/auth/token/refresh` com `{ refreshToken }` → par novo. O refresh é
   single-use; o backend tem uma janela de graça de 60s que trata replay como retry.
4. `POST /api/v1/auth/token/revoke` → logout do dispositivo (aceita o access no header ou
   o refresh no corpo).

## 3. Verificação obrigatória

Nenhuma tarefa está concluída sem build verde colado na resposta:

    xcodebuild -scheme Pexpense -destination 'platform=iOS Simulator,name=iPhone 16' build
    xcodebuild -scheme Pexpense -destination 'platform=iOS Simulator,name=iPhone 16' test

- **Descubra o simulador disponível antes**: `xcrun simctl list devices available`.
  O nome acima é exemplo — usar um device inexistente falha o build.
- Para build sem simulador específico: `-destination 'generic/platform=iOS Simulator'`.
- Nunca escreva "pronto" nem "deve funcionar" sem a saída real do comando.
- Se o build falhar e você não conseguir corrigir, relate o erro exato. Não mascare.

## 4. UI — regras duras

- Vermelho **nunca** em botão, inclusive na confirmação de exclusão. Ações destrutivas
  usam botão neutro; o perigo aparece apenas no rótulo.
- Tipografia do sistema. `JetBrains Mono` ou `.monospacedDigit()` para números e valores.
- Estética limpa e minimalista, alinhada às Human Interface Guidelines.

## 5. Dinheiro, números e locale

- Valores chegam da API como **inteiro em centavos**. Trafegue e calcule como `Int`.
  Nunca `Double`/`Float` em dinheiro.
- O `openapi.json` declara, por campo, que valores de resposta estão em centavos — e que
  `amount` nas requisições vai em unidades. A referência é o spec, não este documento.
- Formate apenas na borda de apresentação, com `NumberFormatter`, locale `de-CH` e
  separador de milhar fixado em `U+0027` (`'`) — ver `docs/architecture/adr-0004`.
- Exemplos canônicos: `CHF 1'890.00` e `€ 68.50`.
- i18n: `fr-CH` é o padrão, `en` o secundário. **Nunca** string em português no
  código nem na UI.

## 6. Segurança

- Tokens somente no Keychain, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
  Nunca `UserDefaults`, nunca arquivo.
- 401 → **um único** refresh → **um único** retry. Se falhar: limpe o Keychain e volte
  para a autenticação. Nunca loop de refresh.
- Nenhum segredo no repositório. Base URL e configuração por ambiente via `.xcconfig`
  não versionado.
- **Idempotência:** todo POST que cria recurso manda `Idempotency-Key`. A chave é gerada
  **uma vez por operação** (quando o usuário confirma) e **reusada em todo retry** daquela
  mesma operação. Chave nova por tentativa anula a proteção. Nunca reusar a chave de uma
  operação diferente.

## 7. Arquitetura

- MVVM com `@Observable` + `@MainActor` + `async/await`. Não use Combine,
  `@StateObject` nem `@ObservedObject`.
- Injeção de dependência por protocolo através de `AppEnvironment`. Services dependem
  de protocolos, não de implementações — é o que torna o preview confiável.
- Swift 6 com strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`). Modelos `Sendable`;
  mutação de estado observável apenas em `@MainActor` explícito. `SWIFT_APPROACHABLE_CONCURRENCY`
  é fixado em `NO` para garantir compatibilidade com `ClientMiddleware` e tipos gerados do
  OpenAPI — ver `docs/architecture/adr-0007`.
- Layout: `App/ Models/ Services/ ViewModels/ Views/ Utilities/`.
- Swift 6 com strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`). Modelos `Sendable`;
  mutação de estado observável apenas em `@MainActor` explícito. `SWIFT_APPROACHABLE_CONCURRENCY`
  é fixado em `NO` para garantir compatibilidade com `ClientMiddleware` e tipos gerados do
  OpenAPI — ver `docs/architecture/adr-0007`.
- Layout: `App/ Models/ Services/ ViewModels/ Views/ Utilities/`.

## 8. Pitfalls já conhecidos (não redescubra)

- `NumberFormatter` com `de-CH`: **medido em iOS 17+ (Swift 6): o separador sai correto,
  `U+0027`.** Ainda assim, fixe `groupingSeparator` explicitamente e mantenha o teste
  unitário como guarda de regressão — o ICU varia entre toolchains.
- **O Keychain sobrevive à desinstalação do app.** Limpe no primeiro lançamento, ou o
  usuário reinstala já autenticado.
- Datas no backend vêm em formatos mistos (timestamp numérico e string ISO). Use o
  formato que o spec declara; nunca compare strings de data.
- **Reenvio de OTP**: `429` com `code = RESEND_COOLDOWN` significa que o envio foi
  bloqueado (cooldown de 60s) — o app precisa de contagem regressiva própria.
- `@Observable` exige iOS 17 e `import Observation`.

## 9. Antes de abrir um PR

- Build + testes verdes (item 3).
- Nenhuma string em português.
- Nenhum valor monetário em `Double`.
- Nenhum `Codable` escrito à mão para modelo do servidor.