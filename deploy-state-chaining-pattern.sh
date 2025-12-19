#!/bin/bash
# Deployment script for State-Chaining Batch Pattern Implementation
# Deploys classes in dependency order to avoid compilation errors

set -e  # Exit on error

echo "==========================================="
echo "State-Chaining Batch Pattern Deployment"
echo "==========================================="
echo ""

# Step 1: Deploy BatchSummary (no dependencies)
echo "Step 1/6: Deploying BatchSummary..."
sf project deploy start \
  --source-dir force-app/main/default/classes/BatchSummary.cls \
  --wait 10
echo "✅ BatchSummary deployed"
echo ""

# Step 2: Deploy SAPB1ApiService enhancements (depends on BatchIntegrationHelper which already exists)
echo "Step 2/6: Deploying SAPB1ApiService..."
sf project deploy start \
  --source-dir force-app/main/default/classes/SAPB1ApiService.cls \
  --wait 10
echo "✅ SAPB1ApiService deployed"
echo ""

# Step 3: Deploy BasePaginatedBatchJob (depends on BatchSummary, BatchIntegrationHelper, IntegrationLogger, IntegrationEventPublisher)
echo "Step 3/6: Deploying BasePaginatedBatchJob..."
sf project deploy start \
  --source-dir force-app/main/default/classes/BasePaginatedBatchJob.cls \
  --wait 10
echo "✅ BasePaginatedBatchJob deployed"
echo ""

# Step 4: Deploy ProductosBatchJob (depends on BasePaginatedBatchJob, ProductosController)
echo "Step 4/6: Deploying ProductosBatchJob..."
sf project deploy start \
  --source-dir force-app/main/default/classes/ProductosBatchJob.cls \
  --wait 10
echo "✅ ProductosBatchJob deployed"
echo ""

# Step 5: Deploy PedidosBatchJob (depends on BasePaginatedBatchJob, PedidosController)
echo "Step 5/6: Deploying PedidosBatchJob..."
sf project deploy start \
  --source-dir force-app/main/default/classes/PedidosBatchJob.cls \
  --wait 10
echo "✅ PedidosBatchJob deployed"
echo ""

# Step 6: Deploy FacturasBatchJob (depends on BasePaginatedBatchJob, FacturasController)
echo "Step 6/6: Deploying FacturasBatchJob..."
sf project deploy start \
  --source-dir force-app/main/default/classes/FacturasBatchJob.cls \
  --wait 10
echo "✅ FacturasBatchJob deployed"
echo ""

# Step 7: Deploy Integration Job updates (these depend on the batch jobs)
echo "Step 7/7: Deploying Integration Jobs..."
sf project deploy start \
  --source-dir force-app/main/default/classes/ProductosIntegrationJob.cls \
  --source-dir force-app/main/default/classes/PedidosIntegrationJob.cls \
  --source-dir force-app/main/default/classes/FacturasIntegrationJob.cls \
  --wait 10
echo "✅ Integration Jobs deployed"
echo ""

echo "==========================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "1. Run unit tests to verify compatibility"
echo "2. Test with mock payloads"
echo "3. Test with small date ranges in production"
echo "4. Monitor logs carefully"
echo ""
