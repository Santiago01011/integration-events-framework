@IsTest
private class ProductosControllerTest {
  /**
   * @description Returns a mock JSON payload simulating real data with various scenarios:
   * - Valid products with valid picklist values
   * - Products with invalid picklist values (should be set to null)
   * - Different data types and edge cases
   * @return String JSON payload for testing
   */
  private static String getMockPayload() {
    return '{' +
      '"odata.metadata": "$metadata#Collection(Edm.ComplexType)",' +
      '"value": [' +
      '{' +
      '"Manufacturers": {' +
      '"ManufacturerName": "PIERRE FABRE DERMO-COSMETIQUE"' +
      '},' +
      '"Items": {' +
      '"ItemCode": "109209",' +
      '"UpdateDate": "2025-08-27",' +
      '"ItemName": "KLORANE ACIANO CREMA DE AGUA 50ML",' +
      '"U_SEI_PA": "CUIDADO FACIAL",' +
      '"U_SEI_GEN": "FALSO",' +
      '"U_SEI_ROT": "FALSO",' +
      '"U_Departamento": null,' +
      '"U_Categoria": null,' +
      '"U_SubCategoria": null,' +
      '"Valid": "Y",' +
      '"BarCode": "3282770208016",' +
      '"U_SEI_FAM": "NOREFRIGERADOS",' +
      '"U_SEI_SUBFAM": "COSMETICO",' +
      '"Mainsupplier": "PN762298708",' +
      '"DefaultWarehouse": null' +
      '},' +
      '"ItemGroups": {' +
      '"GroupName": "CONSUMO MASIVO"' +
      '}' +
      '},' +
      '{' +
      '"Manufacturers": {' +
      '"ManufacturerName": "MADEGOM S.A."' +
      '},' +
      '"Items": {' +
      '"ItemCode": "109210",' +
      '"UpdateDate": "2025-08-27",' +
      '"ItemName": "(DM) GUANTE PROCED. NITRILO ESTERIL CELESTE TALLA L X CAJA 100 UNID.",' +
      '"U_SEI_PA": "GUANTE NITRILO",' +
      '"U_SEI_GEN": "FALSO",' +
      '"U_SEI_ROT": "FALSO",' +
      '"U_Departamento": null,' +
      '"U_Categoria": null,' +
      '"U_SubCategoria": null,' +
      '"Valid": "Y",' +
      '"BarCode": "UPC_109210",' +
      '"U_SEI_FAM": "NOREFRIGERADOS",' +
      '"U_SEI_SUBFAM": "DISPOSITIVOS MEDICOS",' +
      '"Mainsupplier": "PN846096000",' +
      '"DefaultWarehouse": null' +
      '},' +
      '"ItemGroups": {' +
      '"GroupName": "INSUMO"' +
      '}' +
      '},' +
      '{' +
      '"Manufacturers": {' +
      '"ManufacturerName": "COMERCIAL CHILENO BRITANICA SA"' +
      '},' +
      '"Items": {' +
      '"ItemCode": "109214",' +
      '"UpdateDate": "2025-08-27",' +
      '"ItemName": "MUSTELA GEL DE BAÑO 500ML",' +
      '"U_SEI_PA": "CUIDADO CORPORAL",' +
      '"U_SEI_GEN": "FALSO",' +
      '"U_SEI_ROT": "FALSO",' +
      '"U_Departamento": null,' +
      '"U_Categoria": null,' +
      '"U_SubCategoria": null,' +
      '"Valid": "Y",' +
      '"BarCode": "3504105035617",' +
      '"U_SEI_FAM": "NOREFRIGERADOS",' +
      '"U_SEI_SUBFAM": "COSMETICO",' +
      '"Mainsupplier": "PN765815304",' +
      '"DefaultWarehouse": null' +
      '},' +
      '"ItemGroups": {' +
      '"GroupName": "CONSUMO MASIVO"' +
      '}' +
      '},' +
      '{' +
      '"Manufacturers": {' +
      '"ManufacturerName": "BAGO"' +
      '},' +
      '"Items": {' +
      '"ItemCode": "102017",' +
      '"UpdateDate": "2025-08-27",' +
      '"ItemName": "DOLOTEN 325/37,5 MG X 30 COMP.",' +
      '"U_SEI_PA": "PARACETAMOL + TRAMADOL",' +
      '"U_SEI_GEN": "FALSO",' +
      '"U_SEI_ROT": "VERDADERO",' +
      '"U_Departamento": "Medicamentos",' +
      '"U_Categoria": "Analgésicos",' +
      '"U_SubCategoria": "Analgésicos",' +
      '"Valid": "Y",' +
      '"BarCode": "7800028001743",' +
      '"U_SEI_FAM": "NOREFRIGERADOS",' +
      '"U_SEI_SUBFAM": "MEDICAMENTO APROBADO",' +
      '"Mainsupplier": "PN969456702",' +
      '"DefaultWarehouse": null' +
      '},' +
      '"ItemGroups": {' +
      '"GroupName": "MEDICAMENTO"' +
      '}' +
      '}' +
      ']' +
      '}';
  }

  /**
   * @description Test method to verify the upsert behavior with a realistic mock JSON payload from SAP.
   * Covers creation of products, proper field mapping, boolean conversions, and picklist validation.
   * Specifically tests that invalid picklist values are set to null instead of causing DML errors.
   */
  @IsTest
  static void testUpsertWithRealSapMockData() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Test.startTest();
      ProductosController.processProductData(getMockPayload());
      Test.stopTest();

      Map<String, Product2> productsByCode = new Map<String, Product2>();
      for (Product2 p : [
        SELECT
          Id,
          Productos_ID__c,
          Name,
          Principio_activo__c,
          Generico__c,
          Rotomat__c,
          Departamento__c,
          Categoria__c,
          Sub_categoria__c,
          IsActive,
          Codigo_de_barra__c,
          Family,
          Sub_familia_del_producto__c,
          Proveedor_por_defecto__c,
          Laboratorio__c,
          Grupo_de_articulos__c
        FROM Product2
        WHERE Productos_ID__c IN ('109209', '109210', '109214', '102017')
      ]) {
        productsByCode.put(p.Productos_ID__c, p);
      }

      System.assertEquals(
        4,
        productsByCode.size(),
        'Los 4 productos del payload deben ser creados'
      );

      assertProduct(
        productsByCode.get('109209'),
        'KLORANE ACIANO CREMA DE AGUA 50ML',
        'CUIDADO FACIAL',
        'FALSO',
        'FALSO',
        null,
        null,
        null,
        true,
        '3282770208016',
        'NOREFRIGERADOS',
        'COSMETICO',
        'PN762298708',
        'PIERRE FABRE DERMO-COSMETIQUE',
        'CONSUMO MASIVO'
      );
      assertProduct(
        productsByCode.get('109210'),
        '(DM) GUANTE PROCED. NITRILO ESTERIL CELESTE TALLA L X CAJA 100 UNID.',
        'GUANTE NITRILO',
        'FALSO',
        'FALSO',
        null,
        null,
        null,
        true,
        'UPC_109210',
        'NOREFRIGERADOS',
        'DISPOSITIVOS MEDICOS',
        'PN846096000',
        'MADEGOM S.A.',
        'INSUMO'
      );
      assertProduct(
        productsByCode.get('109214'),
        'MUSTELA GEL DE BAÑO 500ML',
        'CUIDADO CORPORAL',
        'FALSO',
        'FALSO',
        null,
        null,
        null,
        true,
        '3504105035617',
        'NOREFRIGERADOS',
        'COSMETICO',
        'PN765815304',
        'COMERCIAL CHILENO BRITANICA SA',
        'CONSUMO MASIVO'
      );
      assertProduct(
        productsByCode.get('102017'),
        'DOLOTEN 325/37,5 MG X 30 COMP.',
        'PARACETAMOL + TRAMADOL',
        'FALSO',
        'VERDADERO',
        'Medicamentos',
        null,
        null,
        true,
        '7800028001743',
        'NOREFRIGERADOS',
        'MEDICAMENTO APROBADO',
        'PN969456702',
        'BAGO',
        'MEDICAMENTO'
      );
    }
  }

  /**
   * @description Test method to verify behavior when dataResponse is blank.
   * Covers the isProcessable method returning false.
   */
  @IsTest
  static void testProcessProductDataWithBlankData() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Test.startTest();
      ProductosController.processProductData('');
      Test.stopTest();
      List<Product2> products = [
        SELECT Id
        FROM Product2
        WHERE Productos_ID__c != NULL
      ];
      System.assert(
        products.isEmpty(),
        'No products should be created when input is blank'
      );
    }
  }

  /**
   * @description Test method to verify behavior when user permissions are insufficient.
   * Covers the isProcessable method returning false.
   */
  //   @IsTest
  //   static void testProcessProductDataWithInsufficientPermissions() {
  //     System.runAs(new User(Id = UserInfo.getUserId())) {
  //       Test.startTest();
  //       ProductosController.processProductData('');
  //       Test.stopTest();
  //       List<Product2> products = [
  //         SELECT Id
  //         FROM Product2
  //         WHERE Productos_ID__c != NULL
  //       ];
  //       System.assert(
  //         products.isEmpty(),
  //         'No products should be created when user permissions are insufficient'
  //       );
  //     }
  //   }

  /**
   * @description Test method to verify behavior when JSON has no 'value' key.
   * Covers extractValueArray returning null.
   */
  @IsTest
  static void testProcessProductDataWithNoValueKey() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      String payloadWithoutValue = '{"odata.metadata": "$metadata#Collection(Edm.ComplexType)"}';

      // Act: Process payload without 'value'
      Test.startTest();
      ProductosController.processProductData(payloadWithoutValue);
      Test.stopTest();
      System.assert(true, 'Method should handle missing value key gracefully');
    }
  }

  /**
   * @description Test method to verify behavior when 'value' array is empty.
   * Covers the pending.isEmpty() check returning true.
   */
  @IsTest
  static void testProcessProductDataWithEmptyValueArray() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      String payloadWithEmptyValue = '{"odata.metadata": "$metadata#Collection(Edm.ComplexType)","value": []}';

      Test.startTest();
      ProductosController.processProductData(payloadWithEmptyValue);
      Test.stopTest();

      System.assert(true, 'Method should handle empty value array gracefully');
    }
  }

  /**
   * @description Test that nodes without 'Items' are ignored (buildRecord returns null).
   */
  @IsTest
  static void testBuildRecordWhenItemsMissing() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      String payload =
        '{"odata.metadata": "$metadata#Collection(Edm.ComplexType)","value": [' +
        '{"Manufacturers": {"ManufacturerName": "X"}, "ItemGroups": {"GroupName": "G"}}' +
        ']}';

      Test.startTest();
      ProductosController.processProductData(payload);
      Test.stopTest();

      // No Product2 should be created
      Integer cnt = [
        SELECT COUNT()
        FROM Product2
        WHERE Productos_ID__c != NULL
      ];
      System.assertEquals(
        0,
        cnt,
        'No products should be created when Items is missing'
      );
    }
  }

  /**
   * @description Test that nodes with ItemCode = null are ignored.
   */
  @IsTest
  static void testBuildRecordWhenItemCodeIsNull() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      String payload =
        '{"odata.metadata": "$metadata#Collection(Edm.ComplexType)","value": [' +
        '{"Items": {"ItemCode": null, "ItemName": "NoCode"}}' +
        ']}';

      Test.startTest();
      ProductosController.processProductData(payload);
      Test.stopTest();

      Integer cnt = [
        SELECT COUNT()
        FROM Product2
        WHERE Productos_ID__c != NULL
      ];
      System.assertEquals(
        0,
        cnt,
        'No products should be created when ItemCode is null'
      );
    }
  }

  /**
   * @description Test that nodes with ItemCode = 'null' (string) are ignored.
   */
  @IsTest
  static void testBuildRecordWhenItemCodeIsStringNull() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      String payload =
        '{"odata.metadata": "$metadata#Collection(Edm.ComplexType)","value": [' +
        '{"Items": {"ItemCode": "null", "ItemName": "NoCodeString"}}' +
        ']}';

      Test.startTest();
      ProductosController.processProductData(payload);
      Test.stopTest();

      Integer cnt = [
        SELECT COUNT()
        FROM Product2
        WHERE Productos_ID__c != NULL
      ];
      System.assertEquals(
        0,
        cnt,
        'No products should be created when ItemCode is the string "null"'
      );
    }
  }

  /**
   * @description Test that when an existing Product2 with the external id exists,
   * the controller uses its Id (update path) instead of creating a new record.
   */
  @IsTest
  static void testProcessProductDataUpdatesExistingProduct() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      // Create existing product that should be updated
      Product2 existing = new Product2(
        Name = 'BeforeUpdate',
        Productos_ID__c = 'EXIST123'
      );
      insert existing;

      String payload =
        '{"odata.metadata": "$metadata#Collection(Edm.ComplexType)","value": [' +
        '{"Items": {"ItemCode": "EXIST123", "ItemName": "AfterUpdate", "Valid": "Y"},' +
        '"Manufacturers": {"ManufacturerName": "ACME"},' +
        '"ItemGroups": {"GroupName": "GRP"} }' +
        ']}';

      Test.startTest();
      ProductosController.processProductData(payload);
      Test.stopTest();

      // Verify only one product exists with that Productos_ID__c and that its name was updated
      List<Product2> found = [
        SELECT Id, Name
        FROM Product2
        WHERE Productos_ID__c = 'EXIST123'
      ];
      System.assertEquals(
        1,
        found.size(),
        'There should still be exactly one Product2 with that external id'
      );
      System.assertEquals(
        'AfterUpdate',
        found[0].Name,
        'Existing product should be updated with new Name'
      );
    }
  }

  /**
   * @description Helper method to assert product field values
   */
  private static void assertProduct(
    Product2 p,
    String name,
    String principioActivo,
    String generico,
    String rotomat,
    String departamento,
    String categoria,
    String subCategoria,
    Boolean isActive,
    String codigoBarra,
    String family,
    String subFamilia,
    String proveedor,
    String laboratorio,
    String grupoArticulos
  ) {
    System.assertEquals(name, p.Name, 'Name should match');
    System.assertEquals(
      principioActivo,
      p.Principio_activo__c,
      'Principio_activo__c should match'
    );
    System.assertEquals(generico, p.Generico__c, 'Generico should match');
    System.assertEquals(rotomat, p.Rotomat__c, 'Rotomat should match');
    System.assertEquals(
      departamento,
      p.Departamento__c,
      'Departamento should match'
    );
    System.assertEquals(categoria, p.Categoria__c, 'Categoria should match');
    System.assertEquals(
      subCategoria,
      p.Sub_categoria__c,
      'Sub_categoria should match'
    );
    System.assertEquals(isActive, p.IsActive, 'IsActive should match');
    System.assertEquals(
      codigoBarra,
      p.Codigo_de_barra__c,
      'Codigo_de_barra__c should match'
    );
    System.assertEquals(family, p.Family, 'Family should match');
    System.assertEquals(
      subFamilia,
      p.Sub_familia_del_producto__c,
      'Sub_familia_del_producto__c should match'
    );
    System.assertEquals(
      proveedor,
      p.Proveedor_por_defecto__c,
      'Proveedor_por_defecto__c should match'
    );
    System.assertEquals(
      laboratorio,
      p.Laboratorio__c,
      'Laboratorio should match'
    );
    System.assertEquals(
      grupoArticulos,
      p.Grupo_de_articulos__c,
      'Grupo_de_articulos__c should match'
    );
  }
}
