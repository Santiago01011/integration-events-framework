const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  moduleNameMapper: {
    "^c/iefPluginCard$":
      "<rootDir>/force-app/integration-logs-framework/main/default/lwc/iefPluginCard/__mocks__/iefPluginCard.js"
  }
};
