# 🔄 05. Workflow: The PDD Lifecycle

This distinct workflow ensures that packages remain stable and versioned correctly.

## High Level Flow

1.  **Develop** in Scratch Org.
2.  **Commit** to Git.
3.  **Validate** via CI (Run Package Tests).
4.  **Package** Version Creation.
5.  **Promote** to Sandbox (Install).
6.  **Verify** in Sandbox (Run Org Integration Tests).

## Detailed Steps

### Step 1: Feature Branch

Create a new branch for your feature: `feature/cool-new-calc`.

### Step 2: Scratch Org Development

```bash
sf org create scratch -d 30 -f config/project-scratch-def.json -a my-scratch
sf project deploy start
```

### Step 3: Iterate & Test

Write your code and your **Package Tests**.
Run them locally:

```bash
sf apex run test --code-coverage --result-format human
```

### Step 4: Create Package Version (CI)

When you open a Pull Request, the CI system should:

1.  Create a fresh Scratch Org.
2.  Install the package.
3.  Run the tests.
4.  If successful, create a beta version:
    ```bash
    sf package version create --package "MyPackage" --installation-key "123456" --wait 10
    ```

### Step 5: Install & Verify (Sandbox)

Install the beta version in your Sandbox:

```bash
sf package install --package "04t..." --target-org my-sandbox
```

**CRITICAL**: Do _not_ deploy the source code to the Sandbox. Install the _package version_.

### Step 6: Release

Once verified, promote the package version to released status:

```bash
sf package version promote --package "04t..."
```

This artifact is now ready for Production.
