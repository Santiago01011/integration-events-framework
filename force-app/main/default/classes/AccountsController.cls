public class AccountsController {

    // MÉTODO CON RECORD TYPE DINÁMICO: Procesa los datos con Record Type específico
    public static void processAccountData(String dataResponse, String recordTypeName) {
        Map<String, Object> mapJSONResponse = (Map<String, Object>) JSON.deserializeUntyped(dataResponse);

        List<Account> accToUpdate = new List<Account>();
        List<Direcciones__c> direccionesToUpdate = new List<Direcciones__c>();

        Map<String, Id> mapAccounts = new Map<String, Id>(); 

        // Cargar cuentas existentes con External ID
        for (Account acc : [SELECT Id, Clientes_ID__c FROM Account WHERE Clientes_ID__c != null] ){
            mapAccounts.put(acc.Clientes_ID__c, acc.Id);
        }
		System.debug('mapAccounts inicial: ' + mapAccounts);

        // PASO 1: Procesar solo los datos de Account (SIN direcciones) con Record Type específico
        for (Object accJSONResponse : (List<Object>) mapJSONResponse.get('value')) {
            setDataAccount((Map<String, Object>) accJSONResponse, accToUpdate, recordTypeName);
        }

        // PASO 2: Hacer upsert de Accounts PRIMERO
        if (!accToUpdate.isEmpty()) {
            try {
                System.debug('Upsert de ' + accToUpdate.size() + ' cuentas...');
                upsert accToUpdate Clientes_ID__c;
                System.debug('✅ Upsert de Accounts exitoso');
                
                // PASO 3: Actualizar mapAccounts con las cuentas recién creadas/actualizadas
                mapAccounts.clear(); // Limpiar mapa
                for (Account acc : [SELECT Id, C_digo_socio_negocios__c FROM Account WHERE C_digo_socio_negocios__c != null] ){
                    mapAccounts.put(acc.C_digo_socio_negocios__c, acc.Id);
                }
                System.debug('mapAccounts actualizado: ' + mapAccounts);
                
            } catch (DmlException e) {
                System.debug('❌ Error al upsert cuentas: ' + e.getMessage());
                return; // Salir si falla el upsert de cuentas
            }
        }

        // PASO 4: Ahora procesar las direcciones con mapAccounts actualizado
        for (Object accJSONResponse : (List<Object>) mapJSONResponse.get('value')) {
            setAddressAccount((Map<String, Object>) accJSONResponse, direccionesToUpdate, mapAccounts);
        }

        // PASO 5: Hacer upsert de Direcciones si hay alguna
        if (!direccionesToUpdate.isEmpty()) {
            try {
                System.debug('Upsert de ' + direccionesToUpdate.size() + ' direcciones...');
                upsert direccionesToUpdate Direcciones_ID__c;
                System.debug('✅ Upsert de Direcciones exitoso');
            } catch (DmlException e) {
                System.debug('❌ Error al upsert direcciones: ' + e.getMessage());
            }
        } else {
            System.debug('ℹ️ No hay direcciones para procesar');
        }
    }

    private static void setAddressAccount(Map<String, Object> accJSONResponse, List<Direcciones__c> direccionesToUpdate, Map<String, Id> mapAccounts){
        String cardCode = String.valueOf(accJSONResponse.get('CardCode'));
        Id accountId = mapAccounts.get(cardCode);
        
        System.debug('setAddressAccount - CardCode: ' + cardCode + ', AccountId encontrado: ' + accountId);
        
        // Solo crear direcciones si encontramos el Account
        if (accountId == null) {
            System.debug('⚠️ ADVERTENCIA: No se encontró Account para CardCode: ' + cardCode);
            return;
        }
        
        // Dirección principal
        if(accJSONResponse.get('Address') != null && String.valueOf(accJSONResponse.get('Address')) != 'null'){ 
            Direcciones__c dirAddress = new Direcciones__c();
            dirAddress.Direcciones_ID__c = cardCode + '-Address';
            dirAddress.Name = String.valueOf(accJSONResponse.get('Address'));
            dirAddress.Account__c = accountId;
            direccionesToUpdate.add(dirAddress);
            System.debug('✅ Dirección Address creada: ' + dirAddress.Name + ' -> Account: ' + accountId);
        }

        // Dirección de correo
        if(accJSONResponse.get('MailAddress') != null && String.valueOf(accJSONResponse.get('MailAddress')) != 'null'){
            Direcciones__c dirMail = new Direcciones__c();
            dirMail.Direcciones_ID__c = cardCode + '-Mail';
            dirMail.Name = String.valueOf(accJSONResponse.get('MailAddress'));
            dirMail.Account__c = accountId;
            direccionesToUpdate.add(dirMail);
            System.debug('✅ Dirección Mail creada: ' + dirMail.Name + ' -> Account: ' + accountId);
        }

        // Dirección de envío
        if(accJSONResponse.get('ShipToDefault') != null && String.valueOf(accJSONResponse.get('ShipToDefault')) != 'null'){
            Direcciones__c dirShip = new Direcciones__c();
            dirShip.Direcciones_ID__c = cardCode + '-ShipTo';
            dirShip.Name = String.valueOf(accJSONResponse.get('ShipToDefault'));
            dirShip.Account__c = accountId;
            direccionesToUpdate.add(dirShip);
            System.debug('✅ Dirección ShipTo creada: ' + dirShip.Name + ' -> Account: ' + accountId);
        }
    }

    //mapea los datos de la respuesta JSON a un objeto Account de Salesforce
    private static void setDataAccount(Map<String, Object> accJSONResponse, List<Account> accToUpdate, String recordTypeName) {
        Account acc = new Account();

        // Asignar Record Type dinámico según el parámetro recibido
        try {
            Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
            acc.RecordTypeId = recordTypeId;
            System.debug('✅ Record Type ' + recordTypeName + ' asignado: ' + recordTypeId);
        } catch (Exception e) {
            System.debug('❌ Error asignando Record Type ' + recordTypeName + ': ' + e.getMessage());
            System.debug('💡 Nota: Verifique que el Record Type "' + recordTypeName + '" existe en el objeto Account');
        }

        acc.Clientes_ID__c = (String) accJSONResponse.get('CardCode');
        acc.C_digo_socio_negocios__c = (String) accJSONResponse.get('CardCode'); 
        acc.Name = (String) accJSONResponse.get('CardName');
        if ( accJSONResponse.get('CardType') == 'cSupplier'){
            	acc.Type = 'Proveedor';    
        }else if (accJSONResponse.get('CardType') == 'cCustomer' ){
            acc.Type = 'Cliente';
        }
        acc.Cod_d_grp__c = String.valueof( accJSONResponse.get('GroupCode')); 
        acc.BillingCity = (String) accJSONResponse.get('City'); 
        acc.BillingState = (String) accJSONResponse.get('County');
        acc.BillingPostalCode = (String) accJSONResponse.get('ZipCode');
        acc.BillingCountry = (String) accJSONResponse.get('Country'); 
        acc.ShippingCity = (String) accJSONResponse.get('MailCity'); 
        acc.ShippingState = (String) accJSONResponse.get('MailCounty');
        acc.ShippingPostalCode = (String) accJSONResponse.get('MailZipCode');
        acc.ShippingCountry = (String) accJSONResponse.get('MailCountry');
        acc.Phone = (String) accJSONResponse.get('Phone1'); 
        acc.Phone2__c = (String) accJSONResponse.get('Phone2'); 
        acc.Fax = (String) accJSONResponse.get('Fax'); 
        //acc.ContactPerson = (String) accJSONResponse.get('ContactPerson');revisar para crear contacto, numero de telefono de contacto
        acc.Notas__c = (String) accJSONResponse.get('Notes');
        // Campos financieros y comerciales
        if (accJSONResponse.get('CreditLimit') != null) {
            acc.Limite_de_Cr_dito__c = (Decimal) accJSONResponse.get('CreditLimit');
        }
        if (accJSONResponse.get('CurrentAccountBalance') != null) {
            acc.Saldo_deuda_cliente__c = String.valueOf(accJSONResponse.get('CurrentAccountBalance'));
        }
        if (accJSONResponse.get('VatLiable') != null) {
            String vatLiable = String.valueOf(accJSONResponse.get('VatLiable'));
            acc.Impuesto_siempre_IVA__c = 'vLiable'.equals(vatLiable) ? 'SI' : 'NO';
        }
        
        acc.Rut_del_Cliente__c = (String) accJSONResponse.get('FederalTaxID');
        
        if (accJSONResponse.get('PriceListNum') != null) {
            //acc.PriceListNum__c = (Integer) accJSONResponse.get('PriceListNum');
        } 
        // Manejar SalesPersonCode especial (-1 = Sin vendedor)
        if (accJSONResponse.get('SalesPersonCode') != null) {
            Integer salesPersonCode = (Integer) accJSONResponse.get('SalesPersonCode');
            acc.Codigo_del_vendedor__c = salesPersonCode == -1 ? 'NINGUNO' : String.valueOf(salesPersonCode);
        } 
        acc.Saldo_pendiente_de_notas__c = (Decimal) accJSONResponse.get('OpenOrdersBalance'); 
        acc.Cliente_Activo_Inactivo__c = accJSONResponse.get('Valid') == 'tYES'?'Activo':'Inactivo'; 
        acc.Frozen__c = accJSONResponse.get('Frozen') == 'tYES'?true: false ; 
        acc.Email_por_defecto__c = (String) accJSONResponse.get('EmailAddress');

        accToUpdate.add(acc);
    }
    
    // MÉTODO LEGACY: Para mantener compatibilidad con versión anterior
    public static void processAccountData(String dataResponse) {
        System.debug('⚠️ Usando método legacy processAccountData() - Defaulting to Record Type "Profar"');
        processAccountData(dataResponse, 'Profar');
    }
}