# Estado do projeto

- **Atualizado em:** 2026-09-25
- **Fase:** 3 (Fatia vertical de Edição e Exclusão de Despesas concluída)
- **Contrato OpenAPI:** `docs/api/openapi.json` e `Pexpense/API/openapi.json` (sha `a95d2842593666e09b3ad3aa829e656bb78ef64ad38230e0bea0ac50551abb20`, 16 caminhos)
- **Repositório do backend:** `/Users/silva/Documents/repositories-dev/devpexpense` (fora deste workspace).

## O que existe e está pronto nesta fatia

- **OpenAPI Integration:**
  - `docs/api/openapi.json` e `Pexpense/API/openapi.json` sincronizados via `./scripts/sync-openapi.sh` (16 caminhos ativos, incluindo `PATCH /api/v1/expenses/{id}` e `DELETE /api/v1/expenses/{id}`).
- **Camada de Rede:**
  - `updateExpense`: envia requisição `PATCH /api/v1/expenses/{id}` parcial, enviando somente campos alterados e com `amountInUnits` em unidades. Trata `VALIDATION_ERROR` (com `field`) e `NOT_FOUND_EXPENSE`.
  - `deleteExpense`: envia requisição `DELETE /api/v1/expenses/{id}` sem idempotency key (idempotência nativa de DELETE).
- **Telas e Interface de Usuário:**
  - `Views/EditExpenseView.swift` e `ViewModels/EditExpenseViewModel.swift`: preenche os campos a partir dos centavos recebidos dividindo por 100 (`formatCentimesForFormInput`), calcula diff parcial e envia em unidades no salvamento. Destaque de erros por campo.
  - `Views/ExpenseListView.swift`:
    - Swipe lateral com ação de excluir neutra (rótulo vermelho/neutro conforme HIG e AGENTS.md §4, sem botão vermelho).
    - Modal de confirmação descritivo antes da exclusão.
    - Toque no item ou swipe de edição abre `EditExpenseView` em sheet.
    - Recarrega a lista e o resumo após qualquer alteração.
- **Testes Unitários:**
  - `ExpenseCreationTests`:
    - Testes de ida e volta do dinheiro: 341100 centavos preenche `3411.00` no formulário e gera PATCH com `3411` unidades. 2500 centavos EUR preenche `25.00`.
    - Teste de chamada de exclusão no serviço.
    - Testes de idempotência e persistência mantidos e verdes.

## O que NÃO foi feito (ficou para as próximas fatias)

- **Comprovantes / Recibos:** upload de foto/câmera e OCR (`GET /api/v1/expenses/{id}/receipt`).
- **Charts:** visualização gráfica de `ExpenseCharts`.
- **Regras Recorrentes e Categorias:** gestão completa via tela dedicada.

## Próximos passos

1. Upload e visualização de comprovantes de despesa.
2. Filtros por período e gráficos de resumo.