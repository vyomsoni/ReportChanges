/**
* @File Name : WebhookCDLCreation.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : September 26, 2024
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | September 26, 2024 |   | Initial Version
**/
public with sharing class WebhookCDLCreation implements Messaging.InboundEmailHandler {
    public Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult(); // Fix the casing here
        String emailBody = email.plainTextBody;
        System.debug('emailBody: ' + emailBody);
        
        // Deserialize the JSON string into a Map
        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(emailBody);
        System.debug(jsonMap);

        // Validate CRUD permissions for ContentDocumentLink
        if (!Schema.sObjectType.ContentDocumentLink.isCreateable()) {
            System.debug('User does not have permission to create Content Document Links.');
            return result; // Return early if permission is denied
        }

        // Create a new ContentDocumentLink instance
        ContentDocumentLink contentDocumentLink = new ContentDocumentLink(
            ContentDocumentId = jsonMap.get('contentDocumentId').toString(),
            LinkedEntityId = jsonMap.get('linkedEntityId').toString(),
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        // Use try-catch to handle potential DML exceptions
        try {
            insert contentDocumentLink;
        } catch (DmlException e) {
            System.debug('Error inserting Content Document Link: ' + e.getMessage());
            // Handle the error as appropriate, e.g., logging or notifying the user
        }

        return result; // Return the result
    }
}
