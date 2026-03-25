const fs = require("fs");
const path = require("path");

const projectJsonPath = path.join(__dirname, "..", "sfdx-project.json");
const packageMapPath = path.join(__dirname, "..", "config", "package-map.json");

function parseArgs(argv) {
  const args = {};

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith("--")) {
      continue;
    }

    const key = token.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith("--")) {
      args[key] = true;
      continue;
    }

    args[key] = next;
    index += 1;
  }

  return args;
}

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function normalizePart(part) {
  const normalized = (part || "patch").toLowerCase();
  if (!["major", "minor", "patch"].includes(normalized)) {
    throw new Error(
      `Invalid bump part "${part}". Expected one of: major, minor, patch`
    );
  }
  return normalized;
}

function getSelector(args) {
  const selectors = [
    { type: "default", value: args.default === true ? "default" : null },
    { type: "packageKey", value: args["package-key"] || null },
    { type: "packageAlias", value: args.package || null },
    { type: "path", value: args.path || null }
  ].filter((entry) => entry.value !== null);

  if (selectors.length === 0) {
    throw new Error(
      "No package selector provided. Use --default, --package-key, --package, or --path"
    );
  }

  if (selectors.length > 1) {
    throw new Error(
      "Provide only one package selector. Use one of --default, --package-key, --package, or --path"
    );
  }

  return selectors[0];
}

function resolvePackageMetadata(selector, packageMap, projectJson) {
  const packageDirectories = Array.isArray(projectJson.packageDirectories)
    ? projectJson.packageDirectories
    : [];
  const mappedPackages = Array.isArray(packageMap.packages)
    ? packageMap.packages
    : [];

  let mappedPackage = null;
  let packageDirectory = null;

  if (selector.type === "default") {
    mappedPackage = mappedPackages.find((pkg) => pkg.default) || null;
    packageDirectory = packageDirectories.find((dir) => dir.default) || null;
  } else if (selector.type === "packageKey") {
    mappedPackage =
      mappedPackages.find((pkg) => pkg.key === selector.value) || null;
    if (mappedPackage) {
      packageDirectory =
        packageDirectories.find(
          (dir) =>
            dir.package === mappedPackage.packageAlias ||
            dir.path === mappedPackage.path
        ) || null;
    }
  } else if (selector.type === "packageAlias") {
    mappedPackage =
      mappedPackages.find((pkg) => pkg.packageAlias === selector.value) || null;
    packageDirectory =
      packageDirectories.find((dir) => dir.package === selector.value) || null;
  } else if (selector.type === "path") {
    mappedPackage =
      mappedPackages.find((pkg) => pkg.path === selector.value) || null;
    packageDirectory =
      packageDirectories.find((dir) => dir.path === selector.value) || null;
  }

  if (!packageDirectory) {
    throw new Error(
      `Could not resolve package directory for selector ${selector.type}=${selector.value}`
    );
  }

  return {
    mappedPackage,
    packageDirectory
  };
}

function parseVersionNumber(versionNumber) {
  const parts = String(versionNumber).split(".");
  if (parts.length < 3) {
    throw new Error(
      `Invalid version format "${versionNumber}". Expected Major.Minor.Patch[.Build]`
    );
  }

  const major = Number.parseInt(parts[0], 10);
  const minor = Number.parseInt(parts[1], 10);
  const patch = Number.parseInt(parts[2], 10);
  const build = parts[3] || "NEXT";

  if ([major, minor, patch].some(Number.isNaN)) {
    throw new Error(
      `Invalid semantic version "${versionNumber}". Major, minor, and patch must be numbers`
    );
  }

  return { major, minor, patch, build };
}

function bumpVersion(parsedVersion, part) {
  const next = { ...parsedVersion };

  if (part === "major") {
    next.major += 1;
    next.minor = 0;
    next.patch = 0;
  } else if (part === "minor") {
    next.minor += 1;
    next.patch = 0;
  } else {
    next.patch += 1;
  }

  return next;
}

function formatVersionNumber(parsedVersion) {
  return [
    parsedVersion.major,
    parsedVersion.minor,
    parsedVersion.patch,
    parsedVersion.build
  ].join(".");
}

function formatVersionName(parsedVersion) {
  return `ver ${parsedVersion.major}.${parsedVersion.minor}.${parsedVersion.patch}`;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const selector = getSelector(args);
  const bumpPart = normalizePart(args.part);
  const dryRun = args["dry-run"] === true;

  const projectJson = loadJson(projectJsonPath);
  const packageMap = fs.existsSync(packageMapPath)
    ? loadJson(packageMapPath)
    : { packages: [] };

  const { mappedPackage, packageDirectory } = resolvePackageMetadata(
    selector,
    packageMap,
    projectJson
  );

  const currentVersion = parseVersionNumber(packageDirectory.versionNumber);
  const nextVersion = bumpVersion(currentVersion, bumpPart);
  const nextVersionNumber = formatVersionNumber(nextVersion);
  const nextVersionName = formatVersionName(nextVersion);

  const targetLabel =
    (mappedPackage && mappedPackage.key) ||
    packageDirectory.package ||
    packageDirectory.path;

  console.log(`Target package: ${targetLabel}`);
  console.log(`Current version number: ${packageDirectory.versionNumber}`);
  console.log(`Current version name: ${packageDirectory.versionName}`);
  console.log(`Bump part: ${bumpPart}`);
  console.log(`Next version number: ${nextVersionNumber}`);
  console.log(`Next version name: ${nextVersionName}`);

  if (dryRun) {
    console.log("Dry run enabled. No files were changed.");
    return;
  }

  packageDirectory.versionNumber = nextVersionNumber;
  packageDirectory.versionName = nextVersionName;

  fs.writeFileSync(
    projectJsonPath,
    `${JSON.stringify(projectJson, null, 2)}\n`,
    "utf8"
  );

  console.log("Successfully updated sfdx-project.json");
}

try {
  main();
} catch (error) {
  console.error(`Error updating package version: ${error.message}`);
  process.exit(1);
}
