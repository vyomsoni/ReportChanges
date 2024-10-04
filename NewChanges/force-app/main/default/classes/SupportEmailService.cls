public class SupportEmailService implements Messaging.InboundEmailHandler {
    public Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
    
        // Step 1: Extract Name and Email from the email body
        String emailBody = email.plainTextBody;
    
        ParsedEmailWrapper parsedEmail = parseEmail(emailBody);
    
        // Step 2: Create a new Support Case record with the extracted values
        MVEX__Support_Case__c supportCase = new MVEX__Support_Case__c();
        supportCase.MVEX__Name__c = parsedEmail.fromName;  // Storing extracted Name
        supportCase.MVEX__Email__c = parsedEmail.emailAddress; // Storing extracted Email
        supportCase.MVEX__Subject__c = email.subject; 
        supportCase.MVEX__Description__c = parsedEmail.body;
        insert supportCase;
    
        // Step 3: Process attachments and store them as Content Files if any exist
        if (email.binaryAttachments != null && email.binaryAttachments.size() > 0) {
            for (Messaging.InboundEmail.BinaryAttachment attachment : email.binaryAttachments) {
                ContentVersion contentVersion = new ContentVersion();
                contentVersion.Title = attachment.fileName;
                contentVersion.PathOnClient = attachment.fileName;
                contentVersion.VersionData = attachment.body;
                contentVersion.IsMajorVersion = true;
                insert contentVersion;
    
                ContentDocumentLink contentLink = new ContentDocumentLink();
                contentLink.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1].ContentDocumentId;
                contentLink.LinkedEntityId = supportCase.Id;
                contentLink.ShareType = 'V';
                contentLink.Visibility = 'AllUsers';
                insert contentLink;
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