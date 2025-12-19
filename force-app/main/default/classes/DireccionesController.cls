/**
 * @description Controller responsible for mapping and upserting/inserting Addresses from an external system (SAP B1).
 */
public without sharing class DireccionesController {

    /**
     * @description Result object for processAddressList operation
     */
    public class ProcessResult {
        public Integer addressesProcessed;
        public Integer addressesUpserted;
        public Integer addressesSkipped;
        public List<AddressError> addressErrors;
        public List<String> skippedAddressDetails;
        
        public ProcessResult() {
            this.addressesProcessed = 0;
            this.addressesUpserted = 0;
            this.addressesSkipped = 0;
            this.addressErrors = new List<AddressError>();
            this.skippedAddressDetails = new List<String>();
        }
    }
    
    public class AddressError {
        public String addressId;
        public String message;
        
        public AddressError(String addressId, String message) {
            this.addressId = addressId;
            this.message = message;
        }
    }

    /**
     * @description Processes a list of deserialized addresses and performs upsert of Direcciones__c.
     * @param addressNodes List of maps with the SAP B1 payload structure (BusinessPartners/BPAddresses).
     * @return ProcessResult with metrics and errors.
     */
    public static ProcessResult processAddressList(List<Map<String, Object>> addressNodes) {
        ProcessResult result = new ProcessResult();
        
        if (addressNodes == null || addressNodes.isEmpty()) {
            return result;
        }
        
        if (!Schema.sObjectType.Direcciones__c.isAccessible()) {
            result.addressErrors.add(new AddressError(null, 'No access to Direcciones__c object'));
            return result;
        }
        
        Set<String> cardCodes = new Set<String>();
        for (Map<String, Object> node : addressNodes) {
            Map<String, Object> bp = (Map<String, Object>) node.get('BusinessPartners');
            if (bp != null) {
                String cardCode = String.valueOf(bp.get('CardCode'));
                if (!String.isBlank(cardCode) && cardCode != 'null') {
                    cardCodes.add(cardCode);
                }
            }
        }
        
        Map<String, Id> accountMap = buildAccountMap(cardCodes);
        
        List<Direcciones__c> pending = new List<Direcciones__c>();
        Set<String> processedExtIds = new Set<String>();
        
        for (Map<String, Object> node : addressNodes) {
            result.addressesProcessed++;
            
            Direcciones__c addr = buildRecord(node, accountMap);
            if (addr != null) {
                String extId = addr.ID_Externo_Direcciones__c;
                if (extId != null && !processedExtIds.contains(extId)) {
                    pending.add(addr);
                    processedExtIds.add(extId);
                }
            } else {
                Map<String, Object> bpAddresses = (Map<String, Object>) node.get('BusinessPartners/BPAddresses');
                String addressName = bpAddresses != null ? String.valueOf(bpAddresses.get('AddressName')) : 'Unknown';
                result.skippedAddressDetails.add('AddressName: ' + addressName + ' - Missing or invalid data');
                result.addressesSkipped++;
            }
        }
        
        if (pending.isEmpty()) {
            return result;
        }
        
        Database.UpsertResult[] upsertResults = Database.upsert(
            pending,
            Direcciones__c.Fields.ID_Externo_Direcciones__c,
            false
        );
        
        Integer upsertedCount = 0;
        List<String> upsertErrors = new List<String>();
        
        for (Integer i = 0; i < upsertResults.size(); i++) {
            Database.UpsertResult ur = upsertResults[i];
            if (ur.isSuccess()) {
                upsertedCount++;
            } else {
                String extId = pending[i].ID_Externo_Direcciones__c;
                String errorMsg = 'AddressId: ' + extId + ' - ' + ur.getErrors()[0].getMessage();
                upsertErrors.add(errorMsg);
                result.addressErrors.add(new AddressError(extId, errorMsg));
            }
        }
        
        result.addressesUpserted = upsertedCount;
        
        return result;
    }

    /**
     * @description Builds a Direcciones__c record from the API node data.
     * @param node Root node containing BusinessPartners and BusinessPartners/BPAddresses data.
     * @param accountMap Map of CardCode to Account Ids for lookups.
     * @return Direcciones__c record ready for upsert or null if skipped.
     */
    private static Direcciones__c buildRecord(Map<String, Object> node, Map<String, Id> accountMap) {
        if (node == null) {
            return null;
        }
        
        Map<String, Object> bp = (Map<String, Object>) node.get('BusinessPartners');
        Map<String, Object> bpAddresses = (Map<String, Object>) node.get('BusinessPartners/BPAddresses');
        
        if (bp == null || bpAddresses == null) {
            return null;
        }
        
        String cardCode = String.valueOf(bp.get('CardCode'));
        String addressName = String.valueOf(bpAddresses.get('AddressName'));
        String addressType = String.valueOf(bpAddresses.get('AddressType'));
        
        if (String.isBlank(cardCode) || cardCode == 'null' || String.isBlank(addressName) || addressName == 'null') {
            return null;
        }
        
        Id accountId = accountMap.get(cardCode);
        if (accountId == null) {
            return null;
        }
        
        Direcciones__c dir = new Direcciones__c();
        dir.ID_Externo_Direcciones__c = cardCode + '-' + addressName + '-' + (String.isBlank(addressType) ? 'B' : addressType);
        dir.Name = addressName;
        dir.Account__c = accountId;
        dir.Street__c = String.valueOf(bpAddresses.get('Street'));
        dir.City__c = String.valueOf(bpAddresses.get('City'));
        dir.County__c = String.valueOf(bpAddresses.get('County'));
        
        Map<String, String> addressTypeMapping = new Map<String, String>{
            'B' => 'Despacho',
            'S' => 'Entrega'
        };
        dir.Seleccionar__c = addressTypeMapping.get(addressType);
        
        return dir;
    }

    /**
     * @description Builds a map of CardCode to Account Id for efficient lookups.
     * @param cardCodes Set of CardCode values from the API response.
     * @return Map of CardCode to Account Ids.
     */
    private static Map<String, Id> buildAccountMap(Set<String> cardCodes) {
        Map<String, Id> accountMap = new Map<String, Id>();
        
        if (cardCodes.isEmpty()) {
            return accountMap;
        }
        
        if (!Schema.sObjectType.Account.isAccessible()) {
            return accountMap;
        }
        
        List<Account> accounts = [
            SELECT Id, Clientes_ID__c 
            FROM Account 
            WHERE Clientes_ID__c IN :cardCodes
            WITH SECURITY_ENFORCED
        ];
        
        for (Account acc : accounts) {
            accountMap.put(acc.Clientes_ID__c, acc.Id);
        }
        
        return accountMap;
    }
}
