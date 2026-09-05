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

- The `iefEventHub` component might not be loaded on the page.
- The Platform Event listener failed to subscribe. Refresh the page.

---

## 3. Toast Notifications Not Showing

- Check browser console for "EMP API connection error".

---

## 4. Dashboard Shows an "Access Restricted" Card

If a user opens the Integration Health Dashboard and sees an access-denied card
instead of data:

- The user is missing the `Integration_Dashboard_Read` permission set (or read
  access to `Integration_Log__c`).
- The dashboard calls `IntegrationHealthController.getDashboardAccess()` before
  any other traffic. When access is denied, the UI renders a friendly
  access-denied card and stops all further Apex calls, LMS subscriptions, and
  EMP/realtime connections.
- Exactly **one** `DASHBOARD_ACCESS_DENIED` observation is published per denied
  load (`FRAMEWORK_INTERNAL` / `DASHBOARD_ACCESS_DENIED`, with the user Id as
  correlation and the reason in the context). Users without event-create
  permissions silently skip this publish — it is best effort.
- If the card appears but the user does have the permission set, check for
  CRUD/FLS denials on `Integration_Log__c`; a first wire/callout error matching
  an access-denied shape (403 / Access Denied / InsufficientAccessRights) also
  switches the dashboard into the denied state.

---

## 5. "Dependency Error" on Install

If you encounter errors during package installation:

- Local tests in your org must pass before installing the package.
- Check if you have conflicting metadata names in your org.
