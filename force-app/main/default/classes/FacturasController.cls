/**
 * @description Controlador responsable de mapear y actualizar/insertar Facturas desde un sistema externo (SAP B1).
 *
 */
public without sharing class FacturasController {

    public class ProcessResult {
        public Integer invoicesProcessed = 0;
        public Integer invoicesUpserted = 0;
        public Integer invoicesSkipped = 0;
        public Integer linesProcessed = 0;
        public Integer linesUpserted = 0;
        public Integer linesSkipped = 0;
        public List<InvoiceError> invoiceErrors = new List<InvoiceError>();
        public List<LineError> lineErrors = new List<LineError>();
        public List<String> skippedInvoiceDetails = new List<String>();
        public List<String> skippedLineDetails = new List<String>();
    }
    
    public class InvoiceError {
        public String docEntry;
        public String message;
        public InvoiceError(String docEntry, String message) {
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
     * @description Processes a list of deserialized invoices, upserting Facturas__c and Detalle_de_Facturas__c.
     * @param invoiceNodes List of maps with the SAP B1 payload structure.
     * @return ProcessResult with metrics and errors.
     */
    public static ProcessResult processInvoiceList(List<Map<String, Object>> invoiceNodes) {
        ProcessResult result = new ProcessResult();
        if (invoiceNodes == null || invoiceNodes.isEmpty()) {
            return result;
        }
        if (!Schema.sObjectType.Facturas__c.isAccessible() || !Schema.sObjectType.Detalle_de_Facturas__c.isAccessible()) {
            result.invoiceErrors.add(new InvoiceError(null, 'Permission denied for Facturas__c or Detalle_de_Facturas__c.'));
            return result;
        }

        Map<String, Facturas__c> draftInvoices = new Map<String, Facturas__c>();
        List<Detalle_de_Facturas__c> draftLines = new List<Detalle_de_Facturas__c>();
        Set<String> lineExtIds = new Set<String>();
        Map<String, String> invoiceCardCodes = new Map<String, String>();
        Map<String, String> lineItemCodes = new Map<String, String>();
        Map<String, String> lineInvoiceExtIds = new Map<String, String>();
        Map<String, String> invoiceOrderExtIds = new Map<String, String>();

        for (Map<String, Object> node : invoiceNodes) {
            buildInvoiceAndLine(node, draftInvoices, draftLines, lineExtIds, invoiceCardCodes, lineItemCodes, lineInvoiceExtIds, invoiceOrderExtIds);
        }
        
        result.invoicesProcessed = draftInvoices.size();
        result.linesProcessed = draftLines.size();

        Map<String, Id> accountMap = buildAccountMap(invoiceCardCodes.values());
        Map<String, Id> productMap = buildProductMap(lineItemCodes.values());
        Map<String, Order> orderMap = buildOrderMap(invoiceOrderExtIds.values());

        List<Facturas__c> invoicesToUpsert = new List<Facturas__c>();
        for (String docEntry : draftInvoices.keySet()) {
            Facturas__c inv = draftInvoices.get(docEntry);
            String cardCode = invoiceCardCodes.get(docEntry);
            Id accId = accountMap.get(cardCode);
            if (accId == null) {
                result.invoicesSkipped++;
                result.skippedInvoiceDetails.add('DocEntry: ' + docEntry + ', CardCode: ' + cardCode + ' - Account not found.');
                continue;
            }
            inv.Codigo_socio_de_negocios__c = accId;
            inv.Nombre_socio_de_negocios__c = accId;
            inv.RUT_del_socio_de_negocios__c = accId;
            inv.Account__c = accId;

            String orderExtId = invoiceOrderExtIds.get(docEntry);
            if (String.isNotBlank(orderExtId)) {
                Order relatedOrder = orderMap.get(orderExtId);
                if (relatedOrder != null) {
                    inv.Correlativo_interno_SAP__c = relatedOrder.Id;
                    inv.U_RUTA__c = relatedOrder.Id;
                    inv.U_SEI_IDW__c = relatedOrder.Id;
                }
            }
            invoicesToUpsert.add(inv);
        }

        if (!invoicesToUpsert.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(invoicesToUpsert, Facturas__c.Fields.Facturas_ID__c, false);
            for (Integer i = 0; i < results.size(); i++) {
                Database.UpsertResult res = results[i];
                if (res.isSuccess()) {
                    result.invoicesUpserted++;
                } else {
                    String errors = '';
                    for (Database.Error err : res.getErrors()) errors += err.getMessage() + '; ';
                    result.invoiceErrors.add(new InvoiceError(invoicesToUpsert[i].Facturas_ID__c, errors));
                }
            }
        }

        Map<String, Id> invoiceIdMap = new Map<String, Id>();
        for (Facturas__c inv : invoicesToUpsert) {
            if (inv.Id != null && inv.Facturas_ID__c != null) {
                invoiceIdMap.put(inv.Facturas_ID__c, inv.Id);
            }
        }

        List<Detalle_de_Facturas__c> linesToUpsert = new List<Detalle_de_Facturas__c>();
        for (Detalle_de_Facturas__c line : draftLines) {
            String extId = line.Detalle_Facturas_ID__c;
            String itemCode = lineItemCodes.get(extId);
            String invoiceExtId = lineInvoiceExtIds.get(extId);
            Id prodId = productMap.get(itemCode);
            Id invId = invoiceIdMap.get(invoiceExtId);
            if (prodId == null || invId == null) {
                result.linesSkipped++;
                result.skippedLineDetails.add('DocEntry-Line: ' + extId + ', ItemCode: ' + itemCode + ' - Missing Product or Invoice reference.');
                continue;
            }
            line.Producto__c = prodId;
            line.Numero_factura__c = invId;
            linesToUpsert.add(line);
        }

        if (!linesToUpsert.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(linesToUpsert, Detalle_de_Facturas__c.Fields.Detalle_Facturas_ID__c, false);
            for (Integer i = 0; i < results.size(); i++) {
                Database.UpsertResult res = results[i];
                if (res.isSuccess()) {
                    result.linesUpserted++;
                } else {
                    String errors = '';
                    for (Database.Error err : res.getErrors()) errors += err.getMessage() + '; ';
                    result.lineErrors.add(new LineError(linesToUpsert[i].Detalle_Facturas_ID__c, errors));
                }
            }
        }
        return result;
    }

    /**
     * @description Legacy method - processes invoices from JSON string.
     * @deprecated Use processInvoiceList(List<Map<String,Object>>, String) for better performance and error handling.
     */
    public static void processInvoicesData(String dataResponse) {
        if (!isProcessable(dataResponse)) {
            return;
        }

        List<Object> vals = extractValueArray(dataResponse);
        if (vals == null || vals.isEmpty()) {
            System.debug('No invoices data to process.');
            return;
        }

        Map<String, Facturas__c> draftInvoices = new Map<String, Facturas__c>();
        List<Detalle_de_Facturas__c> draftLines = new List<Detalle_de_Facturas__c>();
        Set<String> lineExtIds = new Set<String>();
        Map<String, String> invoiceCardCodes = new Map<String, String>();
        Map<String, String> lineItemCodes = new Map<String, String>();
        Map<String, String> lineInvoiceExtIds = new Map<String, String>();
        Map<String, String> invoiceOrderExtIds = new Map<String, String>();

        for (Object o : vals) {
            Map<String, Object> node = (Map<String, Object>) o;
            buildInvoiceAndLine(node, draftInvoices, draftLines, lineExtIds, invoiceCardCodes, lineItemCodes, lineInvoiceExtIds, invoiceOrderExtIds);
        }

        // Build lookup maps
        Map<String, Id> accountMap = buildAccountMap(invoiceCardCodes.values());
        Map<String, Id> productMap = buildProductMap(lineItemCodes.values());
        Map<String, Order> orderMap = buildOrderMap(invoiceOrderExtIds.values());

        // Process Invoices
        List<Facturas__c> invoicesToUpsert = new List<Facturas__c>();
        Integer invoicesOmitted = 0;
        for (String docEntry : draftInvoices.keySet()) {
            Facturas__c inv = draftInvoices.get(docEntry);
            String cardCode = invoiceCardCodes.get(docEntry);
            Id accId = accountMap.get(cardCode);
            if (accId == null) {
                System.debug(LoggingLevel.WARN, 'Omitting invoice ' + docEntry + ' due to missing Account for CardCode ' + cardCode);
                invoicesOmitted++;
                continue;
            }
            inv.Codigo_socio_de_negocios__c = accId;
            inv.Nombre_socio_de_negocios__c = accId;
            inv.RUT_del_socio_de_negocios__c = accId;
            inv.Account__c = accId;

                        // Optional Order lookup
            String orderExtId = invoiceOrderExtIds.get(docEntry);
            if (String.isNotBlank(orderExtId)) {
                Order relatedOrder = orderMap.get(orderExtId);
                if (relatedOrder != null) {
                    inv.Correlativo_interno_SAP__c = relatedOrder.Id;
                    // Populate routing fields from the related Order
                    inv.U_RUTA__c = relatedOrder.Id;
                    inv.U_SEI_IDW__c = relatedOrder.Id;
                }
            }

            invoicesToUpsert.add(inv);
        }

        Integer invoicesUpserted = 0;
        if (!invoicesToUpsert.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(invoicesToUpsert, Facturas__c.Fields.Facturas_ID__c, false);
            for (Database.UpsertResult res : results) {
                if (res.isSuccess()) {
                    invoicesUpserted++;
                } else {
                    System.debug(LoggingLevel.ERROR, 'Failed to upsert invoice: ' + res.getErrors());
                }
            }
        }

        // Build invoiceId map - use the upserted records directly
        Map<String, Id> invoiceIdMap = new Map<String, Id>();
        for (Facturas__c inv : invoicesToUpsert) {
            if (inv.Id != null && inv.Facturas_ID__c != null) {
                invoiceIdMap.put(inv.Facturas_ID__c, inv.Id);
            }
        }

        // Process Invoice Lines
        List<Detalle_de_Facturas__c> linesToUpsert = new List<Detalle_de_Facturas__c>();
        Integer linesOmitted = 0;
        for (Detalle_de_Facturas__c line : draftLines) {
            String extId = line.Detalle_Facturas_ID__c;
            String itemCode = lineItemCodes.get(extId);
            String invoiceExtId = lineInvoiceExtIds.get(extId);
            Id prodId = productMap.get(itemCode);
            Id invId = invoiceIdMap.get(invoiceExtId);
            if (prodId == null || invId == null) {
                System.debug(LoggingLevel.WARN, 'Omitting line ' + extId + ' due to missing lookups: Product=' + prodId + ', Invoice=' + invId);
                linesOmitted++;
                continue;
            }
            line.Producto__c = prodId;
            line.Numero_factura__c = invId;
            linesToUpsert.add(line);
        }

        Integer linesUpserted = 0;
        if (!linesToUpsert.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(linesToUpsert, Detalle_de_Facturas__c.Fields.Detalle_Facturas_ID__c, false);
            linesUpserted = results.size();
            for (Database.UpsertResult res : results) {
                if (!res.isSuccess()) {
                    System.debug(LoggingLevel.ERROR, 'Failed to upsert invoice line: ' + res.getErrors());
                }
            }
        }

        // Summary logs
        System.debug('Processing summary: Invoices processed=' + draftInvoices.size() + ', upserted=' + invoicesUpserted + ', omitted=' + invoicesOmitted +
                     '; Lines processed=' + draftLines.size() + ', upserted=' + linesUpserted + ', omitted=' + linesOmitted);
    }

    private static Boolean isProcessable(String dataResponse) {
        if (String.isBlank(dataResponse)) {
            return false;
        }
        if (!Schema.sObjectType.Facturas__c.isAccessible() || !Schema.sObjectType.Detalle_de_Facturas__c.isAccessible()) {
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
            System.debug(LoggingLevel.ERROR, 'Failed to parse JSON: ' + e.getMessage());
            return null;
        }
    }

    private static void buildInvoiceAndLine(Map<String, Object> node, Map<String, Facturas__c> draftInvoices, List<Detalle_de_Facturas__c> draftLines, Set<String> lineExtIds,
                                         Map<String, String> invoiceCardCodes, Map<String, String> lineItemCodes, Map<String, String> lineInvoiceExtIds, Map<String, String> invoiceOrderExtIds) {
        Map<String, Object> invoicesNode = (Map<String, Object>) node.get('Invoices');
        Map<String, Object> linesNode = (Map<String, Object>) node.get('Invoices/DocumentLines');
        if (invoicesNode == null || linesNode == null) {
            return;
        }

        String docEntry = String.valueOf(invoicesNode.get('DocEntry'));
        if (String.isBlank(docEntry)) {
            return;
        }

        // Build Invoice if not already
        if (!draftInvoices.containsKey(docEntry)) {
            Facturas__c inv = buildInvoice(invoicesNode);
            if (inv != null) {
                draftInvoices.put(docEntry, inv);
                invoiceCardCodes.put(docEntry, String.valueOf(invoicesNode.get('CardCode')));
                invoiceOrderExtIds.put(docEntry, docEntry); // DocEntry is used for Order lookup
            }
        }

        // Build Invoice Line
        String lineNum = String.valueOf(linesNode.get('LineNum'));
        if (String.isBlank(lineNum)) {
            return;
        }
        String extId = docEntry + '-' + lineNum;
        if (lineExtIds.contains(extId)) {
            return; // duplicate
        }
        lineExtIds.add(extId);
        Detalle_de_Facturas__c line = buildInvoiceDetail(linesNode);
        if (line != null) {
            line.Detalle_Facturas_ID__c = extId;
            draftLines.add(line);
            lineItemCodes.put(extId, String.valueOf(linesNode.get('ItemCode')));
            lineInvoiceExtIds.put(extId, docEntry);
        }
    }

    private static Facturas__c buildInvoice(Map<String, Object> invoicesNode) {
        Facturas__c inv = new Facturas__c();
        inv.Facturas_ID__c = String.valueOf(invoicesNode.get('DocEntry'));
        inv.N_mero_factura_de_ventas__c = IntegrationUtils.toDecimal(invoicesNode.get('DocNum'));
        inv.Folio_ID__c = String.valueOf(invoicesNode.get('FolioNumber'));
        inv.Fecha_contabilizaci_n__c = IntegrationUtils.toDate(invoicesNode.get('DocDate'));
        inv.Fecha_entrega__c = IntegrationUtils.toDate(invoicesNode.get('DocDueDate'));
        inv.Tipo_moneda_factura__c = String.valueOf(invoicesNode.get('DocCurrency'));
        inv.Id_link_factura_electr_nica__c = String.valueOf(invoicesNode.get('U_SEI_FEBOSID'));
        inv.Tipo_de_documentos__c = String.valueOf(invoicesNode.get('DocType'));
        inv.Direcci_n_de_factura__c = String.valueOf(invoicesNode.get('Address'));
        inv.Direcci_n_de_despacho_2__c = String.valueOf(invoicesNode.get('Address2'));
        inv.Direcci_n_de_despacho__c = String.valueOf(invoicesNode.get('ShipToCode'));
        inv.N_orden_de_compra_socio_negocios__c = IntegrationUtils.toDecimal(invoicesNode.get('NumAtCard'));
        inv.Total_documento_con_IVA__c = IntegrationUtils.toDecimal(invoicesNode.get('DocTotal'));
        inv.C_digo_del_vendedor__c = String.valueOf(invoicesNode.get('SalesPersonCode'));
        inv.Comentarios__c = String.valueOf(invoicesNode.get('Comments'));
        inv.Con_Receta__c = IntegrationUtils.mapReceta(String.valueOf(invoicesNode.get('U_Receta')));

        return inv;
    }

    private static Detalle_de_Facturas__c buildInvoiceDetail(Map<String, Object> linesNode) {
        Detalle_de_Facturas__c detail = new Detalle_de_Facturas__c();
        detail.Correlativo_interno_SAP__c = String.valueOf(linesNode.get('LineNum'));
        detail.Descripcion__c = String.valueOf(linesNode.get('ItemDescription'));
        detail.Cantidad__c = IntegrationUtils.toDouble(linesNode.get('Quantity'));
        detail.Fecha_de_Envio__c = IntegrationUtils.toDate(linesNode.get('ShipDate'));
        detail.Precio__c = IntegrationUtils.toDecimal(linesNode.get('Price'));
        detail.Precio_VAT__c = IntegrationUtils.toDecimal(linesNode.get('PriceAfterVAT'));
        detail.Codigo_de_Deposito_Almacen__c = String.valueOf(linesNode.get('WarehouseCode'));
        detail.Codigo_de_Barras__c = String.valueOf(linesNode.get('BarCode'));
        detail.Codigo_TAX__c = String.valueOf(linesNode.get('TaxCode'));

        return detail;
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

    private static Map<String, Order> buildOrderMap(List<String> docEntries) {
        Set<String> docEntriesSet = new Set<String>(docEntries);
        Map<String, Order> orderMap = new Map<String, Order>();
        for (Order ord : [SELECT Id, Pedidos_ID__c FROM Order WHERE Pedidos_ID__c IN :docEntriesSet WITH SYSTEM_MODE]) {
            orderMap.put(ord.Pedidos_ID__c, ord);
        }
        return orderMap;
    }
}