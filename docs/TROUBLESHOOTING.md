# IED Troubleshooting Guide

## 1. Events Not Appearing in Dashboard

### Checklist

1.  **Is the "Kill Switch" enabled?**
    - Navigate to **Custom Metadata Types** > **Integration Definition**.
    - Find your Integration Code.
    - Ensure the `Enabled__c` checkbox is checked.

2.  **Does the User have Permissions?**
    - Users need `Integration_Dashboard_Read` Permission Set to visualize the dashboard.
    - Users need `Integration_Dashboard_Admin` to manage the registry.

3.  **Is Streaming API Enabled?**
    - Go to **Setup** > **User Interface** > **User Interface**.
    - Ensure "Enable Streaming API" is checked.

---

## 2. "Pending" Status Stuck

If events show purely as "Pending" or gray icons:

- The `IEDEventHub` component might not be loaded on the page.
- The Platform Event listener failed to subscribe. Refresh the page.

---

## 3. Toast Notifications Not Showing

- Check browser console for "EMP API connection error".

---

## 4. "Dependency Error" on Install

If you encounter errors during package installation:

- Local tests in your org must pass before installing the package.
- Check if you have conflicting metadata names in your org.
