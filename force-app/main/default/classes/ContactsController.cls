public class ContactsController {

    // Procesa los datos de la respuesta y actualiza los contactos
    public static void processContactData(String dataResponse) {
        try {
            System.debug('🚀 INICIANDO processContactData...');
            System.debug('📥 dataResponse recibido: ' + (dataResponse != null ? dataResponse.length() + ' caracteres' : 'NULL'));
            
            if (String.isBlank(dataResponse)) {
                System.debug('❌ ERROR: dataResponse está vacío o null');
                return;
            }
            
            Map<String, Object> mapJSONResponse = (Map<String, Object>) JSON.deserializeUntyped(dataResponse);
            System.debug('✅ JSON deserializado correctamente');
            System.debug('🔍 Claves del JSON: ' + mapJSONResponse.keySet());
            
            List<Contact> contactsToUpdate = new List<Contact>();
            Map<String, Id> mapAccounts = new Map<String, Id>();
       
       //Relacion lookup account
        for (Account acc : [SELECT Id, Clientes_ID__c FROM Account WHERE Clientes_ID__c != null]) {
            mapAccounts.put(acc.Clientes_ID__c, acc.Id);
        }
        
        
            // Verificar si existe la clave 'value' en el JSON
            if (!mapJSONResponse.containsKey('value')) {
                System.debug('❌ ERROR: El JSON no contiene la clave "value"');
                System.debug('🔍 Claves disponibles: ' + mapJSONResponse.keySet());
                return;
            }
            
            Object valueObject = mapJSONResponse.get('value');
            if (valueObject == null) {
                System.debug('❌ ERROR: La clave "value" es null');
                return;
            }
            
            List<Object> contactsList = (List<Object>) valueObject;
            System.debug('📊 Cantidad de contactos encontrados: ' + contactsList.size());
            
            for (Integer i = 0; i < contactsList.size(); i++) {
                try {
                    System.debug('🔄 Procesando contacto #' + (i + 1));
                    Object contactJSONResponse = contactsList[i];
                    setDataContact((Map<String, Object>) contactJSONResponse, contactsToUpdate, mapAccounts);
                    System.debug('✅ Contacto #' + (i + 1) + ' procesado exitosamente');
                } catch (Exception contactError) {
                    System.debug('❌ ERROR procesando contacto #' + (i + 1) + ': ' + contactError.getMessage());
                    System.debug('❌ Stack trace contacto #' + (i + 1) + ': ' + contactError.getStackTraceString());
                }
            }

        // Realiza upsert de los contactos por si hay que actualizar alguno
        if (!contactsToUpdate.isEmpty()) {
            System.debug('🔄 Iniciando upsert de ' + contactsToUpdate.size() + ' contactos...');
            try {
                upsert contactsToUpdate ID_Externo_Contactos__c;
                System.debug('✅ Upsert completado exitosamente');
            } catch (DmlException e) {
                System.debug('❌ ERROR en upsert: ' + e.getMessage());
                System.debug('❌ Stack trace upsert: ' + e.getStackTraceString());
            }
        } else {
            System.debug('⚠️ No hay contactos para procesar');
        }
        
        } catch (Exception e) {
            System.debug('❌ ERROR CRÍTICO en processContactData: ' + e.getMessage());
            System.debug('❌ Stack trace completo: ' + e.getStackTraceString());
            System.debug('❌ Línea del error: ' + e.getLineNumber());
            System.debug('❌ Tipo de excepción: ' + e.getTypeName());
        }
    }

    // Mapea los datos de la respuesta JSON a objetos Contact de Salesforce
    private static void setDataContact(Map<String, Object> contactJSONResponse, List<Contact> contactsToUpdate, Map<String, Id> mapAccounts) {
        try {
            System.debug('🔧 Iniciando setDataContact...');
            System.debug('🔍 contactJSONResponse keys: ' + contactJSONResponse.keySet());
            
            Contact contact = new Contact();

     	Map<String, Object> businessJSONResponse = (Map<String, Object>) contactJSONResponse.get('BusinessPartners');
		String accountExternalID = String.ValueOf(businessJSONResponse.get('CardCode'));
        
        Map<String, Object> businessContactsJSONResponse = (Map<String, Object>) contactJSONResponse.get('BusinessPartners/ContactEmployees');
		String contactName = String.ValueOf(businessContactsJSONResponse.get('Name'));
        String contactFirstName = String.ValueOf(businessContactsJSONResponse.get('FirstName'));
         
         
        //contact. = mapAccounts.get((String) contactJSONResponse.get('CardCode'));
        contact.AccountId = mapAccounts.get(accountExternalID);
        if(contactFirstName != null){
            contact.FirstName = contactFirstName;}
        	contact.LastName = contactName;
        	contact.Phone = String.ValueOf(businessContactsJSONResponse.get('MobilePhone'));
        	contact.Email = String.ValueOf(businessContactsJSONResponse.get('E_mail'));
        	// Crear External ID único incluyendo FirstName si existe
        	String uniqueId = accountExternalID + '-' + contactName;
        	if (contactFirstName != null && !contactFirstName.equals('null')) {
            	uniqueId += '-' + contactFirstName;
        	}
        	contact.ID_Externo_Contactos__c = uniqueId;
        

        contactsToUpdate.add(contact);
        System.debug('✅ Contact agregado a la lista - External ID: ' + contact.ID_Externo_Contactos__c);
        
        } catch (Exception e) {
            System.debug('❌ ERROR en setDataContact: ' + e.getMessage());
            System.debug('❌ Stack trace setDataContact: ' + e.getStackTraceString());
            System.debug('❌ Línea del error: ' + e.getLineNumber());
            throw e; // Re-throw para que sea capturado en el nivel superior
        }
    }

   
   
}