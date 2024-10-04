public with sharing class SupportEmailService implements Messaging.InboundEmailHandler {
    public Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        String emailBody = email.plainTextBody;
        ParsedEmailWrapper parsedEmail = parseEmail(emailBody);

        if (!Schema.sObjectType.MVEX__Support_Case__c.isCreateable()) {
            System.debug('User does not have permission to create Support Cases.');
            return result; 
        }
        
        if (!Schema.sObjectType.MVEX__Support_Case__c.fields.MVEX__Description__c.isUpdateable() ||
            !Schema.sObjectType.MVEX__Support_Case__c.fields.MVEX__Name__c.isCreateable() ||
            !Schema.sObjectType.MVEX__Support_Case__c.fields.MVEX__Email__c.isCreateable()) {
            System.debug('User does not have permission to set required fields on Support Cases.');
            return result; 
        }

        MVEX__Support_Case__c supportCase = new MVEX__Support_Case__c();
        supportCase.MVEX__Name__c = parsedEmail.fromName; 
        supportCase.MVEX__Email__c = parsedEmail.emailAddress; 
        supportCase.MVEX__Subject__c = email.subject; 
        supportCase.MVEX__Description__c = parsedEmail.body;

        try {
            insert supportCase;
        } catch (DmlException e) {
            System.debug('Error inserting Support Case: ' + e.getMessage());
            return result; 
        }

        List<ContentVersion> contentVersions = new List<ContentVersion>();
        List<ContentDocumentLink> contentLinks = new List<ContentDocumentLink>();

        if (email.binaryAttachments != null && email.binaryAttachments.size() > 0) {
            if (!Schema.sObjectType.ContentVersion.isCreateable()) {
                System.debug('User does not have permission to create Content Versions.');
                return result; 
            }

            for (Messaging.InboundEmail.BinaryAttachment attachment : email.binaryAttachments) {
                ContentVersion contentVersion = new ContentVersion();
                contentVersion.Title = attachment.fileName;
                contentVersion.PathOnClient = attachment.fileName;
                contentVersion.VersionData = attachment.body;
                contentVersion.IsMajorVersion = true;
                contentVersions.add(contentVersion); // Collecting content versions
            }

            if (!contentVersions.isEmpty()) {
                try {
                    insert contentVersions;
                } catch (DmlException e) {
                    System.debug('Error inserting Content Versions: ' + e.getMessage());
                    return result; 
                }
            }

            for (ContentVersion contentVersion : contentVersions) {

                if (!Schema.sObjectType.ContentDocumentLink.isCreateable()) {
                    System.debug('User does not have permission to create Content Document Links.');
                    return result; 
                }

                ContentDocumentLink contentLink = new ContentDocumentLink();
                contentLink.ContentDocumentId = contentVersion.ContentDocumentId;
                contentLink.LinkedEntityId = supportCase.Id;
                contentLink.ShareType = 'V';
                contentLink.Visibility = 'AllUsers';
                contentLinks.add(contentLink);
            }

            if (!contentLinks.isEmpty()) {
                try {
                    insert contentLinks;
                } catch (DmlException e) {
                    System.debug('Error inserting Content Document Links: ' + e.getMessage());
                }
            }
        }

        result.success = true;
        return result;
    }

    public class ParsedEmailWrapper {
        public String body { get; set; }
        public String fromName { get; set; }
        public String emailAddress { get; set; }
    }

    public static ParsedEmailWrapper parseEmail(String emailContent) {
        ParsedEmailWrapper emailWrapper = new ParsedEmailWrapper();
        String[] lines = emailContent.split('\n');
        for (String line : lines) {
            line = line.trim();
            if (line.startsWith('From :')) {
                emailWrapper.fromName = line.substringAfter('From :').trim();
            }
            else if (line.startsWith('Email :')) {
                emailWrapper.emailAddress = line.substringAfter('Email :').trim();
            }
            else {
                if (emailWrapper.body == null) {
                    emailWrapper.body = line;
                } else {
                    emailWrapper.body += '\n' + line;
                }
            }
        }
        return emailWrapper;
    }
}
