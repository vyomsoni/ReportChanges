public with sharing class WhatsAppIntegration {

    public static String currentTime = System.now().format('yyyy-MM-dd HH:mm:ss');

	@AuraEnabled
    public static Boolean sendMessageWithText(String toPhone, String messageText, String contactId,String Message,String timeOfMessage,String fileData) {
        try {
            String formattedMessage = messageText.replaceAll('"','\'');
            String messageBody = '{'+
            '    "messaging_product": "whatsapp",'+
            '    "recipient_type": "individual",'+
            '    "to": "'+toPhone+'",'+
            '    "type": "text",'+
            '    "text": {'+
            '        "body": "'+formattedMessage+'"'+
            '    }'+
            '}';
            sendWhatsAppMessage(toPhone, messageBody,contactId, formattedMessage,timeOfMessage,fileData);
            return true;
        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsAppIntegration', 'sendMessageWithText',currentTime);
            System.debug('Error in sendMessageWithText: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return false;
        }
    }

    @AuraEnabled
    public static String createContentDistribution(String contentDocumentId, String contactId) {
        try {
            List<ContentVersion> contentVersions = [SELECT Id, Title, VersionData, ContentDocumentId FROM ContentVersion WHERE ContentDocumentId = :contentDocumentId WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 1];
            
            if (contentVersions.isEmpty()) {
                throw new AuraHandledException('No ContentVersion found for the given ContentDocumentId.');
            }

            List<ContentDocumentLink> existingLinks;
            if(ContentDocumentLink.SObjectType.getDescribe().isAccessible() && Schema.SObjectType.ContentDocumentLink.fields.Id.isAccessible() 
                  && Schema.SObjectType.ContentDocumentLink.fields.ContentDocumentId.isAccessible() && Schema.SObjectType.ContentDocumentLink.fields.LinkedEntityId.isAccessible()) {
                existingLinks = [SELECT Id FROM ContentDocumentLink WHERE ContentDocumentId = :contentDocumentId AND LinkedEntityId = :contactId LIMIT 1];
            }

            if (existingLinks.isEmpty()) {
                // Create a new ContentDocumentLink if not exists
                ContentDocumentLink newLink = new ContentDocumentLink(
                    ContentDocumentId = contentDocumentId,
                    LinkedEntityId = contactId,
                    ShareType = 'V', 
                    Visibility = 'AllUsers' 
                );
                if(ContentDocumentLink.sObjectType.getDescribe().isCreateable()){
                    insert newLink;
                }
            }

            ContentVersion contentVersion = contentVersions[0];

            // Create ContentDistribution record
            ContentDistribution contentDistribution = new ContentDistribution(
                Name = 'Public Link',
                ContentVersionId = contentVersion.Id,
                PreferencesAllowOriginalDownload = true,
                PreferencesAllowPDFDownload = true,
                PreferencesAllowViewInBrowser = true,
                PreferencesNotifyOnVisit = false
            );
            if (Schema.sObjectType.ContentDistribution.isCreateable() && 
                Schema.sObjectType.ContentDistribution.fields.Name.isCreateable() &&
                Schema.sObjectType.ContentDistribution.fields.ContentVersionId.isCreateable() &&
                Schema.sObjectType.ContentDistribution.fields.PreferencesAllowOriginalDownload.isCreateable() &&
                Schema.sObjectType.ContentDistribution.fields.PreferencesAllowPDFDownload.isCreateable() &&
                Schema.sObjectType.ContentDistribution.fields.PreferencesAllowViewInBrowser.isCreateable() &&
                Schema.sObjectType.ContentDistribution.fields.PreferencesNotifyOnVisit.isCreateable()) {
                
                System.debug('User does not have permission to create ContentDistribution or required fields.');
                insert contentDistribution;
            }else{
                System.debug('User does not have permission to create ContentDistribution or required fields.');
            }
            ContentDistribution createdContentDistribution = [SELECT Id, DistributionPublicUrl,ContentDownloadUrl FROM ContentDistribution WHERE Id = :contentDistribution.Id WITH SECURITY_ENFORCED];
            return createdContentDistribution.ContentDownloadUrl;
        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsAppIntegration', 'createContentDistribution',currentTime);
            System.debug('Error in createContentDistribution: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
    }

    @AuraEnabled
    public static Boolean sendDocumentByUrl(String toPhone, String documentUrl, String contactId, String fileName, String timeOfMessage, String fileData) {
        try {
            String messageBody = '{'+
            '    "messaging_product": "whatsapp",'+
            '    "recipient_type": "individual",'+
            '    "to": "'+toPhone+'",'+
            '    "type": "document",'+
            '    "document": {'+
            '        "link": "'+documentUrl+'",'+
            '        "filename": "' + fileName + '"' +
            '    }'+
            '}';
            sendWhatsAppMessage(toPhone, messageBody, contactId, fileName, timeOfMessage, fileData);
            return true;
        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsAppIntegration', 'sendDocumentByUrl',currentTime);
            System.debug('Error in sendDocumentByUrl: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return false;
        }
    }

    @AuraEnabled
    public static Boolean sendAudioByUrl(String toPhone, String audioUrl, String contactId, String fileName, String timeOfMessage, String fileData) {
        try {
            String messageBody = '{'+
            '    "messaging_product": "whatsapp",'+
            '    "recipient_type": "individual",'+
            '    "to": "'+toPhone+'",'+
            '    "type": "audio",'+
            '    "audio": {'+
            '        "link": "'+audioUrl+'"'+
            '    }'+
            '}';
            sendWhatsAppMessage(toPhone, messageBody, contactId, fileName, timeOfMessage, fileData);
            return true;
        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsAppIntegration', 'sendAudioByUrl',currentTime);
            System.debug('Error in sendAudioByUrl: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return false;
        }
    }

    @AuraEnabled
    public static void sendTemplateMessage(String tempId, String toPhone, String contactId, String timeOfMessage, String fileData,String headerMergeVal,List<String> mergeFieldValues){
        try {
            WhatsApp_Template__c waTemp = [SELECT Id, Name, Contains_Variable_Value__c,Language__c, Category__c, Total_Merge_Fields__c,Body_Merge_Field_Count__c,Type_of_Buttons__c FROM WhatsApp_Template__c WHERE Id = :tempId WITH SECURITY_ENFORCED LIMIT 1];
            Contact con = [Select Id,Name,WhatsApp_Phone__c from Contact where id =: contactId WITH SECURITY_ENFORCED ];
            String messageBody;

            Boolean hasCopyCodeButton = false;

            if (!String.isBlank(waTemp.Type_of_Buttons__c)) {
                List<String> buttonTypes = waTemp.Type_of_Buttons__c.split('\n'); 
    
                for (String buttonType : buttonTypes) {
                    if (buttonType.trim().contains('ButtonType: COPY_CODE')) {
                        hasCopyCodeButton = true;
                    }
                }
            }

            if(waTemp.Category__c == 'Authentication'){
                String otpVal = generateOTP();
                 messageBody = '{ "messaging_product": "whatsapp", "to": "' + con.WhatsApp_Phone__c + '", "type": "template", "template": { "name": "' + waTemp.Name + '", "language": { "code": "' + waTemp.Language__c + '" }, "components": [ ' +
                '{ "type": "body", "parameters": [{ "type": "text", "text": "' + otpVal + '" }] }, ' + 
                '{ "type": "button", "sub_type": "url", "index": 0, "parameters": [' +
                '{ "type": "text", "text": "' + otpVal + '" } ' + 
                '] } ] } }';
            }else{
                List<String> headerParameters = new List<String>();
                List<String> bodyParameters = new List<String>();
                if (waTemp.Total_Merge_Fields__c > 0 && !String.isBlank(headerMergeVal)) {
                    headerParameters.add('{ "type": "text", "text": "' + headerMergeVal + '" }');
                }
                if (mergeFieldValues != null && mergeFieldValues.size() > 0) {
                    for (Integer i = 0; i < mergeFieldValues.size(); i++) {
                        String bodyValue = mergeFieldValues[i];
                        if (!String.isBlank(bodyValue)) {
                            bodyParameters.add('{ "type": "text", "text": "' + bodyValue + '" }');
                        }
                    }
                }
                messageBody = '{ "messaging_product": "whatsapp", "to": "' + con.WhatsApp_Phone__c + '", "type": "template", "template": { "name": "' + waTemp.Name + '", "language": { "code": "' + waTemp.Language__c + '" }, "components": [ ';
                if (headerParameters.size() > 0) {
                    String headerParamsJson = '[' + String.join(headerParameters, ',') + ']';
                    messageBody += '{"type": "header", "parameters": ' + headerParamsJson + ' }';
                }
                if (bodyParameters.size() > 0) {
                    if (headerParameters.size() > 0) {
                        messageBody += ', '; 
                    }
                    String bodyParamsJson = '[' + String.join(bodyParameters, ',') + ']';
                    messageBody += '{"type": "body", "parameters": ' + bodyParamsJson + ' }';
                }
                if (hasCopyCodeButton) {
                    String couponCode = generateCouponCode(); 
                    messageBody += '{ "type": "button", "sub_type": "COPY_CODE", "index": 0, "parameters": [{ "type": "coupon_code", "coupon_code": "' + couponCode + '" }] }';
                }
                messageBody += '] } }';
            }
            WhatsappIntegration.sendWhatsAppMessage(toPhone, messageBody, contactId, waTemp.Name, timeOfMessage , fileData);
        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsAppIntegration', 'snedTemplateMessage',currentTime);
            System.debug('Error in snedTemplateMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }

    public static String generateOTP() {
        Integer otp = (Integer) (Math.random() * 900000) + 100000;
        return String.valueOf(otp);
    }

    public static String generateCouponCode() {
        List<Integer> possibleLengths = new List<Integer>{5, 8,10, 12, 15};
        Integer randomLength = possibleLengths[(Integer)(Math.floor(Math.random() * possibleLengths.size()))];       
        String characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        String couponCode = '';
        for (Integer i = 0; i < randomLength; i++) {
            Integer randomIndex = (Integer)(Math.floor(Math.random() * characters.length()));
            couponCode += characters.substring(randomIndex, randomIndex + 1); 
        }
        return couponCode; 
    }
    
    public static void sendWhatsAppMessage(String toPhone, String messageBody,String contactId,String messageText, String timeOfMessage, String fileData) {
        String isTestApp = System.Label.Whatsapp_test_app_toggle;
        String accessToken = '';
        String endpoint = '';
        if(isTestApp == 'true'){
            accessToken = System.Label.Test_WA_Accesstoken;
            endpoint = System.Label.Test_WA_endpoint;  
        } else if(isTestApp == 'false'){
            accessToken = System.Label.access_token_for_whatsapp;
            endpoint = System.Label.whatsapp_endpoint;  
        }
        if((accessToken != '') && (endpoint != '')){
            System.debug('Body ::' + messageBody);
            // Parse the JSON string
            Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(messageBody);
            String messagetypeValue = (String) parsedJson.get('type');
            System.debug('Type: ' + messagetypeValue);
            String templateName = '';
            Id templateId = null;
            if(messagetypeValue == 'template'){
                Map<String, Object> retrievedTemplateMap = (Map<String, Object>) parsedJson.get('template');
                templateName = (String) retrievedTemplateMap.get('name');
                System.debug(templateName);
                	WhatsApp_Template__c templateRecord = [SELECT Id FROM WhatsApp_Template__c WHERE Name = :templateName WITH SECURITY_ENFORCED LIMIT 1];
                if (templateRecord != null) {
                    templateId = templateRecord.Id;
                }
            }
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setHeader('Authorization', 'Bearer '+ accessToken);
            httpReq.setBody(messageBody);
            DateTime myDateTime = DateTime.now();
            String formattedDate = myDateTime.format(' d MMM yyyy');
            Http http = new Http();
            try {
                HttpResponse response = http.send(httpReq);
                Integer statusCode = response.getStatusCode();                
                if(response != null && statusCode == 200){
                    String reponseBody = response.getBody();
                    Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(reponseBody);
                    List<Object> messages = (List<Object>) jsonMap.get('messages');
                    Map<String, Object> firstMessage = (Map<String, Object>) messages[0];
                    String whatsAppMessageID = (String) firstMessage.get('id');

                    WhatsApp_Chat__c whatsappMsg = new WhatsApp_Chat__c(
                        Message_Type__c = 'Outbound-Message',
                        Message__c = messageText,
                        Time_of_Message__c = timeOfMessage, 
                        Type_of_Message__c = messagetypeValue,
                        WhatsAppMessageID__c = whatsAppMessageID,
                        ContactId__c = contactId,
                        Related_Record_Id__c = contactId,
                        Date_of_WpMessage__c = formattedDate,
                        File_Data__c = fileData 
                    );
                    
                    if(templateName != '' && messagetypeValue == 'template'){
                        whatsappMsg.Template__c = templateId;
                    }
                    if(WhatsApp_Chat__c.sObjectType.getDescribe().isCreateable() && 
                        Schema.sObjectType.WhatsApp_Chat__c.fields.Message_Type__c.isCreateable() &&
                        Schema.sObjectType.WhatsApp_Chat__c.fields.Message__c.isCreateable() &&
                        Schema.sObjectType.WhatsApp_Chat__c.fields.Time_of_Message__c.isCreateable() &&
                        Schema.sObjectType.WhatsApp_Chat__c.fields.Type_of_Message__c.isCreateable() &&
                        Schema.sObjectType.WhatsApp_Chat__c.fields.WhatsAppMessageID__c.isCreateable() &&
                        Schema.sObjectType.WhatsApp_Chat__c.fields.ContactId__c.isCreateable() &&
                        Schema.sObjectType.WhatsApp_Chat__c.fields.Related_Record_Id__c.isCreateable() &&
                        Schema.sObjectType.WhatsApp_Chat__c.fields.Date_of_WpMessage__c.isCreateable() &&
                        Schema.sObjectType.WhatsApp_Chat__c.fields.File_Data__c.isCreateable()){
                        insert whatsappMsg;
                    }else{
                        System.debug('User does not have permission to set one or more required fields on WhatsApp_Chat__c.');
                    }
                    System.debug('whatsappMsg ==> ' + whatsappMsg);
                }else{
                    System.debug('Error in sending the message.');
                    // Contact contact = [SELECT Id, Name, OwnerId FROM Contact WHERE Id = :contactId LIMIT 1];
                    // sendNotificationForContact(contact);
                }
            } catch (Exception e) {
                // ExceptionLog.exception(e.getMessage(), 'WhatsAppIntegration', 'sendWhatsAppMessage',currentTime);
                System.debug('Error in sendWhatsAppMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            }
        } else{
            System.debug('Failed fetched access token and endpoint from custom labels');
        }
    }

    public static void sendNotificationForContact(Contact con) {
        try {
            CustomNotificationType cnType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'WhatsappNotification' WITH SECURITY_ENFORCED];
            
            // Id userId = Userinfo.getUserId();
            String messageContent = 'Message has not been sent to '+ con.Name;
            System.debug('messageContent==> '+messageContent);
            // Prepare the custom notification object
            Set<String> addressee = new Set<String>();
            addressee.add(con.OwnerId);
            Messaging.CustomNotification customNotificationObj = new Messaging.CustomNotification();
            customNotificationObj.setBody(messageContent); 
            customNotificationObj.setTitle('Sending message failed.'); 
            customNotificationObj.setNotificationTypeId(cnType.Id); 
            // customNotificationObj.setSenderId(userId); 
            customNotificationObj.setTargetId(con.Id); 
            customNotificationObj.send(addressee);

        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsAppIntegration', 'sendNotificationForContact',currentTime);
            System.debug('Error in sendNotificationForContact: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }
}