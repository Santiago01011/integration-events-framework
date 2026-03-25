const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith("--")) {
      continue;
    }
    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) {
      args[key] = "true";
      continue;
    }
    args[key] = next;
    i += 1;
  }
  return args;
}

function runGitDiff(base, head) {
  const args = ["diff", "--name-only", "--relative"];
  if (base && head) {
    args.push(base, head);
  } else {
    args.push("HEAD~1", "HEAD");
  }

  try {
    const output = execFileSync("git", args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"]
    });
    return output
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean);
  } catch (error) {
    if (base || head) {
      throw error;
    }

    const fallback = execFileSync("git", ["ls-files"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"]
    });
    return fallback
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean);
  }
}

function loadPackageMap() {
  const packageMapPath = path.join(
    __dirname,
    "..",
    "config",
    "package-map.json"
  );
  const raw = fs.readFileSync(packageMapPath, "utf8");
  const parsed = JSON.parse(raw);

  if (!Array.isArray(parsed.packages) || parsed.packages.length === 0) {
    throw new Error(
      "config/package-map.json must define a non-empty packages array"
    );
  }

  return parsed;
}

function buildPackageIndex(packageMap) {
  const byKey = new Map();
  for (const pkg of packageMap.packages) {
    byKey.set(pkg.key, pkg);
  }
  return byKey;
}

function fileMatchesPrefix(filePath, prefix) {
  return filePath === prefix || filePath.startsWith(`${prefix}/`);
}

function detectDirectChanges(files, packageMap) {
  const changedKeys = new Set();
  let fullRebuild = false;

  for (const file of files) {
    if (
      Array.isArray(packageMap.globalTriggers) &&
      packageMap.globalTriggers.some((prefix) =>
        fileMatchesPrefix(file, prefix)
      )
    ) {
      fullRebuild = true;
    }

    for (const pkg of packageMap.packages) {
      if (fileMatchesPrefix(file, pkg.path)) {
        changedKeys.add(pkg.key);
      }
    }
  }

  if (fullRebuild) {
    for (const pkg of packageMap.packages) {
      changedKeys.add(pkg.key);
    }
  }

  return {
    changedKeys,
    fullRebuild
  };
}

function expandDependents(initialKeys, packageMap) {
  const dependentsByKey = new Map();
  for (const pkg of packageMap.packages) {
    for (const dependency of pkg.dependencies || []) {
      if (!dependentsByKey.has(dependency)) {
        dependentsByKey.set(dependency, []);
      }
      dependentsByKey.get(dependency).push(pkg.key);
    }
  }

  const expanded = new Set(initialKeys);
  const queue = [...initialKeys];

  while (queue.length > 0) {
    const current = queue.shift();
    const dependents = dependentsByKey.get(current) || [];
    for (const dependent of dependents) {
      if (!expanded.has(dependent)) {
        expanded.add(dependent);
        queue.push(dependent);
      }
    }
  }

  return expanded;
}

function topologicalSort(keys, packageMap) {
  const selected = new Set(keys);
  const sorted = [];
  const visiting = new Set();
  const visited = new Set();
  const byKey = buildPackageIndex(packageMap);

  function visit(key) {
    if (visited.has(key) || !selected.has(key)) {
      return;
    }
    if (visiting.has(key)) {
      throw new Error(`Circular package dependency detected at ${key}`);
    }

    const pkg = byKey.get(key);
    if (!pkg) {
      throw new Error(`Unknown package key in dependency graph: ${key}`);
    }

    visiting.add(key);
    for (const dependency of pkg.dependencies || []) {
      if (selected.has(dependency)) {
        visit(dependency);
      }
    }
    visiting.delete(key);
    visited.add(key);
    sorted.push(key);
  }

  for (const key of keys) {
    visit(key);
  }

  return sorted;
}

function buildResult(files, packageMap) {
  const { changedKeys, fullRebuild } = detectDirectChanges(files, packageMap);
  const impactedKeys = expandDependents(changedKeys, packageMap);
  const buildOrder = topologicalSort([...impactedKeys], packageMap);
  const directBuildOrder = topologicalSort([...changedKeys], packageMap);
  const impactedPackages = buildOrder.map((key) =>
    packageMap.packages.find((pkg) => pkg.key === key)
  );
  const directlyChangedPackages = directBuildOrder.map((key) =>
    packageMap.packages.find((pkg) => pkg.key === key)
  );

  return {
    changedFiles: files,
    fullRebuild,
    directlyChangedPackages: directlyChangedPackages.map((pkg) => pkg.key),
    directlyChangedPackagePaths: directlyChangedPackages.map((pkg) => pkg.path),
    impactedPackages: impactedPackages.map((pkg) => ({
      key: pkg.key,
      path: pkg.path,
      packageAlias: pkg.packageAlias,
      dependencies: pkg.dependencies || []
    })),
    impactedPackageKeys: impactedPackages.map((pkg) => pkg.key),
    impactedPackagePaths: impactedPackages.map((pkg) => pkg.path),
    buildOrder,
    directBuildOrder
  };
}

function writeGithubOutput(result, outputPath) {
  const impacted = result.impactedPackageKeys.join(",");
  const direct = result.directlyChangedPackages.join(",");
  const changedFiles = JSON.stringify(result.changedFiles);
  const buildOrder = JSON.stringify(result.buildOrder);
  const directBuildOrder = JSON.stringify(result.directBuildOrder);
  const impactedPackagePaths = JSON.stringify(result.impactedPackagePaths);
  const directlyChangedPackagePaths = JSON.stringify(
    result.directlyChangedPackagePaths
  );
  const payload = JSON.stringify(result);

  const lines = [
    `impacted_packages=${impacted}`,
    `directly_changed_packages=${direct}`,
    `full_rebuild=${String(result.fullRebuild)}`,
    `build_order=${buildOrder}`,
    `direct_build_order=${directBuildOrder}`,
    `impacted_package_paths=${impactedPackagePaths}`,
    `directly_changed_package_paths=${directlyChangedPackagePaths}`,
    `changed_files=${changedFiles}`,
    `result_json=${payload}`
  ];

  fs.appendFileSync(outputPath, `${lines.join("\n")}\n`);
}

function writeGithubSummary(result, summaryPath) {
  const lines = [
    "## Package Impact",
    "",
    `- Full rebuild: \`${result.fullRebuild}\``,
    `- Directly changed packages: \`${result.directlyChangedPackages.join(",") || "none"}\``,
    `- Impacted packages: \`${result.impactedPackageKeys.join(",") || "none"}\``,
    `- Build order: \`${result.buildOrder.join(" -> ") || "none"}\``,
    `- Direct build order: \`${result.directBuildOrder.join(" -> ") || "none"}\``,
    ""
  ];

  if (result.changedFiles.length > 0) {
    lines.push("### Changed Files", "");
    for (const file of result.changedFiles) {
      lines.push(`- \`${file}\``);
    }
    lines.push("");
  }

  fs.appendFileSync(summaryPath, `${lines.join("\n")}\n`);
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const packageMap = loadPackageMap();
  const files = runGitDiff(args.base, args.head);
  const result = buildResult(files, packageMap);

  if (args["github-output"]) {
    writeGithubOutput(result, args["github-output"]);
  }

  if (args["github-summary"]) {
    writeGithubSummary(result, args["github-summary"]);
  }

  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}

main();
