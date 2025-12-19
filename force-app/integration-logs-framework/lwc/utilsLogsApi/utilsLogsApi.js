// Lightweight logs data service with in-memory cache, TTL, in-flight dedupe and simple debounce
const CACHE_TTL_MS = 60000; // default 60s

function makeKey(params) {
    // Only include relevant params for cache key
    const { pageSize, statusFilter, search, lastCreatedDate, lastId } = params || {};
    return JSON.stringify({ pageSize, statusFilter, search, lastCreatedDate, lastId });
}

function uuidv4() {
    // simple UUID generator (RFC4122 version 4 style)
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

const cache = new Map();

// in-flight dedupe: store promise on cache entry while request is ongoing
export async function fetchPage(apexFetchFn, params = {}, options = {}) {
    // apexFetchFn: a function that receives params and returns a Promise resolving to { records, hasMore }
    const key = makeKey(params);
    const now = Date.now();

    const entry = cache.get(key);
    if (entry) {
        if (entry.inFlightPromise) {
            return entry.inFlightPromise;
        }
        if (entry.expiresAt && entry.expiresAt > now && !options.force) {
            return Promise.resolve(entry.data);
        }
    }

    // create placeholder
    const inFlightPromise = (async () => {
        const correlationId = uuidv4();
        try {
            const payload = Object.assign({}, params, { correlationId });
            const data = await apexFetchFn(payload);
            const expiresAt = Date.now() + (options.ttlMs || CACHE_TTL_MS);
            cache.set(key, { data, expiresAt });
            return data;
        } catch (err) {
            // on error, remove the cache entry to avoid serving stale promises
            cache.delete(key);
            throw err;
        }
    })();

    cache.set(key, { inFlightPromise });
    const res = await inFlightPromise;
    // clear inFlightPromise (store resolved data already set)
    const final = cache.get(key) || { data: res };
    delete final.inFlightPromise;
    cache.set(key, final);
    return res;
}

export function clearCache(keyPattern) {
    if (!keyPattern) {
        cache.clear();
        return;
    }
    // delete keys that include the pattern string
    for (const key of Array.from(cache.keys())) {
        if (key.includes(keyPattern)) {
            cache.delete(key);
        }
    }
}

export function invalidateForRecord() {
    // conservative invalidation: clear entire cache when we cannot determine affected keys
    // record expected to be an object with fields that may match filters (Id, CreatedDate, ObservationType__c, etc.)
    // For now, clear all entries. This is safe and simple; we can refine later.
    cache.clear();
}

export function getCacheSnapshot() {
    const out = {};
    for (const [k, v] of cache.entries()) {
        out[k] = { hasData: !!v.data, expiresAt: v.expiresAt };
    }
    return out;
}

// debounce helper returning a wrapper that delays calls
export function debounce(fn, wait = 300) {
    let timeout;
    return function (...args) {
        clearTimeout(timeout);
        return new Promise((resolve) => {
            // setTimeout is intentionally used here for debounce delay
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            timeout = setTimeout(() => {
                Promise.resolve(fn.apply(this, args)).then(resolve).catch(err => resolve(Promise.reject(err)));
            }, wait);
        });
    };
}

export default {
    fetchPage,
    clearCache,
    invalidateForRecord,
    getCacheSnapshot,
    debounce
};
