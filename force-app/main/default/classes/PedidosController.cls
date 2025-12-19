/**
 * @description Controlador responsable de mapear y actualizar/insertar Pedidos desde un sistema externo (SAP B1).
 * 
 */
public without sharing class PedidosController {

    /**
     * @description Result object for processOrderList operation
     */
    public class ProcessResult {
        public Integer ordersProcessed;
        public Integer ordersUpserted;
        public Integer ordersSkipped;
        public Integer linesProcessed;
        public Integer linesUpserted;
        public Integer linesSkipped;
        public List<OrderError> orderErrors;
        public List<LineError> lineErrors;
        public List<String> skippedOrderDetails;
        public List<String> skippedLineDetails;
        public List<String> rejectedRawOrders;
        
        public ProcessResult() {
            this.ordersProcessed = 0;
            this.ordersUpserted = 0;
            this.ordersSkipped = 0;
            this.linesProcessed = 0;
            this.linesUpserted = 0;
            this.linesSkipped = 0;
            this.orderErrors = new List<OrderError>();
            this.lineErrors = new List<LineError>();
            this.skippedOrderDetails = new List<String>();
            this.skippedLineDetails = new List<String>();
            this.rejectedRawOrders = new List<String>();
        }
    }
    
    public class OrderError {
        public String docEntry;
        public String message;
        
        public OrderError(String docEntry, String message) {
            this.docEntry = docEntry;
            this.message = message;
        }
    }
    
    public class LineError {
        public String docEntryLine;
        public String message;
        
        public LineError(String docEntryLine, String message) {
            this.docEntryLine = docEntryLine;
            this.message = message;
        }
    }

    /**
     * @description Processes a list of deserialized orders and performs upsert of Order and OrderItem.
     * @param orderNodes List of maps with the SAP B1 payload structure (Orders, Orders/DocumentLines).
     * @return ProcessResult with metrics and errors.
     */
    public static ProcessResult processOrderList(List<Map<String, Object>> orderNodes) {
        ProcessResult result = new ProcessResult();
        
        if (orderNodes == null || orderNodes.isEmpty()) {
            return result;
        }
        
        if (!Schema.sObjectType.Order.isAccessible() || !Schema.sObjectType.OrderItem.isAccessible()) {
            return result;
        }
        
        Id pricebookId = getActivePricebookId();
        if (pricebookId == null) {
            return result;
        }
        
        Map<String, Order> draftOrders = new Map<String, Order>();
        List<OrderItem> draftLines = new List<OrderItem>();
        Set<String> lineExtIds = new Set<String>();
        Map<String, String> orderCardCodes = new Map<String, String>();
        Map<String, String> lineItemCodes = new Map<String, String>();
        Map<String, String> lineOrderExtIds = new Map<String, String>();

        for (Map<String, Object> node : orderNodes) {
            Integer ordersBefore = draftOrders.size();
            buildOrderAndLine(node, draftOrders, draftLines, lineExtIds, orderCardCodes, lineItemCodes, lineOrderExtIds);
            
            // Check if this node was rejected during mapping
            if (draftOrders.size() == ordersBefore) {
                Map<String, Object> ordersNode = (Map<String, Object>) node.get('Orders');
                if (ordersNode != null) {
                    String docEntry = String.valueOf(ordersNode.get('DocEntry'));
                    String cardCode = String.valueOf(ordersNode.get('CardCode'));
                    String reason = String.isBlank(docEntry) ? 'Missing DocEntry' : 'Unknown rejection reason';
                    result.rejectedRawOrders.add('DocEntry: ' + docEntry + ', CardCode: ' + cardCode + ', Reason: ' + reason);
                }
            }
        }
        
        result.ordersProcessed = draftOrders.size();
        result.linesProcessed = draftLines.size();

        // Build lookup maps
        Map<String, Id> accountMap = buildAccountMap(orderCardCodes.values());
        Map<String, Id> productMap = buildProductMap(lineItemCodes.values());
        Map<String, Id> pbeMap = buildPbeMap(productMap.keySet(), pricebookId);

        // Track skipped orders (missing Account)
        List<String> skippedOrders = new List<String>();
        List<Order> ordersToUpsert = new List<Order>();
        
        for (String docEntry : draftOrders.keySet()) {
            Order ord = draftOrders.get(docEntry);
            String cardCode = orderCardCodes.get(docEntry);
            Id accId = accountMap.get(cardCode);
            
            if (accId == null) {
                skippedOrders.add('DocEntry: ' + docEntry + ', CardCode: ' + cardCode);
                result.ordersSkipped++;
                continue;
            }
            
            ord.AccountId = accId;
            ord.Pricebook2Id = pricebookId;
            ord.Codigo_socio_de_negocios__c = accId;
            ord.Nombre_socio_de_negocios__c = accId;
            ord.RUT_del_socio_de_negocios__c = accId;
            
            ordersToUpsert.add(ord);
        }
        
        // Track skipped orders for return to caller
        result.skippedOrderDetails = skippedOrders;

        // Upsert Orders and track failures
        if (!ordersToUpsert.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(ordersToUpsert, Order.Fields.Pedidos_ID__c, false);
            for (Integer i = 0; i < results.size(); i++) {
                Database.UpsertResult res = results[i];
                if (res.isSuccess()) {
                    result.ordersUpserted++;
                } else {
                    String errors = '';
                    for (Database.Error err : res.getErrors()) {
                        errors += err.getMessage() + '; ';
                    }
                    result.orderErrors.add(new OrderError(ordersToUpsert[i].Pedidos_ID__c, errors));
                }
            }
        }

        // Build orderId map from upserted records
        Map<String, Id> orderIdMap = new Map<String, Id>();
        for (Order ord : ordersToUpsert) {
            if (ord.Id != null && ord.Pedidos_ID__c != null) {
                orderIdMap.put(ord.Pedidos_ID__c, ord.Id);
            }
        }

        // Track skipped lines (missing Product/Order/PBE)
        List<String> skippedLines = new List<String>();
        List<OrderItem> linesToUpsert = new List<OrderItem>();
        
        for (OrderItem line : draftLines) {
            String extId = line.Productos_de_Pedidos_ID__c;
            String itemCode = lineItemCodes.get(extId);
            String orderExtId = lineOrderExtIds.get(extId);
            Id prodId = productMap.get(itemCode);
            Id ordId = orderIdMap.get(orderExtId);
            Id pbeId = pbeMap.get(itemCode);
            
            if (prodId == null || ordId == null || pbeId == null) {
                skippedLines.add('DocEntry-Line: ' + extId + ', ItemCode: ' + itemCode + ', Product: ' + prodId + ', Order: ' + ordId + ', PBE: ' + pbeId);
                result.linesSkipped++;
                continue;
            }
            
            line.Product2Id = prodId;
            line.OrderId = ordId;
            line.PricebookEntryId = pbeId;
            linesToUpsert.add(line);
        }
        
        // Track skipped lines for return to caller
        result.skippedLineDetails = skippedLines;

        // Upsert OrderItems and track failures
        if (!linesToUpsert.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(linesToUpsert, OrderItem.Fields.Productos_de_Pedidos_ID__c, false);
            for (Integer i = 0; i < results.size(); i++) {
                Database.UpsertResult res = results[i];
                if (res.isSuccess()) {
                    result.linesUpserted++;
                } else {
                    String errors = '';
                    for (Database.Error err : res.getErrors()) {
                        errors += err.getMessage() + '; ';
                    }
                    result.lineErrors.add(new LineError(linesToUpsert[i].Productos_de_Pedidos_ID__c, errors));
                }
            }
        }

        return result;
    }

    /**
     * @description Legacy method - processes orders from JSON string.
     * @deprecated Use processOrderList(List<Map<String,Object>>, String) for better performance and flexibility.
     */
    public static void processOrdersData(String dataResponse) {
        Id pricebookId = getActivePricebookId();
        if (pricebookId == null) {
              // System.debug(LoggingLevel.ERROR, 'Aborting: No active Standard Pricebook found. Cannot process orders.');
            return;
        }
        if (!isProcessable(dataResponse)) {
            return;
        }

        List<Object> vals = extractValueArray(dataResponse);
        if (vals == null || vals.isEmpty()) {
              // System.debug('No orders data to process.');
            return;
        }

        Map<String, Order> draftOrders = new Map<String, Order>();
        List<OrderItem> draftLines = new List<OrderItem>();
        Set<String> lineExtIds = new Set<String>();
        Map<String, String> orderCardCodes = new Map<String, String>();
        Map<String, String> lineItemCodes = new Map<String, String>();
        Map<String, String> lineOrderExtIds = new Map<String, String>();

        for (Object o : vals) {
            Map<String, Object> node = (Map<String, Object>) o;
            buildOrderAndLine(node, draftOrders, draftLines, lineExtIds, orderCardCodes, lineItemCodes, lineOrderExtIds);
        }

        // Build lookup maps
        Map<String, Id> accountMap = buildAccountMap(orderCardCodes.values());
        Map<String, Id> productMap = buildProductMap(lineItemCodes.values());
        
        Map<String, Id> pbeMap = buildPbeMap(productMap.keySet(), pricebookId);

        // Process Orders
        List<Order> ordersToUpsert = new List<Order>();
        Integer ordersOmitted = 0;
        for (String docEntry : draftOrders.keySet()) {
            Order ord = draftOrders.get(docEntry);
            String cardCode = orderCardCodes.get(docEntry);
            Id accId = accountMap.get(cardCode);
            if (accId == null) {
                  // System.debug(LoggingLevel.WARN, 'Omitting order ' + docEntry + ' due to missing Account for CardCode ' + cardCode);
                ordersOmitted++;
                continue;
            }
            ord.AccountId = accId;
            ord.Pricebook2Id = pricebookId;
            
            ord.Codigo_socio_de_negocios__c = accId;
            ord.Nombre_socio_de_negocios__c = accId;
            ord.RUT_del_socio_de_negocios__c = accId;
            
            ordersToUpsert.add(ord);
        }

        Integer ordersUpserted = 0;
        if (!ordersToUpsert.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(ordersToUpsert, Order.Fields.Pedidos_ID__c, false);
            for (Database.UpsertResult res : results) {
                if (res.isSuccess()) {
                    ordersUpserted++;
                } else {
                      // System.debug(LoggingLevel.ERROR, 'Failed to upsert order: ' + res.getErrors());
                }
            }
        }

        // Build orderId map - use the upserted records directly
        Map<String, Id> orderIdMap = new Map<String, Id>();
        for (Order ord : ordersToUpsert) {
            if (ord.Id != null && ord.Pedidos_ID__c != null) {
                orderIdMap.put(ord.Pedidos_ID__c, ord.Id);
            }
        }

        // Process OrderItems
        List<OrderItem> linesToUpsert = new List<OrderItem>();
        Integer linesOmitted = 0;
        for (OrderItem line : draftLines) {
            String extId = line.Productos_de_Pedidos_ID__c;
            String itemCode = lineItemCodes.get(extId);
            String orderExtId = lineOrderExtIds.get(extId);
            Id prodId = productMap.get(itemCode);
            Id ordId = orderIdMap.get(orderExtId);
            Id pbeId = pbeMap.get(itemCode);
            if (prodId == null || ordId == null || pbeId == null) {
                 // System.debug(LoggingLevel.WARN, 'Omitting line ' + extId + ' due to missing lookups: Product=' + prodId + ', Order=' + ordId + ', PBE=' + pbeId);
                linesOmitted++;
                continue;
            }
            line.Product2Id = prodId;
            line.OrderId = ordId;
            line.PricebookEntryId = pbeId;
            linesToUpsert.add(line);
        }

        Integer linesUpserted = 0;
        if (!linesToUpsert.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(linesToUpsert, OrderItem.Fields.Productos_de_Pedidos_ID__c, false);
            linesUpserted = results.size();
            for (Database.UpsertResult res : results) {
                if (!res.isSuccess()) {
                      // System.debug(LoggingLevel.ERROR, 'Failed to upsert order item: ' + res.getErrors());
                }
            }
        }

        // Summary logs
          // System.debug('Processing summary: Orders processed=' + draftOrders.size() + ', upserted=' + ordersUpserted + ', omitted=' + ordersOmitted +
                     //'; Lines processed=' + draftLines.size() + ', upserted=' + linesUpserted + ', omitted=' + linesOmitted);
    }

    private static Boolean isProcessable(String dataResponse) {
        if (String.isBlank(dataResponse)) {
            return false;
        }
        if (!Schema.sObjectType.Order.isAccessible() || !Schema.sObjectType.OrderItem.isAccessible()) {
            return false;
        }
        return true;
    }

    private static List<Object> extractValueArray(String dataResponse) {
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(dataResponse);
            if (root == null) {
                return null;
            }
            return (List<Object>) root.get('value');
        } catch (JSONException e) {
              // System.debug(LoggingLevel.ERROR, 'Failed to parse JSON: ' + e.getMessage());
            return null;
        }
    }

    private static void buildOrderAndLine(Map<String, Object> node, Map<String, Order> draftOrders, List<OrderItem> draftLines, Set<String> lineExtIds,
                                         Map<String, String> orderCardCodes, Map<String, String> lineItemCodes, Map<String, String> lineOrderExtIds) {
        Map<String, Object> ordersNode = (Map<String, Object>) node.get('Orders');
        Map<String, Object> linesNode = (Map<String, Object>) node.get('Orders/DocumentLines');
        if (ordersNode == null || linesNode == null) {
            return;
        }

        String docEntry = String.valueOf(ordersNode.get('DocEntry'));
        if (String.isBlank(docEntry)) {
            return;
        }

        // Build Order if not already
        if (!draftOrders.containsKey(docEntry)) {
            Order ord = buildOrder(ordersNode);
            if (ord != null) {
                draftOrders.put(docEntry, ord);
                orderCardCodes.put(docEntry, String.valueOf(ordersNode.get('CardCode')));
            }
        }

        // Build OrderItem
        String lineNum = String.valueOf(linesNode.get('LineNum'));
        if (String.isBlank(lineNum)) {
            return;
        }
        String extId = docEntry + '-' + lineNum;
        if (lineExtIds.contains(extId)) {
            return; // duplicate
        }
        lineExtIds.add(extId);
        OrderItem line = buildOrderItem(linesNode, ordersNode);
        if (line != null) {
            line.Productos_de_Pedidos_ID__c = extId;
            draftLines.add(line);
            lineItemCodes.put(extId, String.valueOf(linesNode.get('ItemCode')));
            lineOrderExtIds.put(extId, docEntry);
        }
    }

    private static Order buildOrder(Map<String, Object> ordersNode) {
        Order ord = new Order();
        ord.Pedidos_ID__c = String.valueOf(ordersNode.get('DocEntry'));
        ord.Correlativo_interno_SAP__c = String.valueOf(ordersNode.get('DocEntry'));
        ord.N_mero_de_la_nota_de_ventas__c = IntegrationUtils.toDecimal(ordersNode.get('DocNum'));
        ord.Total_documento_con_IVA__c = IntegrationUtils.toDecimal(ordersNode.get('DocTotal'));
        ord.Tipo_de_documentos__c = String.valueOf(ordersNode.get('DocType'));
        ord.EffectiveDate = IntegrationUtils.toDate(ordersNode.get('DocDate'));
        ord.Fecha_entrega__c = IntegrationUtils.toDateTime(ordersNode.get('DocDueDate'));
        ord.Direcci_n_de_factura__c = String.valueOf(ordersNode.get('Address'));
        ord.N_orden_de_compra_socio_negocios__c = IntegrationUtils.toDecimal(ordersNode.get('NumAtCard'));
        ord.Tipo_moneda_de_nota_de_venta__c = String.valueOf(ordersNode.get('DocCurrency'));
        ord.C_digo_del_vendedor__c = String.valueOf(ordersNode.get('SalesPersonCode'));
        ord.Comentarios__c = String.valueOf(ordersNode.get('Comments'));
        ord.Direcci_n_de_despacho__c = String.valueOf(ordersNode.get('ShipToCode'));
        ord.Status = 'Borrador';
        ord.Direcci_n_de_despacho_2__c = String.valueOf(ordersNode.get('Address2'));
        ord.Ruta_Despacho__c = String.valueOf(ordersNode.get('U_RUTA'));
        ord.Con_receta__c = IntegrationUtils.mapReceta(String.valueOf(ordersNode.get('U_RECETA')));
        ord.C_digo_venta_B2B__c = String.valueOf(ordersNode.get('U_SEI_IDW'));
        
        // Additional mappings for accounting date/time
        ord.Fecha_contabilizaci_n__c = IntegrationUtils.toDateTimeWithTime(ordersNode.get('DocDate'), ordersNode.get('DocTime'));
        ord.Hora_contabilizaci_n__c = IntegrationUtils.toTime(ordersNode.get('DocTime'));
        // Note: Estado_de_nota_de_venta__c is a restricted picklist and requires specific values
        // It should be set via workflow or process builder based on Status field

        return ord;
    }

    private static OrderItem buildOrderItem(Map<String, Object> linesNode, Map<String, Object> ordersNode) {
        OrderItem item = new OrderItem();
        item.L_nea_detalle_nota_venta__c = String.valueOf(linesNode.get('LineNum'));
        item.Cantidad_comprada__c = IntegrationUtils.toDouble(linesNode.get('Quantity'));
        item.Quantity = IntegrationUtils.toDouble(linesNode.get('Quantity'));
        item.Precio_neto_del_producto__c = IntegrationUtils.toDecimal(linesNode.get('Price'));
        item.Precio_con_IVA_del_producto__c = IntegrationUtils.toDecimal(linesNode.get('PriceAfterVAT'));
        item.C_digo_de_barra_del_producto__c = IntegrationUtils.toDecimal(linesNode.get('BarCode'));
        item.Fecha_despacho__c = IntegrationUtils.toDate(linesNode.get('ShipDate'));
        item.Tipo_impuesto_aplicado__c = String.valueOf(linesNode.get('TaxCode'));
        item.UnitPrice = IntegrationUtils.toDouble(linesNode.get('Price'));
        
        // Note: The following fields are LOOKUP fields (require Salesforce IDs, not SAP text values)
        // and cannot be populated directly from SAP data:
        // - Descripci_n_del_producto__c (Lookup to Product)
        // - C_digo_del_producto__c (Lookup to Product) 
        // - C_digo_almac_n__c (Lookup to Account)
        // These would need to be resolved via external ID matching if required.

        return item;
    }

    private static Map<String, Id> buildAccountMap(List<String> cardCodes) {
        Set<String> cardCodesSet = new Set<String>(cardCodes);
        Map<String, Id> accMap = new Map<String, Id>();
        for (Account acc : [SELECT Id, Clientes_ID__c FROM Account WHERE Clientes_ID__c IN :cardCodesSet WITH SYSTEM_MODE]) {
            accMap.put(acc.Clientes_ID__c, acc.Id);
        }
        return accMap;
    }

    private static Map<String, Id> buildProductMap(List<String> itemCodes) {
        Set<String> itemCodesSet = new Set<String>(itemCodes);
        Map<String, Id> prodMap = new Map<String, Id>();
        for (Product2 prod : [SELECT Id, Productos_ID__c FROM Product2 WHERE Productos_ID__c IN :itemCodesSet]) {
            prodMap.put(prod.Productos_ID__c, prod.Id);
        }
        return prodMap;
    }

    private static Id getActivePricebookId() {
        if (Test.isRunningTest()) {
            return Test.getStandardPricebookId();
        }
        List<Pricebook2> pbs = [SELECT Id FROM Pricebook2 WHERE IsActive = true AND IsStandard = true LIMIT 1];
        return pbs.isEmpty() ? null : pbs[0].Id;
    }

    private static Map<String, Id> buildPbeMap(Set<String> itemCodes, Id pricebookId) {
        Map<String, Id> pbeMap = new Map<String, Id>();
          // System.debug('Building PBE map for itemCodes: ' + itemCodes + ', pricebookId: ' + pricebookId);
        for (PricebookEntry pbe : [SELECT Id, Product2.Productos_ID__c FROM PricebookEntry
                                   WHERE Product2.Productos_ID__c IN :itemCodes AND Pricebook2Id = :pricebookId AND IsActive = true]) {
            pbeMap.put(pbe.Product2.Productos_ID__c, pbe.Id);
              // System.debug('Found PBE: ' + pbe.Product2.Productos_ID__c + ' -> ' + pbe.Id);
        }
          // System.debug('Final PBE map: ' + pbeMap);
        return pbeMap;
    }
}