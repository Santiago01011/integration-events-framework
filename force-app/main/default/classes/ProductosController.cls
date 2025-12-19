/**
 * @description Controller responsable de mapear y actualizar/insertar de Productos desde un sistema externo.
 * Query para consultar todos los campos insertados por este controlador:
 * SELECT Id, Productos_ID__c, Name, Principio_activo__c, Generico__c, Rotomat__c, Departamento__c, Categoria__c, Sub_categoria__c, IsActive, Codigo_de_barra__c, Family, Sub_familia_del_producto__c, Proveedor_por_defecto__c, Laboratorio__c, Grupo_de_articulos__c, CreatedDate, LastModifiedDate, SystemModstamp FROM Product2
 */
public without sharing class ProductosController {
    
    public class ProcessResult {
        public Integer productsProcessed;
        public Integer productsUpserted;
        public Integer productsSkipped;
        public List<String> skippedProductDetails;
        public List<String> productErrors;
        
        public ProcessResult() {
            this.productsProcessed = 0;
            this.productsUpserted = 0;
            this.productsSkipped = 0;
            this.skippedProductDetails = new List<String>();
            this.productErrors = new List<String>();
        }
    }
    
    public class ProductError {
        public String itemCode;
        public String message;
        
        public ProductError(String itemCode, String message) {
            this.itemCode = itemCode;
            this.message = message;
        }
    }
  /**
   * @description Procesa una lista deserializada de productos y realiza upsert de Product2.
   * Para los productos que no se puedan mapear o insertar, se registran errores en IntegrationEvent. Revisar `IntegrationEventPublisher`.
   * @param productNodes Lista de mapas con la estructura del payload (Items, Manufacturers, ItemGroups).
   * @return ProcessResult con métricas detalladas del procesamiento.
   */
  public static ProcessResult processProductList(List<Map<String, Object>> productNodes) {
    ProcessResult result = new ProcessResult();
    
    if (productNodes == null || productNodes.isEmpty()) {
      return result;
    }
    if (!Schema.sObjectType.Product2.isAccessible()) {
      result.productErrors.add('No access to Product2 object');
      return result;
    }

    List<Product2> pending = new List<Product2>();
    List<String> skippedProducts = new List<String>();
    
    for (Map<String, Object> node : productNodes) {
      result.productsProcessed++;
      Product2 rec = buildRecord(node);
      if (rec != null) {
        pending.add(rec);
      } else {
        Map<String, Object> items = (Map<String, Object>) node.get('Items');
        String itemCode = items != null ? String.ValueOf(items.get('ItemCode')) : 'null';
        String itemName = items != null ? String.ValueOf(items.get('ItemName')) : 'Unknown';
        String skipDetail = 'ItemCode: ' + itemCode + ', ItemName: ' + itemName + ' - Missing or invalid ItemCode';
        skippedProducts.add(skipDetail);
        result.skippedProductDetails.add(skipDetail);
        result.productsSkipped++;
      }
    }
    
    if (!skippedProducts.isEmpty()) {
      String errorMessage = 'Skipped ' + skippedProducts.size() + ' products due to missing or invalid ItemCode: ' + String.join(skippedProducts, '; ');
      result.productErrors.add(errorMessage);
    }
    
    if (pending.isEmpty()) {
      return result;
    }
    
    Database.UpsertResult[] upsertResults = Database.upsert(
      pending,
      Product2.Fields.Productos_ID__c,
      false
    );
    
    Integer upsertedCount = 0;
    List<String> upsertErrors = new List<String>();
    
    for (Integer i = 0; i < upsertResults.size(); i++) {
      Database.UpsertResult ur = upsertResults[i];
      if (ur.isSuccess()) {
        upsertedCount++;
      } else {
        String itemCode = pending[i].Productos_ID__c;
        String errorMsg = 'ItemCode: ' + itemCode + ' - ' + ur.getErrors()[0].getMessage();
        upsertErrors.add(errorMsg);
        result.productErrors.add(errorMsg);
      }
    }
    
    result.productsUpserted = upsertedCount;
    
    List<Id> newlyCreatedProductIds = new List<Id>();
    for (Database.UpsertResult ur : upsertResults) {
      if (ur.isSuccess() && ur.isCreated()) {
        newlyCreatedProductIds.add(ur.getId());
      }
    }

    if (!newlyCreatedProductIds.isEmpty()) {
      createPricebookEntries(newlyCreatedProductIds);
    }

    return result;
  }

  /**
   * @description Procesa el JSON crudo proveniente del callout y realiza upsert de Product2.
   * @param dataResponse JSON string con la raíz que contiene la lista de productos en la key 'value'.
   * @deprecated Use processProductList(List<Map<String,Object>>) for better performance and flexibility.
   */
  public static void processProductData(String dataResponse) {
    if (!isProcessable(dataResponse)) {
      return;
    }
    List<Object> vals = extractValueArray(dataResponse);
    if (vals == null) {
      return;
    }
    List<Map<String, Object>> productNodes = new List<Map<String, Object>>();
    for (Object o : vals) {
      productNodes.add((Map<String, Object>) o);
    }
    processProductList(productNodes);

  }

  /**
   * @description Verifica que el payload sea válido y que el usuario tenga acceso de lectura a Product2.
   * @param dataResponse JSON de entrada.
   * @return true si se puede procesar.
   */
  private static Boolean isProcessable(String dataResponse) {
    if (String.isBlank(dataResponse)) {
      //System.debug('No se encontraron productos para procesar.');
      return false;
    }
    if (!Schema.sObjectType.Product2.isAccessible()) {
      return false;
    }
    return true;
  }

  /**
   * @description Extrae y retorna el arreglo 'value' del JSON.
   * @param dataResponse JSON crudo.
   * @return Lista con los elementos del nodo 'value' o null.
   * @deprecated Revisar `processProductData`.
   */
  private static List<Object> extractValueArray(String dataResponse) {
    try {
      Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(
        dataResponse
      );
      if (root == null) {
        return null;
      }
      return (List<Object>) root.get('value');
    } catch (JSONException e) {
    //   System.debug(LoggingLevel.ERROR, 'Failed to parse JSON: ' + e.getMessage());
      return null;
    }
  }

  /**
   * @description Crea o completa un registro Product2 a partir del nodo JSON.
   * @param node Nodo raíz del producto (incluye subobjetos Items, Manufacturers, ItemGroups).
   * @param existing Mapa de productos existentes.
   * @return Registro Product2 listo para upsert o null si se descarta.
   */
  private static Product2 buildRecord(Map<String, Object> node) {
    if (node == null) {
      return null;
    }
    Map<String, Object> items = (Map<String, Object>) node.get('Items');
    if (items == null) {
      return null;
    }
    String code = String.ValueOf(items.get('ItemCode'));
    if (String.isBlank(code) || code == 'null') {
      return null;
    }
    Product2 p = new Product2();
    p.Productos_ID__c = code;
    mapItemFields(p, items);
    applyManufacturer(p, node);
    applyGroup(p, node);
    return p;
  }

  /**
   * @description Mapea campos del subobjeto Items a Product2.
   * @param p Instancia Product2 destino.
   * @param items Mapa con los campos del subobjeto Items.
   */
  private static void mapItemFields(Product2 p, Map<String, Object> items) {
    p.Name = String.ValueOf(items.get('ItemName'));
    p.ProductCode = String.ValueOf(items.get('ItemCode'));
    p.Principio_activo__c = String.ValueOf(items.get('U_SEI_PA'));
    p.Generico__c = String.ValueOf(items.get('U_SEI_GEN'));
    p.Rotomat__c = String.ValueOf(items.get('U_SEI_ROT'));
    p.Departamento__c = String.ValueOf(items.get('U_Departamento'));

    String categoriaValue = String.ValueOf(items.get('U_Categoria'));
    p.Categoria__c = IntegrationUtils.isValidPicklistValue(
        'Product2',
        'Categoria__c',
        categoriaValue
      )
      ? categoriaValue
      : null;

    String subCategoriaValue = String.ValueOf(items.get('U_SubCategoria'));
    p.Sub_categoria__c = IntegrationUtils.isValidPicklistValue(
        'Product2',
        'Sub_categoria__c',
        subCategoriaValue
      )
      ? subCategoriaValue
      : null;

    p.IsActive = 'Y' == String.ValueOf(items.get('Valid'));
    p.Codigo_de_barra__c = String.ValueOf(items.get('BarCode'));
    p.Family = String.ValueOf(items.get('U_SEI_FAM'));

    String subFamiliaValue = String.ValueOf(items.get('U_SEI_SUBFAM'));
    p.Sub_familia_del_producto__c = IntegrationUtils.isValidPicklistValue(
        'Product2',
        'Sub_familia_del_producto__c',
        subFamiliaValue
      )
      ? subFamiliaValue
      : null;

    p.Proveedor_por_defecto__c = String.ValueOf(items.get('Mainsupplier'));
  }

  /**
   * @description Mapea el fabricante (Manufacturers.ManufacturerName) normalizando placeholder.
   * @param p Instancia Product2 destino.
   * @param node Nodo raíz con posible subobjeto Manufacturers.
   */
  private static void applyManufacturer(Product2 p, Map<String, Object> node) {
    Map<String, Object> man = (Map<String, Object>) node.get('Manufacturers');
    if (man == null) {
      return;
    }
    String m = String.ValueOf(man.get('ManufacturerName'));
    p.Laboratorio__c = m;
  }

  /**
   * @description Mapea el grupo de artículos (ItemGroups.GroupName).
   * @param p Instancia Product2 destino.
   * @param node Nodo raíz con posible subobjeto ItemGroups.
   */
  private static void applyGroup(Product2 p, Map<String, Object> node) {
    Map<String, Object> grp = (Map<String, Object>) node.get('ItemGroups');
    if (grp == null) {
      return;
    }
    p.Grupo_de_articulos__c = String.ValueOf(grp.get('GroupName'));
  }

  /**
   * @description Creates PricebookEntry records for products in the standard pricebook if they don't exist.
   * @param productIds List of Product2 Ids to create PricebookEntries for.
   */
  private static void createPricebookEntries(List<Id> productIds) {
    if (!Schema.sObjectType.PricebookEntry.isCreateable()) {
      return;
    }

    Id pricebookId = Test.isRunningTest()
      ? Test.getStandardPricebookId()
      : [
          SELECT Id
          FROM Pricebook2
          WHERE IsStandard = TRUE
          WITH SYSTEM_MODE
          LIMIT 1
        ]
        ?.Id;
    if (pricebookId == null) {
      return;
    }

    Set<Id> existingProductIds = new Set<Id>();
    for (PricebookEntry pbe : [
      SELECT Product2Id
      FROM PricebookEntry
      WHERE Product2Id IN :productIds AND Pricebook2Id = :pricebookId
    ]) {
      existingProductIds.add(pbe.Product2Id);
    }

    // Create PricebookEntries for products that don't have one
    List<PricebookEntry> newEntries = new List<PricebookEntry>();
    for (Id productId : productIds) {
      if (!existingProductIds.contains(productId)) {
        newEntries.add(
          new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = productId,
            UnitPrice = 0.00,
            IsActive = true
          )
        );
      }
    }

    if (!newEntries.isEmpty()) {
      Database.insert(newEntries, false);
      //System.debug('Created ' + newEntries.size() + ' PricebookEntries for new products.');
    }
  }
}
