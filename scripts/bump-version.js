const { spawnSync } = require("child_process");
const path = require("path");

const delegatedScript = path.join(__dirname, "bump-package-version.js");
const result = spawnSync(
  process.execPath,
  [delegatedScript, "--default", "--part", "patch"],
  {
    stdio: "inherit"
  }
);

process.exit(result.status === null ? 1 : result.status);
