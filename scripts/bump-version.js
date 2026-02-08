const fs = require("fs");
const path = require("path");

const projectJsonPath = path.join(__dirname, "..", "sfdx-project.json");

try {
  const projectJson = JSON.parse(fs.readFileSync(projectJsonPath, "utf8"));

  // Find default package directory
  const defaultPackage = projectJson.packageDirectories.find(
    (dir) => dir.default
  );

  if (!defaultPackage) {
    console.error("No default package directory found in sfdx-project.json");
    process.exit(1);
  }

  console.log(`Current version: ${defaultPackage.versionNumber}`);

  // Parse version number (Major.Minor.Patch.BuildNumber)
  // Example: "1.3.8.NEXT"
  const versionParts = defaultPackage.versionNumber.split(".");

  if (versionParts.length < 3) {
    console.error(
      `Invalid version format: ${defaultPackage.versionNumber}. Expected Major.Minor.Patch.NEXT`
    );
    process.exit(1);
  }

  // Increment patch version
  let patchVersion = parseInt(versionParts[2]);
  patchVersion++;
  versionParts[2] = patchVersion.toString();

  const newVersionNumber = versionParts.join(".");

  // Update versionName if it follows standard pattern "ver X.Y.Z"
  // "ver 1.3.8 - CI/CD Enhancements" -> "ver 1.3.9"
  // We'll keep it simple and just set it to "ver 1.3.9" to be safe and consistent
  const newVersionName = `ver ${versionParts[0]}.${versionParts[1]}.${versionParts[2]}`;

  console.log(`Bumping to version: ${newVersionNumber}`);

  defaultPackage.versionNumber = newVersionNumber;
  defaultPackage.versionName = newVersionName;

  fs.writeFileSync(
    projectJsonPath,
    JSON.stringify(projectJson, null, 2) + "\n"
  ); // Keep formatting
  console.log("Successfully updated sfdx-project.json");
} catch (error) {
  console.error("Error updating version:", error);
  process.exit(1);
}
