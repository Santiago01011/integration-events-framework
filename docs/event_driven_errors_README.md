# Event-Driven Error Logging & Integration Health Dashboard

Complete guide to deploying and using the reusable Integration Health Dashboard architecture across Salesforce orgs.

---

## 1. Overview

The Integration Health Dashboard is a **completely reusable, org-agnostic solution** for real-time monitoring of integration health. It consists of:

- **Platform Event**: `IntegrationEvent__e` - Publishes integration events immediately
- **Custom Object**: `Integration_Log__c` - Persists event data for querying and auditing
- **Event Trigger**: `IntegrationEventTrigger` - Automatically converts events to log records
- **Apex Controller**: `IntegrationHealthController` - Provides data for the dashboard
- **Event Publisher**: `IntegrationEventPublisher` - Utility class to emit events from your code
- **LWC Dashboard**: `integrationHealthDashboard` - Real-time monitoring UI with multiple views

### Key Features

✅ **Real-Time Updates** - Dashboard updates instantly via EMP API when events occur  
✅ **Searchable & Filterable** - Query logs by context, status, date range, payload ID  
✅ **Summary Views** - Overall health + per-integration summaries  
✅ **Org-Agnostic** - Deploy once, configure minimally, use everywhere  
✅ **Lightweight** - Uses platform events to avoid cluttering production with logging  
✅ **Scalable** - Handles high-volume integrations efficiently  

---

## 2. Deployment to a Fresh Org

### Prerequisites

- SFDX CLI installed and configured
- Appropriate Salesforce org access (sandbox or developer org recommended)
- Access to this repository

### Step 1: Deploy Metadata Components

Deploy all integration-related metadata in this specific order:

```bash
# 1. Deploy Platform Event & Custom Object first (schema foundation)
sfdx force:source:deploy -p force-app/main/default/objects/IntegrationEvent__e \
  force-app/main/default/objects/Integration_Log__c \
  -u <YOUR_ORG_ALIAS>

# 2. Deploy Apex classes (controller + publisher)
sfdx force:source:deploy -p force-app/main/default/classes/IntegrationHealthController.cls \
  force-app/main/default/classes/IntegrationEventPublisher.cls \
  -u <YOUR_ORG_ALIAS>

# 3. Deploy the trigger (depends on platform event)
sfdx force:source:deploy -p force-app/main/default/triggers/IntegrationErrorEventTrigger.trigger \
  -u <YOUR_ORG_ALIAS>

# 4. Deploy LWC components (depends on controller)
sfdx force:source:deploy -p force-app/main/default/lwc/integrationHealthDashboard \
  force-app/main/default/lwc/ihdStatsCard \
  force-app/main/default/lwc/ihdTable \
  force-app/main/default/lwc/ihdFilters \
  force-app/main/default/lwc/ihdIntegrationSummaryCard \
  force-app/main/default/lwc/ihdDetailDrawer \
  force-app/main/default/lwc/progressBar \
  force-app/main/default/lwc/lastUpdatedFooter \
  -u <YOUR_ORG_ALIAS>
```

Or, deploy everything at once:

```bash
sfdx force:source:deploy -p force-app/main/default -u <YOUR_ORG_ALIAS>
```

### Step 2: Create Permission Sets

The dashboard requires access to custom objects, Apex classes, and platform events.

#### **Permission Set 1: Integration_Logger_Execute**

Purpose: Allows execution of integration logging functionality

```
Label: Integration Logger Execute
API Name: Integration_Logger_Execute
License: Salesforce Platform

Apex Class Access:
- IntegrationHealthController
- IntegrationEventPublisher

Object Permissions:
- Integration_Log__c: Read, Create, Update
- IntegrationEvent__e: Publish

Custom Permissions: (if you create any)
- PublishIntegrationEvents
```

#### **Permission Set 2: Integration_Dashboard_Read**

Purpose: View the Integration Health Dashboard

```
Label: Integration Dashboard Read
API Name: Integration_Dashboard_Read
License: Salesforce Platform

Apex Class Access:
- IntegrationHealthController (Read only)

Object Permissions:
- Integration_Log__c: Read

Tab Permissions:
- integration-health-dashboard: Read
```

### Step 3: Assign Permission Sets

Assign the permission sets to the users who will:
- **Publish events** (integration developers): `Integration_Logger_Execute`
- **View dashboard** (operations/support): `Integration_Dashboard_Read`

### Step 4: Create a FlexiPage with the Dashboard (Optional)

If you want the dashboard as a tab:

1. Go to **Setup** → **Tabs**
2. Create a new **Lightning Web Component Tab**
3. Select `integrationHealthDashboard`
4. Assign to desired app

Alternatively, add to an existing FlexiPage:

1. **Setup** → **Lightning App Builder** → Create new Lightning App
2. Drag `integrationHealthDashboard` component onto the canvas
3. Save and assign to app

---

## 3. How to Use

### 3.1 Publishing Integration Events from Your Code

#### Basic Usage: Publishing Errors

```apex
// In a try-catch block during an integration
try {
    // Your integration logic
    callExternalAPI();
} catch (Exception ex) {
    IntegrationEventPublisher.publishError(
        'Pedidos',                    // Context (integration name)
        ex,                           // Exception
        payloadId,                    // Optional: reference to payload
        batchJobId                    // Optional: batch job ID
    );
}
```

#### Publishing Business Logic Errors

```apex
// When data validation fails (not an exception)
if (!isValidQuantity(quantity)) {
    IntegrationEventPublisher.publishError(
        'Productos',                  // Context
        'Invalid quantity: ' + quantity,  // Error message
        null,                         // Stack trace (null for business errors)
        payloadId,                    // Payload ID
        jobId                         // Job ID
    );
}
```

#### Publishing Success/Info Messages

```apex
// Publish completion status
IntegrationEventPublisher.publishInfo(
    'Facturas',                       // Context
    'Batch completed: 150 records processed',  // Message
    null,                             // Stack trace (optional)
    payloadId,                        // Payload ID
    batchJobId                        // Batch job ID
);
```

#### Simple Error Message (No Context)

```apex
// Minimal information
IntegrationEventPublisher.publishError(
    'Pedidos',
    'Connection timeout to SAP B1'
);
```

### 3.2 Integration Points in Batch Jobs

#### Example: BatchSyncPedidos

```apex
global class BatchSyncPedidos implements Database.Batchable<SObject> {
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator('SELECT Id, Name FROM Pedido__c WHERE Synced__c = false');
    }
    
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        String jobId = String.valueOf(bc.getJobId());
        List<Pedido__c> pedidos = (List<Pedido__c>) scope;
        
        for (Pedido__c pedido : pedidos) {
            try {
                // Call external API
                String payload = JSON.serialize(pedido);
                String response = callSAPAPI(payload);
                
                // Mark as synced
                pedido.Synced__c = true;
                
                // Publish success
                IntegrationEventPublisher.publishInfo(
                    'Pedidos',
                    'Successfully synced',
                    pedido.Id,
                    jobId
                );
                
            } catch (Exception ex) {
                // Publish error
                IntegrationEventPublisher.publishError(
                    'Pedidos',
                    ex,
                    pedido.Id,
                    jobId
                );
                
                // Handle error (mark as failed, etc.)
                pedido.SyncError__c = ex.getMessage();
            }
        }
        
        update pedidos;
    }
    
    global void finish(Database.BatchableContext bc) {
        // Batch completion logic
        // Optionally publish summary
        IntegrationEventPublisher.publishInfo(
            'Pedidos',
            'Batch job completed',
            null,
            String.valueOf(bc.getJobId())
        );
    }
}
```

### 3.3 Integration Points in Callout Classes

#### Example: SAPIntegrationService

```apex
public class SAPIntegrationService {
    
    public static Map<String, Object> createInvoice(Invoice__c invoice) {
        String payloadId = invoice.Id;
        
        try {
            String payload = buildPayload(invoice);
            HttpResponse response = makeCallout(payload);
            
            if (!response.isSuccess()) {
                String errorMsg = 'SAP API returned ' + response.getStatusCode();
                IntegrationEventPublisher.publishError(
                    'Facturas',
                    errorMsg,
                    payload,
                    payloadId
                );
                throw new CalloutException(errorMsg);
            }
            
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            
            // Publish success
            IntegrationEventPublisher.publishInfo(
                'Facturas',
                'Invoice created in SAP: ' + result.get('InvoiceId'),
                payloadId,
                null
            );
            
            return result;
            
        } catch (Exception ex) {
            IntegrationEventPublisher.publishError(
                'Facturas',
                ex,
                payloadId,
                null
            );
            throw ex;
        }
    }
    
    private static HttpResponse makeCallout(String payload) {
        // Callout logic
        return new Http().send(buildRequest(payload));
    }
}
```

### 3.4 Integration Points in Queueable Jobs

```apex
public class QueueableProductSync implements Queueable, Database.AllowsCallouts {
    
    private List<Product2> products;
    private String jobId;
    
    public QueueableProductSync(List<Product2> products) {
        this.products = products;
        this.jobId = System.now().format('yyyyMMddHHmmss');
    }
    
    public void execute(QueueableContext context) {
        for (Product2 product : products) {
            try {
                syncProductToExternal(product);
                
                IntegrationEventPublisher.publishInfo(
                    'Productos',
                    'Product synced successfully',
                    product.Id,
                    jobId
                );
                
            } catch (Exception ex) {
                IntegrationEventPublisher.publishError(
                    'Productos',
                    ex,
                    product.Id,
                    jobId
                );
            }
        }
    }
    
    private void syncProductToExternal(Product2 product) {
        // Integration logic
    }
}
```

---

## 4. Monitoring the Dashboard

### 4.1 Accessing the Dashboard

1. Navigate to the app where you added the `integrationHealthDashboard` component
2. Open the dashboard tab

### 4.2 Dashboard Tabs

#### **Summary Tab**
- Overall integration health (success %, error count)
- High-level metrics
- Real-time updates via EMP API

#### **Filters Tab**
- Search by context, payload ID, or job ID
- Filter by status (Processed, Error)
- Filter by date range
- Pagination for large datasets

#### **Integration Summaries Tab**
- Per-integration cards (Pedidos, Productos, Facturas, etc.)
- Success/error breakdown for each integration
- Quick health status

### 4.3 Interpreting Data

- **Status = "Error"**: Log entry represents an error condition (`Processed__c = false`)
- **Status = "Processed"**: Log entry represents successful completion (`Processed__c = true`)
- **Context**: Name of the integration (must match what you publish from code)
- **PayloadId**: ID of the Salesforce record being processed (useful for tracing)
- **JobId**: Batch job ID or queue job ID (groups related operations)

---

## 5. Best Practices

### 5.1 Context Naming Convention

Use consistent context names across all integrations:

```
Pedidos          (Orders integration)
Productos        (Products integration)
Facturas         (Invoices integration)
Direcciones      (Addresses integration)
[CustomName]     (Any other integration)
```

**Why**: The dashboard groups logs by context. Inconsistent naming fragments your data.

### 5.2 Payload Tracking

Always pass the Salesforce record ID as `payloadId`:

```apex
IntegrationEventPublisher.publishError(
    'Pedidos',
    ex,
    pedido.Id,  // ← Always include the record being processed
    jobId
);
```

**Why**: Allows operations to trace issues back to specific records in Salesforce.

### 5.3 Batch Job Tracking

Always capture the batch job ID:

```apex
global void execute(Database.BatchableContext bc, List<SObject> scope) {
    String jobId = String.valueOf(bc.getJobId());
    // Use jobId in all event publishes
}
```

**Why**: Groups all logs from a single batch execution together.

### 5.4 Error vs Info Messages

- Use `publishError()` when something goes wrong
- Use `publishInfo()` for successful operations
- Never mix them (don't publish info as an error)

### 5.5 Field Truncation

The publisher automatically truncates long strings:
- `errorMessage` → 32,000 chars max
- `stackTrace` → 32,000 chars max
- `payloadId` → 100 chars max
- `jobId` → 50 chars max

**Why**: Ensures Salesforce field limits are never exceeded.

---

## 6. Troubleshooting

### Dashboard Not Updating in Real-Time

**Symptom**: Events are published but dashboard doesn't update.

**Solution**:
1. Check browser console for EMP API errors
2. Verify user has `Integration_Dashboard_Read` permission set
3. Confirm platform event is published (check debug logs)
4. Try refreshing the page
5. Clear browser cache and retry

### Events Published But Not Appearing in Logs

**Symptom**: `IntegrationEventPublisher.publishError()` runs but no logs appear.

**Possible Causes**:
1. Trigger is inactive or has errors
2. User lacks `Integration_Logger_Execute` permission
3. `Integration_Log__c` object has field security restrictions
4. Event publishing failed silently (check debug logs)

**Solution**:
```apex
// In debug logs, run:
SELECT Id, Context__c, ErrorMessage__c FROM Integration_Log__c 
ORDER BY CreatedDate DESC LIMIT 10

// Check trigger execution logs:
SELECT Id, DurableId FROM ApexTrigger WHERE EntityDefinition.QualifiedApiName = 'IntegrationEvent__e'
```

### High Event Publish Latency

**Symptom**: Events published but dashboard updates slowly.

**Solution**:
1. Check org event backlog: **Setup** → **Monitoring** → **Event Manager**
2. Review batch job limits (governor limits on event publishing)
3. Reduce event volume if possible
4. Consider publishing only errors, not info messages

### Permission Errors When Publishing

**Symptom**: `"INSUFFICIENT_ACCESS: insufficient access on cross-reference id"` error.

**Solution**:
1. Verify user has `Integration_Logger_Execute` permission
2. Check that user's license includes platform events permission
3. Run as system context (class uses `without sharing`)

---

## 7. Architecture Deep Dive

### Data Flow

```
Your Code (Batch/Queueable)
        ↓
IntegrationEventPublisher.publishError()
        ↓
IntegrationEvent__e Platform Event (published immediately)
        ↓
IntegrationEventTrigger (after insert)
        ↓
Integration_Log__c Record (inserted)
        ↓
LWC Dashboard subscribes to /event/IntegrationEvent__e
        ↓
Dashboard updates in real-time via EMP API
```

### Why This Architecture?

1. **Decoupled**: Integration code doesn't depend on logging schema
2. **Real-Time**: Platform events publish immediately (even on rollback)
3. **Persistent**: Logs stored in custom object for auditing
4. **Queryable**: Logs accessible via SOQL for reporting
5. **Scalable**: Platform events handle high volume efficiently
6. **Reusable**: Same architecture works across multiple integrations

### Governor Limits Considerations

- **Event Publishing**: Max 5,000 platform events per transaction
- **DML**: Trigger inserts logs (max 10,000 DML per transaction)
- **Query**: Controller queries limited by query row limits

**Mitigation**: Batch jobs naturally respect these by processing in chunks.

---

## 8. Support & Maintenance

### Regular Maintenance

1. **Archive Old Logs** (Monthly)
   ```apex
   DELETE FROM Integration_Log__c WHERE CreatedDate < LAST_N_DAYS:90
   ```

2. **Monitor Event Volume** (Weekly)
   - Check **Setup** → **Event Manager** for backlog
   - If consistently >1000 pending events, optimize publishing

3. **Review Permissions** (Quarterly)
   - Ensure only necessary users have `Integration_Logger_Execute`
   - Audit who has dashboard access

### Extending the System

To add a new integration:

1. Update your code to call `IntegrationEventPublisher.publishError()` with a new context (e.g., "Clientes")
2. No code changes needed—just use a new context name
3. Dashboard will automatically start tracking the new integration

To add custom fields to logs:

1. Add new field to `Integration_Log__c`
2. Add new field to `IntegrationEvent__e`
3. Update `IntegrationEventTrigger` to map the field
4. Update `IntegrationEventPublisher.publishError()` method signature if needed

---

## 9. Example: Complete Integration Setup

Here's a minimal example showing a complete integration from code to dashboard:

### Step 1: Create Batch Job

```apex
global class BatchSyncOrders implements Database.Batchable<SObject> {
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator('SELECT Id, ExternalId__c FROM Order WHERE Synced__c = false LIMIT 1000');
    }
    
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        String jobId = String.valueOf(bc.getJobId());
        
        for (Order order : (List<Order>) scope) {
            try {
                // Sync logic
                SyncService.syncOrderToExternal(order);
                order.Synced__c = true;
                
                IntegrationEventPublisher.publishInfo(
                    'Orders',
                    'Order synced successfully',
                    order.Id,
                    jobId
                );
            } catch (Exception ex) {
                IntegrationEventPublisher.publishError(
                    'Orders',
                    ex,
                    order.Id,
                    jobId
                );
                order.SyncError__c = ex.getMessage();
            }
        }
        
        update scope;
    }
    
    global void finish(Database.BatchableContext bc) {
        // Optional: Final summary
    }
}
```

### Step 2: Deploy to Org

```bash
sfdx force:source:deploy -p force-app/main/default -u my-org
```

### Step 3: Assign Permissions

- Assign `Integration_Logger_Execute` to batch user
- Assign `Integration_Dashboard_Read` to support team

### Step 4: Execute Batch

```bash
sfdx force:apex:execute -u my-org
# then paste:
Database.executeBatch(new BatchSyncOrders(), 200);
```

### Step 5: View Dashboard

Open dashboard tab → See real-time logs appearing as batch executes!

---

## 10. Summary Checklist

- [ ] Deployed all metadata components
- [ ] Created permission sets
- [ ] Assigned permission sets to users
- [ ] Added `IntegrationEventPublisher` calls to batch jobs
- [ ] Tested event publishing in sandbox
- [ ] Dashboard appears and updates in real-time
- [ ] Configured FlexiPage with dashboard (optional)
- [ ] Documented integration contexts used
- [ ] Set up log archival schedule (optional)

---

## Questions?

Refer to the `IntegrationHealthController.cls` for API documentation, or check the LWC components in `force-app/main/default/lwc/` for UI implementation details.

