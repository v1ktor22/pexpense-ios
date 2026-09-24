# ADR-0004 — Dinheiro, número e locale

- **Status:** aceito — decisão fechada
- **Data:** 2026-09-22

## Contexto

O Pexpense é um produto suíço (CHF padrão, EUR secundário) com usuários francófonos e
anglófonos. Formatação monetária inconsistente é o tipo de defeito que corrói confiança
no produto.

## Decisão

- Moedas suportadas: **CHF** (padrão) e **EUR**.
- Valores trafegam na API como **inteiro em centavos** — confirmado no backend:
  `Math.round(data.amount * 100)` nas rotas de despesa e `integer('amount') // centavos`
  no schema do banco. No Swift: `Int`. Nunca `Double`/`Float`.
- Formatação apenas na apresentação: `NumberFormatter`, locale `de-CH`, composição
  símbolo + valor.
- Separador de milhar fixado em `U+0027` (`'`): `CHF 1'890.00`, `€ 68.50`.
  Verificado em iOS 17+ com Swift 6: o Foundation já produz `U+0027` sem intervenção.
  `groupingSeparator` é definido explicitamente mesmo assim, e o teste unitário permanece
  como guarda de regressão — o ICU varia entre toolchains, e o backend já sofreu com isso.
- i18n: `fr-CH` padrão, `en` secundário. Nenhuma string em português no código ou na UI.

## Consequências

- Teste unitário obrigatório no formatador, afirmando o code point do separador.
- Nenhum cálculo monetário no app: somas, conversões e agregações vêm do backend.