'use strict';

// Testler için en küçük sahte Firestore + sahte Google Play Developer API.

class Ts {
  constructor(ms) {
    this.ms = ms;
  }
  toMillis() {
    return this.ms;
  }
}

const SERVER_TS = { __serverTimestamp: true };

function clone(v) {
  if (v === SERVER_TS) return new Ts(Date.now());
  if (v instanceof Ts) return new Ts(v.ms);
  if (Array.isArray(v)) return v.map(clone);
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, clone(x)]));
  return v;
}

class Snap {
  constructor(id, data) {
    this.id = id;
    this.exists = data !== undefined;
    this._d = data;
  }
  data() {
    return this._d === undefined ? undefined : clone(this._d);
  }
}

class FakeDb {
  constructor() {
    this.store = new Map(); // "col/id" → data
  }
  collection(col) {
    const db = this;
    return {
      doc(id) {
        return db._ref(col, id);
      },
      where(field, op, value) {
        if (op !== '==') throw new Error('only ==');
        return {
          async get() {
            const docs = [];
            for (const [k, v] of db.store) {
              const [c, id] = k.split('/');
              if (c === col && v[field] === value) docs.push(new Snap(id, v));
            }
            return { docs };
          },
        };
      },
    };
  }
  _ref(col, id) {
    const db = this;
    const key = `${col}/${id}`;
    return {
      id,
      key,
      async get() {
        return new Snap(id, db.store.get(key));
      },
      async set(data, opt) {
        db._set(key, data, opt);
      },
      async update(data) {
        db._update(key, data);
      },
    };
  }
  _set(key, data, opt) {
    const base = opt && opt.merge ? db_get(this, key) || {} : {};
    this.store.set(key, { ...base, ...clone(data) });
  }
  _update(key, data) {
    const cur = this.store.get(key);
    if (!cur) throw Object.assign(new Error('not found'), { code: 5 });
    this.store.set(key, { ...cur, ...clone(data) });
  }
  async getAll(...refs) {
    return refs.map((r) => new Snap(r.id, this.store.get(r.key)));
  }
  async runTransaction(fn) {
    const writes = [];
    const tx = {
      get: async (ref) => new Snap(ref.id, this.store.get(ref.key)),
      set: (ref, data, opt) => writes.push(() => this._set(ref.key, data, opt)),
      update: (ref, data) => writes.push(() => this._update(ref.key, data)),
    };
    const r = await fn(tx);
    for (const w of writes) w();
    return r;
  }
  data(col, id) {
    return this.store.get(`${col}/${id}`);
  }
  put(col, id, data) {
    this.store.set(`${col}/${id}`, clone(data));
  }
}

function db_get(db, key) {
  return db.store.get(key);
}

function fakePublisher(products = {}, voided = []) {
  const calls = { get: 0, ack: 0, list: 0 };
  return {
    calls,
    products,
    async getProduct(productId, token) {
      calls.get++;
      const p = products[token];
      if (!p) throw Object.assign(new Error('Not Found'), { code: 404 });
      if (p.__throw) throw Object.assign(new Error('boom'), { code: p.__throw });
      return { productId, ...p };
    },
    async acknowledge() {
      calls.ack++;
    },
    async listVoided({ pageToken }) {
      calls.list++;
      if (!pageToken) return { voidedPurchases: voided.slice(0, 1), tokenPagination: voided.length > 1 ? { nextPageToken: 'p2' } : undefined };
      return { voidedPurchases: voided.slice(1) };
    },
  };
}

const silent = { info() {}, warn() {}, error() {} };

function makeDeps(over = {}) {
  const db = over.db || new FakeDb();
  return {
    db,
    fv: { serverTimestamp: () => SERVER_TS, ts: (ms) => new Ts(ms) },
    publisher: over.publisher || fakePublisher(),
    bucket: over.bucket,
    now: over.now || (() => Date.UTC(2026, 10, 15, 12, 0, 0)),
    log: silent,
  };
}

module.exports = { FakeDb, Ts, SERVER_TS, fakePublisher, makeDeps };
