@IsTest
public class TestDataFactory {
    
    public static User createStandardUser(String email) {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' OR Name='Usuario estándar' LIMIT 1];
        User testUser = new User(
            Alias = 'stnd', 
            Email = email, 
            EmailEncodingKey = 'UTF-8', 
            LastName = 'Test', 
            LanguageLocaleKey = 'en_US', 
            LocaleSidKey = 'en_US', 
            ProfileId = p.Id, 
            TimeZoneSidKey = 'America/Los_Angeles', 
            UserName = email
        );
        insert testUser;
        return testUser;
    }

    public static void assignPermissionSet(Id userId, String permissionSetName) {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id);
    }
}
