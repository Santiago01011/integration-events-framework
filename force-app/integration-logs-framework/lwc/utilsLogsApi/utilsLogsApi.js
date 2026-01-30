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
  subscriptionByComponent: new Map(),
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

// --- Event Transformation Utilities ---

/**
 * @description Returns the icon name for a given severity level.
 * @param {string} severity - The severity level (ERROR, FATAL, WARN, SUCCESS, INFO)
 * @returns {string} The SLDS icon name
 */
export function getIconForSeverity(severity) {
  if (severity === "ERROR" || severity === "FATAL") return "utility:error";
  if (severity === "WARN") return "utility:warning";
  if (severity === "SUCCESS") return "utility:success";
  if (severity === "INFO") return "utility:info";
  return "utility:help";
}

/**
 * @description Transforms a Platform Event payload into a table row format.
 * @param {object} eventPayload - The raw Platform Event payload
 * @param {object} typeToSeverity - Map of observation types to severity levels
 * @param {function} normalizeContext - Function to normalize integration code to display name
 * @returns {object} A row object compatible with the dashboard table
 */
export function transformEventToRow(
  eventPayload,
  typeToSeverity,
  normalizeContext
) {
  const type = (eventPayload.ObservationType__c || "").toUpperCase();
  const severity = typeToSeverity[type];
  const iconName = getIconForSeverity(severity);
  const normalizedName = normalizeContext
    ? normalizeContext(eventPayload.IntegrationCode__c)
    : eventPayload.IntegrationCode__c;

  return {
    Id: `temp-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    IntegrationCode__c: eventPayload.IntegrationCode__c,
    ObservationType__c: eventPayload.ObservationType__c,
    OccurredAt__c: eventPayload.OccurredAt__c || new Date().toISOString(),
    CorrelationId__c: eventPayload.CorrelationId__c,
    Context__c: eventPayload.Context__c,
    Normalized_Context__c: normalizedName,
    contextPreview: normalizedName,
    statusIconName: iconName,
    _isFromEvent: true,
    _severity: severity
  };
}

/**
 * @description Builds a synthetic LogDetailWrapper from a live event row.
 * @param {object} row - The table row object with event data
 * @returns {object} A wrapper object compatible with ihdDetailDrawer
 */
export function buildLocalDetailWrapper(row) {
  return {
    record: {
      Id: row.Id,
      IntegrationCode__c: row.IntegrationCode__c,
      ObservationType__c: row.ObservationType__c,
      OccurredAt__c: row.OccurredAt__c,
      CorrelationId__c: row.CorrelationId__c,
      Context__c: row.Context__c,
      Normalized_Context__c: row.Normalized_Context__c
    },
    severity: row._severity
  };
}

// --- Column Definitions ---

/**
 * @description Base columns for the logs datatable.
 */
export const BASE_COLUMNS = [
  {
    label: "Occurred At",
    fieldName: "OccurredAt__c",
    type: "date",
    typeAttributes: {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit"
    },
    fixedWidth: 200
  },
  {
    label: "Status",
    fieldName: "",
    type: "text",
    fixedWidth: 80,
    cellAttributes: {
      iconName: { fieldName: "statusIconName" },
      iconPosition: "left",
      alignment: "center"
    }
  },
  { label: "Integration", fieldName: "IntegrationCode__c", type: "text" },
  {
    label: "Context",
    fieldName: "contextPreview",
    type: "text",
    wrapText: true,
    cellAttributes: { title: { fieldName: "Normalized_Context__c" } }
  },
  {
    label: "Correlation",
    fieldName: "CorrelationId__c",
    type: "text",
    wrapText: true
  }
];

/**
 * @description Transforms a raw database record into a table row format.
 * @param {object} record - The raw log record
 * @param {object} typeToSeverity - Map of observation types to severity levels
 * @returns {object} The transformed row
 */
export function transformRow(record, typeToSeverity) {
  const type = (record.ObservationType__c || "").toUpperCase();
  const severity = typeToSeverity[type];
  const iconName = getIconForSeverity(severity);

  return {
    ...record,
    contextPreview: record.Normalized_Context__c,
    statusIconName: iconName
  };
}

/**
 * @description Calculates global stats from a list of integration summaries.
 * @param {Array} summaries - List of integration summaries
 * @returns {object} Calculated stats object
 */
export function calculateGlobalStats(summaries) {
  const data = summaries || [];
  let total = 0;
  let errors = 0;
  let success = 0;

  data.forEach((item) => {
    total += item.totalEvents || 0;
    errors += item.errorCount || 0;
    success += item.successCount || 0;
  });

  const successRate = total > 0 ? Math.round((success / total) * 100) : 100;
  const errorRate = 100 - successRate;

  return {
    total,
    errors,
    success,
    successRate,
    errorRate,
    successRateLabel: "Success",
    errorRateLabel: "Errors",
    progressStyle: `background: linear-gradient(90deg, #04844b ${successRate}%, #c23934 ${successRate}%); width: 100%;`
  };
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
  isEmpEnabled,
  getIconForSeverity,
  transformEventToRow,
  buildLocalDetailWrapper,
  BASE_COLUMNS,
  transformRow,
  calculateGlobalStats
};
