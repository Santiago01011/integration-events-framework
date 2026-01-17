import logsApi from "c/utilsLogsApi";

describe("logsApi service", () => {
  let mockApexFn;

  beforeEach(() => {
    mockApexFn = jest.fn();
    logsApi.clearCache();
  });

  afterEach(() => {
    jest.clearAllMocks();
    logsApi.clearCache();
  });

  describe("fetchPage", () => {
    it("should call Apex function and cache result", async () => {
      const mockData = { records: [{ Id: "1", Name: "Test" }], hasMore: false };
      mockApexFn.mockResolvedValue(mockData);

      const result = await logsApi.fetchPage(mockApexFn, { pageSize: 20 });

      expect(mockApexFn).toHaveBeenCalledTimes(1);
      expect(result).toEqual(mockData);
    });

    it("should return cached result on second call with same params", async () => {
      const mockData = { records: [{ Id: "1" }], hasMore: false };
      mockApexFn.mockResolvedValue(mockData);
      const params = { pageSize: 20, statusFilter: "All" };

      await logsApi.fetchPage(mockApexFn, params);
      const result2 = await logsApi.fetchPage(mockApexFn, params);

      expect(mockApexFn).toHaveBeenCalledTimes(1);
      expect(result2).toEqual(mockData);
    });

    it("should not cache result if different params are used", async () => {
      const mockData1 = { records: [{ Id: "1" }], hasMore: false };
      const mockData2 = { records: [{ Id: "2" }], hasMore: false };
      mockApexFn
        .mockResolvedValueOnce(mockData1)
        .mockResolvedValueOnce(mockData2);

      const result1 = await logsApi.fetchPage(mockApexFn, { pageSize: 20 });
      const result2 = await logsApi.fetchPage(mockApexFn, { pageSize: 50 });

      expect(mockApexFn).toHaveBeenCalledTimes(2);
      expect(result1).toEqual(mockData1);
      expect(result2).toEqual(mockData2);
    });

    it("should coalesce in-flight requests with same params", async () => {
      const mockData = { records: [{ Id: "1" }], hasMore: false };
      // Delay Apex call to allow multiple concurrent fetches
      mockApexFn.mockImplementation(
        () =>
          new Promise((resolve) =>
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => resolve(mockData), 50)
          )
      );

      const params = { pageSize: 20 };
      const p1 = logsApi.fetchPage(mockApexFn, params);
      const p2 = logsApi.fetchPage(mockApexFn, params);
      const [result1, result2] = await Promise.all([p1, p2]);

      expect(mockApexFn).toHaveBeenCalledTimes(1);
      expect(result1).toEqual(mockData);
      expect(result2).toEqual(mockData);
    });

    it("should force refresh cache when force: true is passed", async () => {
      const mockData1 = { records: [{ Id: "1" }], hasMore: false };
      const mockData2 = { records: [{ Id: "2" }], hasMore: false };
      mockApexFn
        .mockResolvedValueOnce(mockData1)
        .mockResolvedValueOnce(mockData2);

      const params = { pageSize: 20 };
      const result1 = await logsApi.fetchPage(mockApexFn, params);
      const result2 = await logsApi.fetchPage(mockApexFn, params, {
        force: true
      });

      expect(mockApexFn).toHaveBeenCalledTimes(2);
      expect(result1).toEqual(mockData1);
      expect(result2).toEqual(mockData2);
    });

    it("should remove cache entry on Apex error", async () => {
      mockApexFn.mockRejectedValueOnce(new Error("Apex error"));
      const params = { pageSize: 20 };

      try {
        await logsApi.fetchPage(mockApexFn, params);
      } catch {
        // expected
      }

      mockApexFn.mockResolvedValueOnce({ records: [], hasMore: false });
      const result = await logsApi.fetchPage(mockApexFn, params);

      expect(mockApexFn).toHaveBeenCalledTimes(2);
      expect(result).toEqual({ records: [], hasMore: false });
    });

    it("should respect custom TTL option", async () => {
      jest.useFakeTimers();
      const mockData = { records: [{ Id: "1" }], hasMore: false };
      mockApexFn.mockResolvedValue(mockData);
      const params = { pageSize: 20 };

      // First fetch with short TTL
      await logsApi.fetchPage(mockApexFn, params, { ttlMs: 100 });

      // Advance time past TTL
      jest.advanceTimersByTime(101);

      // Second fetch should call Apex again
      mockApexFn.mockResolvedValueOnce({
        records: [{ Id: "2" }],
        hasMore: false
      });
      const result = await logsApi.fetchPage(mockApexFn, params);

      expect(mockApexFn).toHaveBeenCalledTimes(2);
      expect(result).toEqual({ records: [{ Id: "2" }], hasMore: false });

      jest.useRealTimers();
    });
  });

  describe("clearCache", () => {
    it("should clear entire cache when no pattern provided", async () => {
      const mockData = { records: [], hasMore: false };
      mockApexFn.mockResolvedValue(mockData);

      await logsApi.fetchPage(mockApexFn, {
        pageSize: 20,
        statusFilter: "All"
      });
      await logsApi.fetchPage(mockApexFn, {
        pageSize: 50,
        statusFilter: "New"
      });

      logsApi.clearCache();

      // Reset mocks and refetch
      mockApexFn.mockClear();
      mockApexFn.mockResolvedValue(mockData);

      await logsApi.fetchPage(mockApexFn, {
        pageSize: 20,
        statusFilter: "All"
      });

      expect(mockApexFn).toHaveBeenCalledTimes(1);
    });

    it("should clear cache entries matching a pattern", async () => {
      const mockData = { records: [], hasMore: false };
      mockApexFn.mockResolvedValue(mockData);

      await logsApi.fetchPage(mockApexFn, {
        pageSize: 20,
        statusFilter: "All"
      });
      await logsApi.fetchPage(mockApexFn, {
        pageSize: 20,
        statusFilter: "New"
      });

      logsApi.clearCache('"statusFilter":"All"');

      mockApexFn.mockClear();
      mockApexFn.mockResolvedValue(mockData);

      // Fetching with 'All' should hit Apex again
      await logsApi.fetchPage(mockApexFn, {
        pageSize: 20,
        statusFilter: "All"
      });
      // Fetching with 'New' should still be cached
      await logsApi.fetchPage(mockApexFn, {
        pageSize: 20,
        statusFilter: "New"
      });

      expect(mockApexFn).toHaveBeenCalledTimes(1);
    });
  });

  describe("invalidateForRecord", () => {
    it("should clear all cache entries", async () => {
      const mockData = { records: [], hasMore: false };
      mockApexFn.mockResolvedValue(mockData);

      await logsApi.fetchPage(mockApexFn, { pageSize: 20 });
      await logsApi.fetchPage(mockApexFn, { pageSize: 50 });

      logsApi.invalidateForRecord();

      mockApexFn.mockClear();
      mockApexFn.mockResolvedValue(mockData);

      await logsApi.fetchPage(mockApexFn, { pageSize: 20 });

      expect(mockApexFn).toHaveBeenCalledTimes(1);
    });
  });

  describe("getCacheSnapshot", () => {
    it("should return cache state", async () => {
      const mockData = { records: [], hasMore: false };
      mockApexFn.mockResolvedValue(mockData);

      await logsApi.fetchPage(mockApexFn, {
        pageSize: 20,
        statusFilter: "All"
      });

      const snapshot = logsApi.getCacheSnapshot();

      expect(Object.keys(snapshot).length).toBe(1);
      const entries = Object.values(snapshot);
      expect(entries[0]).toHaveProperty("hasData", true);
      expect(entries[0]).toHaveProperty("expiresAt");
      expect(typeof entries[0].expiresAt).toBe("number");
    });

    it("should show empty cache when nothing is cached", () => {
      const snapshot = logsApi.getCacheSnapshot();
      expect(snapshot).toEqual({});
    });
  });

  describe("debounce", () => {
    it("should delay function execution", async () => {
      jest.useFakeTimers();
      const mockFn = jest.fn();
      const debouncedFn = logsApi.debounce(mockFn, 300);

      debouncedFn();
      debouncedFn();
      debouncedFn();

      expect(mockFn).not.toHaveBeenCalled();

      jest.advanceTimersByTime(300);
      await Promise.resolve();

      expect(mockFn).toHaveBeenCalledTimes(1);

      jest.useRealTimers();
    });

    it("should pass arguments to debounced function", async () => {
      jest.useFakeTimers();
      const mockFn = jest.fn().mockResolvedValue("result");
      const debouncedFn = logsApi.debounce(mockFn, 100);

      debouncedFn("arg1", "arg2");

      jest.advanceTimersByTime(100);
      await Promise.resolve();

      expect(mockFn).toHaveBeenCalledWith("arg1", "arg2");

      jest.useRealTimers();
    });

    it("should return a promise from debounced function", async () => {
      jest.useFakeTimers();
      const mockFn = jest.fn().mockResolvedValue("result");
      const debouncedFn = logsApi.debounce(mockFn, 100);

      const promise = debouncedFn();
      expect(promise).toBeInstanceOf(Promise);

      jest.advanceTimersByTime(100);
      const result = await promise;

      expect(result).toBe("result");

      jest.useRealTimers();
    });

    it("should handle debounced function errors", async () => {
      jest.useFakeTimers();
      const mockFn = jest.fn().mockRejectedValue(new Error("Test error"));
      const debouncedFn = logsApi.debounce(mockFn, 100);

      const promise = debouncedFn();

      jest.advanceTimersByTime(100);

      await expect(promise).rejects.toThrow("Test error");

      jest.useRealTimers();
    });
  });
});
