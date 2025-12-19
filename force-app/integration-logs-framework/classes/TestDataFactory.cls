@IsTest
public class TestDataFactory {

    public static User createStandardUser(String email) {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        // Ensure username is unique across Salesforce orgs by appending a timestamp suffix.
        String uniqueSuffix = String.valueOf(Datetime.now().getTime());
        // Usernames must be in an email format; append suffix before the @ if present, else append.
        String username;
        if (email.contains('@')) {
            Integer atPos = email.indexOf('@');
            username = email.substring(0, atPos) + '+' + uniqueSuffix + email.substring(atPos);
        } else {
            username = email + '+' + uniqueSuffix + '@example.com';
        }

        String aliasBase = 'tUser';
        // Alias must be 8 characters or fewer
        String alias = (aliasBase + uniqueSuffix).substring(0, Math.min(8, aliasBase.length() + uniqueSuffix.length()));

        User testUser = new User(
            Email = email,
            Username = username,
            LastName = 'Test',
            FirstName = 'User',
            Alias = alias,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id
        );
        
        insert testUser;
        return testUser;
    }

    public static void assignPermissionSet(Id userId, String permissionSetName) {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName LIMIT 1];
        
        insert new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetId = ps.Id
        );
    }

    public static Integration_Log__c createIntegrationLog(
        String context,
        String normalizedContext,
        String message,
        String payloadId,
        Boolean processed
    ) {
        return new Integration_Log__c(
            Context__c = context,
            Normalized_Context__c = normalizedContext,
            Message__c = message,
            PayloadId__c = payloadId,
            Processed__c = processed
        );
    }

    public static List<Integration_Log__c> createIntegrationLogs(Integer count) {
        List<Integration_Log__c> logs = new List<Integration_Log__c>();
        
        for (Integer i = 0; i < count; i++) {
            logs.add(createIntegrationLog(
                'Context_' + i,
                'Normalized_' + i,
                'Message_' + i,
                'PAYLOAD_' + i,
                Math.mod(i, 2) == 0
            ));
        }
        
        return logs;
    }
}
