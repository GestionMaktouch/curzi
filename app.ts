import type { Answer, Result, Sources, Storage } from './app.contract.d.ts';
import { acknowledge, unfinishedPurchases } from '@exact/purchases';
import { CURRENCIES } from './currencies.ts';

// Mid-market rates against USD from the Exchange Rate API's free feed (daily, no key).
// Terms: https://www.exchangerate-api.com/terms (attribution shown in Settings).
const ORIGIN = 'https://open.er-api.com';
const API = `${ORIGIN}/v6/latest/USD`;
const CACHE = 'app:/data/rates.json';
export const grants = [`net.fetch ${ORIGIN}`, `fs.read ${CACHE}`, `fs.write ${CACHE}`].join('\n');

type Feed = { date: string; updatedAt: number; rates: Record<string, number> };
type Loaded = Feed & { stale: boolean };

const decode = (bytes: ArrayBuffer | Uint8Array) => new TextDecoder().decode(bytes);
const encode = (text: string) => new TextEncoder().encode(text);

function isFeed(x: unknown): x is Feed {
  if (x === null || typeof x !== 'object') return false;
  const f = x as { date?: unknown; updatedAt?: unknown; rates?: unknown };
  return typeof f.date === 'string' && typeof f.updatedAt === 'number' && f.rates !== null && typeof f.rates === 'object'
    && Object.values(f.rates as object).every((v) => typeof v === 'number' && Number.isFinite(v));
}

async function readCache(storage: Storage): Promise<Feed | null> {
  try {
    const parsed: unknown = JSON.parse(decode(await storage.fs.readFile(CACHE)));
    return isFeed(parsed) ? parsed : null;
  } catch {
    return null; // no file yet, or unreadable: as a fresh install
  }
}

async function fetchFeed(): Promise<Feed> {
  const response = await fetch(API, { exactTimeout: 10000 });
  if (!response.ok) throw new Error(`The rate feed answered ${response.status}.`);
  const body: unknown = await response.json();
  const b = body as { result?: unknown; time_last_update_unix?: unknown; rates?: unknown };
  if (b.result !== 'success' || typeof b.time_last_update_unix !== 'number' || b.rates === null || typeof b.rates !== 'object') {
    throw new Error('The rate feed answered something else.');
  }
  const rates: Record<string, number> = {};
  for (const [code, rate] of Object.entries(b.rates as Record<string, unknown>)) {
    if (typeof rate === 'number' && Number.isFinite(rate) && rate > 0) rates[code] = rate;
  }
  if (!('USD' in rates)) throw new Error('The rate feed has no base.');
  const updatedAt = b.time_last_update_unix * 1000;
  return { date: new Date(updatedAt).toISOString().slice(0, 10), updatedAt, rates };
}

// One load at a time; what it found stays in memory for `loadRows`, and on disk for offline.
let loaded: Loaded | null = null;
let loading: Promise<Loaded> | null = null;
function load(storage: Storage): Promise<Loaded> {
  loading ??= (async () => {
    const cached = await readCache(storage);
    try {
      const fresh = await fetchFeed();
      // The cache is a convenience: a write that fails (storage refused) never loses the answer.
      try { await storage.fs.atomicWriteFile(CACHE, encode(JSON.stringify(fresh))); } catch { /* next launch fetches again */ }
      return { ...fresh, stale: false };
    } catch (e) {
      if (cached) return { ...cached, stale: true };
      throw e;
    }
  })().then((it) => { loaded = it; loading = null; return it; }, (e) => { loading = null; throw e; });
  return loading;
}

const byCode = new Map(CURRENCIES.map((c) => [c.code, c]));

// `5×100÷7` → 71.43: + − × ÷ % with the usual precedence, left to right. While the person is still
// typing, a trailing operator or point is ignored; anything else that does not parse is `ok: false`.
export function evaluate(expr: string): { value: number; ok: boolean } {
  let s = expr.replace(/[×xX*]/g, '*').replace(/÷/g, '/').replace(/[−–]/g, '-').replace(/[,\s]/g, '');
  s = s.replace(/[+\-*/%.]+$/, '');
  if (s === '') return { value: 0, ok: true };
  const tokens = s.match(/\d*\.?\d+|[+\-*/%]/g) ?? [];
  if (tokens.join('') !== s) return { value: 0, ok: false };
  const values: number[] = [];
  const ops: string[] = [];
  const rank = (op: string) => (op === '+' || op === '-' ? 1 : 2);
  const apply = () => {
    const op = ops.pop();
    const b = values.pop();
    const a = values.pop();
    if (op === undefined || a === undefined || b === undefined) return false;
    values.push(op === '+' ? a + b : op === '-' ? a - b : op === '*' ? a * b : op === '/' ? a / b : a % b);
    return true;
  };
  let expectNumber = true;
  for (const t of tokens) {
    if (/^[+\-*/%]$/.test(t)) {
      if (expectNumber) return { value: 0, ok: false };
      while (ops.length && rank(ops[ops.length - 1]) >= rank(t)) if (!apply()) return { value: 0, ok: false };
      ops.push(t);
      expectNumber = true;
    } else {
      if (!expectNumber) return { value: 0, ok: false };
      values.push(Number(t));
      expectNumber = false;
    }
  }
  if (expectNumber) return { value: 0, ok: false };
  while (ops.length) if (!apply()) return { value: 0, ok: false };
  const value = values[0] ?? 0;
  return Number.isFinite(value) ? { value, ok: true } : { value: 0, ok: false };
}

const sources: Sources = {
  evaluate: async ([expr]): Promise<Result<'evaluate'>> => evaluate(expr),
  allCurrencies: async (): Promise<Result<'allCurrencies'>> => CURRENCIES.map(({ code, name, flag }) => ({ code, name, flag })),
  loadRates: async (_args, _store, storage): Promise<Result<'loadRates'>> => {
    const it = await load(storage);
    return { date: it.date, updatedAt: it.updatedAt, stale: it.stale };
  },
  // The favourites, in the person's order, each with its rate; a code the feed lacks gets 0 and shows 0.00.
  loadRows: async ([codes], _store, storage): Promise<Result<'loadRows'>> => {
    const it = loaded ?? await load(storage).catch(() => null);
    return codes.map((code) => {
      const c = byCode.get(code) ?? { code, name: code, flag: '🏳️' };
      return { code: c.code, name: c.name, flag: c.flag, rate: it?.rates[code] ?? 0 };
    });
  },
  // The one place a purchase is finished, however it arrived; what the person holds is `listPurchases`'.
  deliverPurchases: async (): Promise<Result<'deliverPurchases'>> => {
    let finished = 0;
    for (const p of await unfinishedPurchases()) {
      if (p.purchaseState !== 'purchased') continue;
      try {
        await acknowledge({ purchaseToken: p.purchaseToken });
        finished += 1;
      } catch {
        // Not finished: the store keeps it in the queue and the next answer tries again.
      }
    }
    return { finished };
  },
};
export const answer: Answer = (source, args, store, storage, native) => sources[source](args, store, storage, native);
