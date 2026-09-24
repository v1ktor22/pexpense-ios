# ADR-0001 — Cliente fino (thin client) sobre o backend existente

- **Status:** aceito
- **Data:** 2026-09-22

## Contexto

O Pexpense já tem backend em produção (SvelteKit 2 + Drizzle/SQLite, `packages/web`)
e outros clientes ativos: web, bot Telegram e Mini App `/m`. O app iOS é um cliente novo
sobre infraestrutura existente.

## Decisão

O app iOS é um cliente fino: nenhuma regra de negócio, cálculo, validação ou persistência
local. O backend é a única fonte da verdade. Offline existe apenas como cache de leitura,
descartável a qualquer momento.

Alternativas descartadas:

- **Reimplementar a lógica em Swift.** Cria uma segunda implementação do mesmo produto e
  quebra multi-dispositivo, web e bot. Só faria sentido em app local-only, sem sync.
- **Banco local com sync bidirecional.** Complexidade de resolução de conflito sem
  benefício: o backend está sempre alcançável para escrita.

## Consequências

- Feature nova exige mudança no backend antes do app — a ordem não é negociável.
- O app é fino o suficiente para que o compilador seja o principal portão de qualidade.
- O valor do cliente nativo está no que o PWA não entrega: câmera/OCR de recibo, Face ID,
  widgets, push, presença na loja. Sem esse diferencial, o custo de manter dois clientes
  não se paga.