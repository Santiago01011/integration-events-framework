import { ShowToastEvent } from "lightning/platformShowToastEvent";
import {
  subscribe,
  unsubscribe,
  onError,
  isEmpEnabled
} from "lightning/empApi";
import getEventChannel from "@salesforce/apex/IntegrationHealthController.getEventChannel";

const CACHE_TTL_MS = 60000;

function makeKey(params) {
  return JSON.stringify(params || {});
}

const cache = new Map();

export async function fetchPage(apexFetchFn, params = {}, options = {}) {
  const key = makeKey(params);
  const now = Date.now();

  const entry = cache.get(key);
  if (entry && !options.force) {
    if (entry.inFlightPromise) {
      return entry.inFlightPromise;
    }
    if (entry.expiresAt && entry.expiresAt > now) {
      return Promise.resolve(entry.data);
    }
  }

  const inFlightPromise = (async () => {
    try {
      const data = await apexFetchFn(params);
      const expiresAt = Date.now() + (options.ttlMs || CACHE_TTL_MS);
      cache.set(key, { data, expiresAt });
      return data;
    } catch (err) {
      cache.delete(key);
      throw err;
    }
  })();

  cache.set(key, { inFlightPromise });
  const res = await inFlightPromise;
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

export function debounce(fn, wait = 300) {
  let timeout;
  return function (...args) {
    clearTimeout(timeout);
    return new Promise((resolve) => {
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      timeout = setTimeout(() => {
        Promise.resolve(fn.apply(this, args))
          .then(resolve)
          .catch((err) => resolve(Promise.reject(err)));
      }, wait);
    });
  };
}

/**
 * @description Standardized error message extraction from Apex/LWC errors
 */
export function resolveErrorMessage(error) {
  if (!error) return "Unknown error";
  if (Array.isArray(error.body))
    return error.body.map((entry) => entry.message).join(", ");
  if (error.body && typeof error.body.message === "string")
    return error.body.message;
  if (typeof error.message === "string") return error.message;
  if (typeof error.body === "string") return error.body;
  return JSON.stringify(error);
}

/**
 * @description Dispatches a ShowToastEvent
 */
export function showToast(component, title, message, variant = "info") {
  component.dispatchEvent(new ShowToastEvent({ title, message, variant }));
}

/**
 * @description Convenience wrapper for error toasts
 */
export function showError(component, title, message) {
  showToast(component, title, message, "error");
}

let subscriptionState = {
  channelName: null,
  subscriptionByComponent: new Map(), // component -> subscription
  reconnectAttempts: 0,
  maxRetries: 3
};

/**
 * @description Real-time event handling utilities
 */
export async function initRealtime(component, onEvent) {
  if (!isEmpEnabled()) return;

  try {
    if (!subscriptionState.channelName) {
      subscriptionState.channelName = await getEventChannel();
    }

    if (subscriptionState.subscriptionByComponent.has(component)) {
      unsubscribeFromLogs(component);
    }

    const sub = await subscribe(subscriptionState.channelName, -1, (event) => {
      subscriptionState.reconnectAttempts = 0;
      if (onEvent) onEvent(event.data.payload);
    });

    subscriptionState.subscriptionByComponent.set(component, sub);

    onError((error) => {
      const errorMsg = resolveErrorMessage(error);
      if (isTokenExpired(errorMsg)) {
        handleTokenExpired(component, onEvent);
      }
    });
  } catch (error) {
    showError(
      component,
      "Real-time connection failed",
      resolveErrorMessage(error)
    );
  }
}

export function unsubscribeFromLogs(component) {
  const sub = subscriptionState.subscriptionByComponent.get(component);
  if (sub) {
    unsubscribe(sub, () => {});
    subscriptionState.subscriptionByComponent.delete(component);
  }
}

function handleTokenExpired(component, onEvent) {
  if (subscriptionState.reconnectAttempts >= subscriptionState.maxRetries) {
    showError(
      component,
      "Connection Lost",
      "Lost connection to real-time updates. Please refresh the page."
    );
    return;
  }
  subscriptionState.reconnectAttempts++;
  unsubscribeFromLogs(component);
  initRealtime(component, onEvent);
}

export function isTokenExpired(errorMsg) {
  if (!errorMsg) return false;
  const lower = errorMsg.toLowerCase();
  return (
    lower.includes("403") ||
    lower.includes("unknown client") ||
    lower.includes("session") ||
    lower.includes("unauthorized")
  );
}

export default {
  fetchPage,
  clearCache,
  invalidateForRecord,
  getCacheSnapshot,
  debounce,
  resolveErrorMessage,
  showToast,
  showError,
  initRealtime,
  unsubscribeFromLogs,
  isTokenExpired,
  isEmpEnabled
};
