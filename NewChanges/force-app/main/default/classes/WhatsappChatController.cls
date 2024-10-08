public with sharing class WhatsappChatController {

    public static String currentTime = System.now().format('yyyy-MM-dd HH:mm:ss');

    @AuraEnabled(cacheable=true)
    public static String getNameId(String name, String objectname) {
        try {
            Id recordId;
            if(objectname == 'Contact'){
                Contact con = [SELECT Id FROM Contact WHERE Name = :name WITH SECURITY_ENFORCED LIMIT 1];
                if (con != null) {
                    recordId = con.Id;
                }
            }
            return recordId != null ? String.valueOf(recordId) : null;
        }  catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsappChatController', 'getNameId',currentTime);
            System.debug('Error in getNameId: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Contact getContactDetails(Id contactId) {
        try {
            Contact contact = [SELECT Id, WhatsApp_Phone__c, User_Consent_Received__c FROM Contact WHERE Id = :contactId WITH SECURITY_ENFORCED LIMIT 1];
            return contact;
        }catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsappChatController', 'getContactDetails',currentTime);
            System.debug('Error in getContactDetails: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }      
    }

    @AuraEnabled(cacheable=true)
    public static WhatsApp_Template__c getTemplateRecords(Id templateId){
        try {
            WhatsApp_Template__c wt= [SELECT Id, Template_Header__c,Template_Footer__c, Body__c, Template_Id__c, Contains_Variable_Value__c, Total_Merge_Fields__c,Body_Merge_Field_Count__c,Header_Merge_Field_Count__c  FROM WhatsApp_Template__c WHERE Id = : templateId WITH SECURITY_ENFORCED LIMIT 1];
            System.debug('wt===> '+wt);
            return wt;
        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsappChatController', 'getTemplateRecords',currentTime);
            System.debug('Error in getContactPhone: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
    }
   
    
    public static List<ContentDocument> getFiles(String recordId) {
        try {
            List<ContentDocumentLink> documentLinks = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId WITH SECURITY_ENFORCED];
            Set<Id> documentIds = new Set<Id>();
            for (ContentDocumentLink link : documentLinks) {
                documentIds.add(link.ContentDocumentId);
            }
            return [SELECT Id, Title FROM ContentDocument WHERE Id IN :documentIds];
        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsappChatController', 'getContactPhone',currentTime);
            System.debug('Error in getContactPhone: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }       
    }

    @AuraEnabled
    public static Map<String, List<MessageWrapper>> getWhatsAppMessages(String objectName, Id id) {
        try {
            List<WhatsApp_Chat__c> records = new List<WhatsApp_Chat__c>();
    
            if(objectName == 'Contact'|| objectName == 'Account'){
                records = [SELECT Message_Type__c, Status__c, File_Data__c, Type_of_Message__c, Message__c, Time_of_Message__c, Date_of_WpMessage__c, CreatedDate,Related_Record_Id__c, Template__c,Template__r.Id,Template__r.Template_Header__c, Template__r.Body__c,Template__r.Template_Footer__c, Message_Sent__c, Message_Delivered__c,Message_Failed__c, Message_Seen__c
                            FROM WhatsApp_Chat__c WHERE Related_Record_Id__c = :id WITH SECURITY_ENFORCED ORDER BY CreatedDate ASC, Time_of_Message__c ASC];
                System.debug('Query records ==> '+records);
            }
        
            Map<String, List<MessageWrapper>> messageMap = new Map<String, List<MessageWrapper>>();
            List<Id> contentVersionIds = new List<Id>();
    
            for (WhatsApp_Chat__c msg : records) {
                System.debug('msg ==> ' + msg);
                MessageWrapper mw = new MessageWrapper();
                mw.messageType = msg.Message_Type__c;
                mw.message = msg.Message__c;
                mw.timeOfMessage = String.valueOf(msg.Time_of_Message__c);
                mw.typeOfMessage = msg.Type_of_Message__c;
                mw.fileData = msg.File_Data__c;

                if(msg.Type_of_Message__c == 'template' || msg.Type_of_Message__c=='Broadcast'){
                    WhatsApp_Template__c temp = [SELECT Id, Template_Header__c,Template_Footer__c,Body__c FROM WhatsApp_Template__c WHERE id = :msg.Template__c WITH SECURITY_ENFORCED];
                    mw.templateHeader = temp.Template_Header__c;
                    mw.templateBody = temp.Body__c;
                    mw.templateFooter = temp.Template_Footer__c;
                }

                if(msg.Message_Sent__c == true){
                    mw.msgSent = 'true';
                    mw.msgDelivered = 'false';
                    mw.msgRead = 'false';
                    mw.msgFailed='false';
                } else{
                    mw.msgLoadTick = 'true';
                    mw.msgSent = 'false';
                    mw.msgDelivered = 'false';
                    mw.msgRead = 'false';
                    mw.msgFailed='false';
                }

                if(msg.Message_Delivered__c == true){
                    mw.msgLoadTick = 'false';
                    mw.msgSent = 'false';
                    mw.msgDelivered = 'true';
                    mw.msgRead = 'false';
                    mw.msgFailed='false';
                }

                if(msg.Message_Seen__c == true){
                    mw.msgLoadTick = 'false';
                    mw.msgSent = 'false';
                    mw.msgDelivered = 'false';
                    mw.msgRead = 'true';
                    mw.msgFailed='false';
                }
                if(msg.Message_Failed__c == true){
                    mw.msgLoadTick = 'false';
                    mw.msgSent = 'false';
                    mw.msgDelivered = 'false';
                    mw.msgRead = 'false';
                    mw.msgFailed='true';
                }
                
                if (msg.File_Data__c != null) {
                    Map<String, Object> fileDataMap = (Map<String, Object>) JSON.deserializeUntyped(msg.File_Data__c);
                    if (fileDataMap.containsKey('contentVersionId')) {
                        contentVersionIds.add((Id) fileDataMap.get('contentVersionId'));
                    }
                }
    
                String dateKey = String.valueOf(msg.Date_of_WpMessage__c);
                if (!messageMap.containsKey(dateKey)) {
                    messageMap.put(dateKey, new List<MessageWrapper>{mw});
                } else {
                    messageMap.get(dateKey).add(mw);
                }
            }
    
            Map<Id, ContentVersion> contentVersionMap = new Map<Id, ContentVersion>(
                [SELECT Id, Title, VersionData, FileExtension, FileType, ContentDocumentId
                 FROM ContentVersion
                 WHERE Id IN :contentVersionIds WITH SECURITY_ENFORCED]
            );
    
            // Attach files to messages
            for (String dateKey : messageMap.keySet()) {
                for (MessageWrapper mw : messageMap.get(dateKey)) {
                    if (mw.fileData != null) {
                        Map<String, Object> fileDataMap = (Map<String, Object>) JSON.deserializeUntyped(mw.fileData);
                        if (fileDataMap.containsKey('contentVersionId')) {
                            Id contentVersionId = (Id) fileDataMap.get('contentVersionId');
                            if (contentVersionMap.containsKey(contentVersionId)) {
                                mw.file = contentVersionMap.get(contentVersionId);
                            }
                        }
                    }
                }
            }
            System.debug(messageMap);
            return messageMap;
        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsappChatController', 'getWhatsAppMessages',currentTime);
            System.debug('Error in getWhatsAppMessages: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }  
    }

    public class MessageWrapper {
        @AuraEnabled public String messageType;
        @AuraEnabled public String message;
        @AuraEnabled public String timeOfMessage;
        @AuraEnabled public String typeOfMessage;
        @AuraEnabled public String fileData;
        @AuraEnabled public String templateName;
        @AuraEnabled public String templateIdVal;
        @AuraEnabled public String templateHeader;
        @AuraEnabled public String templateBody;
        @AuraEnabled public String templateFooter;
        @AuraEnabled public String msgLoadTick;
        @AuraEnabled public String msgSent;
        @AuraEnabled public String msgDelivered;
        @AuraEnabled public String msgRead;
        @AuraEnabled public String msgFailed;
        @AuraEnabled public ContentVersion file;
    }
}