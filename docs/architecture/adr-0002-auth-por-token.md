# ADR-0002 — Autenticação nativa por token (Keychain + refresh com rotação)

- **Status:** aceito — implementação no backend pendente
- **Data:** 2026-09-22

## Contexto

Hoje o backend autentica por cookie httpOnly. Em `packages/web/src/hooks.server.ts` existe
um fallback por `Authorization: *** mas ele roda apenas quando o caminho começa com
`/m` ou `/api/pending` (escopo do Mini App e do comprovante pendente). Um cliente iOS
batendo em `/api/expenses` com Bearer recebe **401**. Esse é o bloqueio número um.

Além disso, `sessions.token` é `notNull().unique()` em **texto puro** e o lookup compara a
string diretamente (`getSessionUserFromToken`). Essa tabela é intocável: mexer nela quebra
o login do web.

## Decisão

1. Tokens no Keychain, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Nunca `UserDefaults`.
2. O backend passa a aceitar Bearer nas rotas de API versionadas (`/api/v1/*`). O ramo de
   token de pending continua restrito à própria rota `/api/pending/<id>` — **não afrouxar**.
3. Tabela **nova** para tokens nativos: `tokenHash` (sha256), `kind` (`access` | `refresh`),
   `deviceName`, `platform`, `expiresAt`, `revokedAt`.
4. Access curto (15–30 min) + refresh longo. **Rotação no refresh**: cada uso emite par novo
   e invalida o anterior; reúso detectado revoga a cadeia inteira.
5. 401 → um refresh → um retry. Se falhar: limpa o Keychain e volta à autenticação.
6. Revogação **por dispositivo** (é o que o usuário precisa ao perder o aparelho) e rate
   limit **por token**, não apenas por IP — cliente móvel atrás de CGNAT colide no limite
   por IP e derruba usuários legítimos.

## Consequências

- Login nativo (OTP) precisa de endpoint próprio que devolva o par de tokens.
- Logout deixa de ser "apagar cookie": precisa revogar o token daquele dispositivo.
- Abre caminho para uma tela de dispositivos conectados no web.