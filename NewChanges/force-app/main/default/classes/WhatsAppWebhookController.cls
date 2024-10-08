public with sharing class WhatsAppWebhookController{

    public static String currentTime = System.now().format('yyyy-MM-dd HH:mm:ss');
    public static String phoneNumberId = '';

    public static void processWhatsAppPayload(String jsonString) {
        try {
            List<WhatsAppMessage> parsedMessages = parseMessages(jsonString);
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
            List<Object> listofmessages = (List<Object>) payload.get('entry');
            if (listofmessages != null && !listofmessages.isEmpty()){
            // for (Object messageobj : listofmessages) {
                Object messageobj = listofmessages[0];
                Map<String, Object> messageMap = (Map<String, Object>) messageobj;
                List<Object> changes = (List<Object>) messageMap.get('changes');
                if (changes != null && !changes.isEmpty()) {
                    // for (Object changeObj : changes) {
                        Object changeObj = changes[0];
                        Map<String, Object> changeMap = (Map<String, Object>) changeObj;
                        Map<String, Object> value = (Map<String, Object>) changeMap.get('value');
                        Map<String, Object> metadata = (Map<String, Object>) value.get('metadata');
                        // Extract the phone_number_id
                        phoneNumberId = (String) metadata.get('phone_number_id');
                        List<Object> messages = (List<Object>) value.get('messages');
                        processWhatsAppMessages(messages);
                    // }
                }
            // }
            }
        } 
        catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'WhatsAppWebhook', 'processWhatsAppPayload', e.getMessage());
        }
    }

    public static void processWhatsAppMessages(List<Object> messages) {
        try {
            if (messages != null) {
                for (Object messageObj : messages) {
                    Map<String, Object> message = (Map<String, Object>) messageObj;
                    processSingleMessage(message);
                }
            }
        }  
        catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'WhatsAppWebhook', 'processWhatsAppMessages', e.getMessage());
        }
    }

    public static void processSingleMessage(Map<String, Object> message) {
        String senderId = (String) message.get('from');
        String messageType = (String) message.get('type');
        String whatsAppMessageID = (String) message.get('id');
        Integer timestampValue = Integer.valueOf(message.get('timestamp'));
        DateTime currentUTCDateTime = System.now();
        Timezone tzIST = Timezone.getTimeZone('Asia/Kolkata');
        Integer offsetMillis = tzIST.getOffset(currentUTCDateTime);
        Integer offsetHours = offsetMillis / (1000 * 60 * 60);
        Integer offsetMinutes = Math.abs(offsetMillis / (1000 * 60) - offsetHours * 60);
        DateTime currentISTDateTime = currentUTCDateTime.addHours(offsetHours).addMinutes(offsetMinutes);
        String formattedTime2 = currentISTDateTime.format('h:mm a');

        // Query to check if the message has already been processed
        List<WhatsApp_Chat__c> existingChatRecords = [SELECT Id FROM WhatsApp_Chat__c WHERE WhatsAppMessageID__c = :whatsAppMessageID WITH SECURITY_ENFORCED LIMIT 1 ];
        if (!existingChatRecords.isEmpty()) {
            System.debug('Message already processed: ' + whatsAppMessageID);
            return; 
        }

        if (messageType.equalsIgnoreCase('text')) {
            Map<String, Object> text = (Map<String, Object>) message.get('text');
            Map<String, Object> context = (Map<String, Object>) message.get('context');
            String contextId = '';
            if(context != null){
                contextId = (String) context.get('id');
            }
            String messageBody = (String) text.get('body');
            senderId = '+' + senderId;
            String formattedNumber = senderId.substring(0, 3) + senderId.substring(3);
            
            DateTime myDateTime = DateTime.now();
            String formattedDate = myDateTime.format(' d MMM yyyy');
            Contact contact;
            try {
                List<Contact> contacts = [SELECT Id, Name,WhatsApp_Phone__c,MobilePhone,OwnerId, User_Consent_Received__c FROM Contact WHERE WhatsApp_Phone__c = :formattedNumber WITH SECURITY_ENFORCED  LIMIT 1];
                if (contacts.size() > 0) {
                    contact = contacts[0];
                    List<WhatsApp_Chat__c> chatRecordsWp = [SELECT Id,ContactId__c,WhatsAppMessageID__c FROM WhatsApp_Chat__c WHERE WhatsAppMessageID__c = :whatsAppMessageID WITH SECURITY_ENFORCED  ORDER BY CreatedDate DESC];
                    List<WhatsApp_Chat__c> deletedChatRecordsWp = [SELECT Id,ContactId__c,WhatsAppMessageID__c FROM WhatsApp_Chat__c WHERE WhatsAppMessageID__c = :whatsAppMessageID AND IsDeleted = true WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC ];

                    if(chatRecordsWp.isEmpty() && deletedChatRecordsWp.isEmpty()){
                        WhatsApp_Chat__c whatsappChat = new WhatsApp_Chat__c();

                        whatsappChat.ContactId__c = contact.Id;
                        whatsappChat.Related_Record_Id__c = contact.id;
                        whatsappChat.Message__c = messageBody;
                        whatsappChat.Message_Type__c = 'Inbound-Message';
                        whatsappChat.Type_of_Message__c = messageType;
                        whatsappChat.WhatsAppMessageID__c = whatsAppMessageID;
                        whatsappChat.Time_of_Message__c = formattedTime2;
                        whatsappChat.Date_of_WpMessage__c = formattedDate;
                        if (contextId != null && contextId != '') {
                            whatsappChat.WhatsAppContextMessageID__c = contextId;
                        }
                            
                        ChatMessageEvent__e chatevent = new ChatMessageEvent__e(
                            ContactId__c = contact.Id,
                            Message__c = messageBody,
                            Message_Type__c = 'Inbound-Message',
                            Type_of_Message__c = messageType,
                            WhatsAppMessageID__c = whatsAppMessageID,
                            Time_of_Message__c = formattedTime2,
                            Date_of_WpMessage__c = formattedDate,
                            userConsent__c = true
                        );
                        if (Schema.sObjectType.WhatsApp_Chat__c.fields.ContactId__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.Related_Record_Id__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.Message__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.Message_Type__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.Type_of_Message__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.WhatsAppMessageID__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.Time_of_Message__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.Date_of_WpMessage__c.isCreateable()) {
                            insert whatsappChat;
                        }else{
                            System.debug('User does not have permission to set required fields on WhatsApp_Chat__c.');
                        }
                        // insert whatsappChat;
                        updateContactUserConsent(contact);
                        EventBus.publish(chatevent);
                        sendNotificationForContact(contact);
                    }
                }
                else{
                    System.debug('Unable to get contact to send message.');
                }
            } catch (Exception e) {
                System.debug('Error in processSingleMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            }
        } 
        if (messageType.equalsIgnoreCase('document')) {
            Map<String, Object> document = (Map<String, Object>) message.get('document');
            String mediaId = (String) document.get('id');
            String filename = (String) document.get('filename');
            String mimeType = (String) document.get('mime_type');
        
            try {
                Blob documentBody = handleMediaAttachment(mediaId);         
                if (documentBody != null) {
                    String formattedNumber = '+' + senderId;
                    formattedNumber = formattedNumber.substring(0, 3) + formattedNumber.substring(3);
                    DateTime myDateTime = DateTime.now();
                    String formattedDate = myDateTime.format(' d MMM yyyy');
                    Contact contacts = [SELECT Id, Name, WhatsApp_Phone__c,OwnerId FROM Contact WHERE WhatsApp_Phone__c = :formattedNumber WITH SECURITY_ENFORCED ];
                    saveMediaToSalesforce(documentBody, filename, mimeType,messageType,whatsAppMessageID,formattedTime2,formattedDate,senderId, contacts.Id);
                }
            } catch (Exception e) {
                System.debug('Error in processSingleMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            }         
        } 
        if (messageType.equalsIgnoreCase('image')) {
            Map<String, Object> image = (Map<String, Object>) message.get('image');
            String imageId = (String) image.get('id');
            String filename = (String) image.get('filename');
            String mimeType = (String) image.get('mime_type');

            try {
                Blob imageBody = handleMediaAttachment(imageId);
                String fileExtension = getFileExtension(mimeType);           
                if (imageBody != null) {
                    String formattedNumber = '+' + senderId;
                    formattedNumber = formattedNumber.substring(0, 3) + formattedNumber.substring(3);
                    DateTime myDateTime = DateTime.now();
                    String formattedDate = myDateTime.format(' d MMM yyyy');
                    Contact contacts =[SELECT Id, Name, WhatsApp_Phone__c, OwnerId 
                    FROM Contact 
                    WHERE WhatsApp_Phone__c = :formattedNumber WITH SECURITY_ENFORCED
                    ORDER BY CreatedDate DESC 
                    LIMIT 1];
                    String filedateformat = myDateTime.format('ddMMyyyy_HHmmss');
                    String fileTitle = 'IMG-'+filedateformat+fileExtension;
                    saveMediaToSalesforce(imageBody, fileTitle, mimeType,messageType,whatsAppMessageID,formattedTime2,formattedDate,senderId, contacts.Id);
                }
            }  catch (Exception e) {
                System.debug('Error in processSingleMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            }
        } 
        if (messageType.equalsIgnoreCase('video')) {
            Map<String, Object> video = (Map<String, Object>) message.get('video');
            String videoId = (String) video.get('id');
            String filename = (String) video.get('filename');
            String mimeType = (String) video.get('mime_type');

            try {
                Blob videoBody = handleMediaAttachment(videoId);
                String fileExtension = getFileExtension(mimeType);
            
                if (videoBody != null) {
                    String formattedNumber = '+' + senderId;
                    formattedNumber = formattedNumber.substring(0, 3) + formattedNumber.substring(3);
                    DateTime myDateTime = DateTime.now();
                    String formattedDate = myDateTime.format(' d MMM yyyy');
                    Contact contacts = [SELECT Id, Name, WhatsApp_Phone__c,OwnerId FROM Contact WHERE WhatsApp_Phone__c = :formattedNumber WITH SECURITY_ENFORCED ];
                    String filedateformat = myDateTime.format('ddMMyyyy_HHmmss');
                    String fileTitle = 'Video-'+filedateformat+fileExtension;
                    saveMediaToSalesforce(videoBody, fileTitle, mimeType,messageType,whatsAppMessageID,formattedTime2,formattedDate,senderId, contacts.Id);
                  }
            }  catch (Exception e) {
                System.debug('Error in processSingleMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            }
        }
        if (messageType.equalsIgnoreCase('audio')) {
            Map<String, Object> video = (Map<String, Object>) message.get('audio');
            String audioId = (String) video.get('id');
            String filename = (String) video.get('filename');
            String mimeType = (String) video.get('mime_type');

            try {
                Blob audioBody = handleMediaAttachment(audioId);
                String fileExtension = getFileExtension(mimeType);
            
                if (audioBody != null) {
                    String formattedNumber = '+' + senderId;
                    formattedNumber = formattedNumber.substring(0, 3) + formattedNumber.substring(3);
                    DateTime myDateTime = DateTime.now();
                    String formattedDate = myDateTime.format(' d MMM yyyy');
                    Contact contacts = [SELECT Id, Name, WhatsApp_Phone__c,OwnerId FROM Contact WHERE WhatsApp_Phone__c = :formattedNumber WITH SECURITY_ENFORCED ];
                    String fileDateFormat = myDateTime.format('ddMMyyyy_HHmmss');
                    String fileTitle = 'AUD-'+fileDateFormat+fileExtension;
                    saveMediaToSalesforce(audioBody, fileTitle, mimeType,messageType,whatsAppMessageID,formattedTime2,formattedDate,senderId, contacts.Id);
                }
            } catch (Exception e) {
                System.debug('Error in processSingleMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            }
        }
        if (messageType.equalsIgnoreCase('button')) {
            Map<String, Object> button = (Map<String, Object>) message.get('button');
            String payload = (String) button.get('payload');
            String text = (String) button.get('text');
            Map<String, Object> context = (Map<String, Object>) message.get('context');
            String contextId = '';
            if(context != null){
                contextId = (String) context.get('id');
            }
            senderId = '+' + senderId;
            String formattedNumber = senderId.substring(0, 3) + senderId.substring(3);
            
            DateTime myDateTime = DateTime.now();
            String formattedDate = myDateTime.format(' d MMM yyyy');
            Contact contact;
            try {
                List<Contact> contacts = [SELECT Id, Name,WhatsApp_Phone__c,OwnerId, User_Consent_Received__c FROM Contact WHERE WhatsApp_Phone__c = :formattedNumber WITH SECURITY_ENFORCED  LIMIT 1 ];
                if (contacts.size() > 0) {
                    contact = contacts[0];
                    List<WhatsApp_Chat__c> chatRecordsWp = [SELECT Id,ContactId__c,WhatsAppMessageID__c FROM WhatsApp_Chat__c WHERE WhatsAppMessageID__c = :whatsAppMessageID WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC ];
                    List<WhatsApp_Chat__c> deletedChatRecordsWp = [SELECT Id,ContactId__c,WhatsAppMessageID__c FROM WhatsApp_Chat__c WHERE WhatsAppMessageID__c = :whatsAppMessageID AND IsDeleted = true WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC];

                    if(chatRecordsWp.isEmpty() && deletedChatRecordsWp.isEmpty()){
                        WhatsApp_Chat__c whatsappChat = new WhatsApp_Chat__c();
                        whatsappChat.ContactId__c = contact.Id;
                        whatsappChat.Related_Record_Id__c = contact.id;
                        whatsappChat.Message__c = text;
                        whatsappChat.Message_Type__c = 'Inbound-Message';
                        whatsappChat.Type_of_Message__c = messageType;
                        whatsappChat.WhatsAppMessageID__c = whatsAppMessageID;
                        whatsappChat.Time_of_Message__c = formattedTime2;
                        whatsappChat.Date_of_WpMessage__c = formattedDate;
                        whatsappChat.Phone_Number_Id__c = phoneNumberId;
                        if (contextId != null && contextId != '') {
                            whatsappChat.WhatsAppContextMessageID__c = contextId;
                        }
                        
                        ChatMessageEvent__e chatevent = new ChatMessageEvent__e(
                            ContactId__c = contact.Id,
                            Message__c = text,
                            Message_Type__c = 'Inbound-Message',
                            Type_of_Message__c = messageType,
                            WhatsAppMessageID__c = whatsAppMessageID,
                            Time_of_Message__c = formattedTime2,
                            Date_of_WpMessage__c = formattedDate,
                            userConsent__c = true
                        );
                        if (Schema.sObjectType.WhatsApp_Chat__c.fields.ContactId__c.isCreateable() && 
                            Schema.sObjectType.WhatsApp_Chat__c.fields.Related_Record_Id__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.Message__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.Message_Type__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.Type_of_Message__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.WhatsAppMessageID__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.Time_of_Message__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.Date_of_WpMessage__c.isCreateable() &&
                            Schema.sObjectType.WhatsApp_Chat__c.fields.Phone_Number_Id__c.isCreateable()) {
                            insert whatsappChat;
                        } else {
                            System.debug('User does not have access to create fields on WhatsApp_Chat__c');
                        }
                        updateContactUserConsent(contact);
                        EventBus.publish(chatevent);
                         // Send push notification
                        sendNotificationForContact(contact);
                    }
                }
                else{
                    System.debug('Unable to get contact to send message.');
                }
            } catch (Exception e) {
                ErrorHandler.insert_errordata(e, 'WhatsAppWebhook', 'processSingleMessage', e.getMessage());
            }
        }
        else if (messageType != null) {
            System.debug('Unsupported message type: ' + messageType);
        }
    }

    public static String getFileExtension(String mimeType) {
        if (mimeType.equals('image/jpeg')) {
            return '.jpeg';
        } else if (mimeType.equals('image/png')) {
            return '.png';
        } else if (mimeType.equals('image/jpg')) {
            return '.jpg';
        } else if (mimeType.equals('audio/mp3') || mimeType.equals('audio/mpeg')) {
            return '.mp3';
        } else if (mimeType.equals('audio/ogg; codecs=opus')) {
            return '.ogg';
        } else if (mimeType.equals('video/mp4')) {
            return '.mp4';
        } else if (mimeType.equals('video/3gp')) {
            return '.3gp';
        } else {
            return '.bin'; 
        }
    }

    // @future(callout=true)
    public static Blob handleMediaAttachment(String documentId) {
        String mediaUrl = 'https://graph.facebook.com/v20.0/' + documentId;
        String isTestApp = System.Label.Whatsapp_test_app_toggle;
        String accessToken = '';
        if(isTestApp == 'true'){
            accessToken = System.Label.Test_WA_Accesstoken;
        } else if(isTestApp == 'false'){
            accessToken = System.Label.access_token_for_whatsapp;
        }
        if(accessToken != ''){
            HttpRequest req = new HttpRequest();
            req.setEndpoint(mediaUrl);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken); 
            HttpResponse res;
            
            try {
                Http http = new Http();
                res = http.send(req);
                
                if (res.getStatusCode() == 200) {
                    // Parse the metadata response
                    Map<String, Object> mediaMetadata = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    String downloadUrl = (String) mediaMetadata.get('url'); // Retrieve download URL from metadata
                    system.debug('mediaid url===> '+downloadUrl);
                    
                    // Download the media content
                    return downloadMediaContent(downloadUrl, accessToken);
                } else {
                    System.debug('Failed to retrieve media metadata. Status: ' + res.getStatus() + ', Response: ' + res.getBody());
                    return null;
                }
            } catch (Exception e) {
                System.debug('Error in handleMediaAttachment: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
                return null;
            }
        } else{
            return null;
        }
    }

    public static Blob downloadMediaContent(String mediaUrl, String accessToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(mediaUrl);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken); 
        HttpResponse res;
        
        try {
            Http http = new Http();
            res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Return the binary data
                return res.getBodyAsBlob();
            } else {
                System.debug('Failed to download media. Status: ' + res.getStatus() + ', Response: ' + res.getBody());
                return null;
            }
        }catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'WhatsAppWebhook', 'downloadMediaContent', e.getMessage());
            return null;
        }
    }
    
    public static void saveMediaToSalesforce(Blob mediaBlob, String filename, String mimeType, String messageType,String whatsAppMessageID,String formattedTime2,String formattedDate,String senderId,Id parentRecordId) {
        try {
            Contact contact = [SELECT Id, Name, OwnerId, User_Consent_Received__c FROM Contact WHERE Id = :parentRecordId WITH SECURITY_ENFORCED LIMIT 1];
    
            // Create ContentVersion with Contact's OwnerId
            ContentVersion contentVersion = new ContentVersion(
                Title = filename,
                VersionData = mediaBlob,
                PathOnClient = filename,
                ContentLocation = 'S',
                OwnerId = contact.OwnerId
            );
            if (Schema.sObjectType.ContentVersion.fields.Title.isCreateable() &&
                Schema.sObjectType.ContentVersion.fields.VersionData.isCreateable() &&
                Schema.sObjectType.ContentVersion.fields.PathOnClient.isCreateable() &&
                Schema.sObjectType.ContentVersion.fields.ContentLocation.isCreateable() &&
                Schema.sObjectType.ContentVersion.fields.OwnerId.isCreateable()) {

                insert contentVersion;
            } else {
                System.debug('User does not have access to create fields on ContentVersion');
            }
            
            ContentVersion insertedContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id WITH SECURITY_ENFORCED LIMIT 1 ];
            String contentDocumentId = insertedContentVersion.ContentDocumentId;

            CDLWrapper cdlWrap = new CDLWrapper(parentRecordId, contentDocumentId);
            String body = JSON.Serialize(cdlWrap);
           
            sendEmailViaGmail(body);

            System.debug('Media file saved as ContentDocument Id: ' + contentDocumentId);
    
            // Construct fileData object
            Map<String, Object> fileData = new Map<String, Object>{
                'fileName' => filename,
                'documentId' => contentDocumentId,
                'contentVersionId' => contentVersion.Id,
                'mimeType' => mimeType
            };

            List<WhatsApp_Chat__c> chatRecordsWp = [SELECT Id, ContactId__c, WhatsAppMessageID__c FROM WhatsApp_Chat__c WHERE WhatsAppMessageID__c = :whatsAppMessageID WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC];
            List<WhatsApp_Chat__c> deletedChatRecordsWp = [SELECT Id,ContactId__c,WhatsAppMessageID__c FROM WhatsApp_Chat__c WHERE WhatsAppMessageID__c = :whatsAppMessageID AND IsDeleted = true WITH SECURITY_ENFORCED  ORDER BY CreatedDate DESC];

            if (chatRecordsWp.isEmpty() && deletedChatRecordsWp.isEmpty()) {
                WhatsApp_Chat__c whatsappChat = new WhatsApp_Chat__c(
                    ContactId__c = parentRecordId,
                    Related_Record_Id__c =parentRecordId,
                    Message__c = filename,
                    Message_Type__c = 'Inbound-Message',
                    Type_of_Message__c = messageType,
                    WhatsAppMessageID__c = whatsAppMessageID,
                    Time_of_Message__c = formattedTime2,
                    File_Data__c= JSON.serialize(fileData),
                    Date_of_WpMessage__c = formattedDate,
                    Phone_Number_Id__c = phoneNumberId
                );
                ChatMessageEvent__e chatevent = new ChatMessageEvent__e(
                    ContactId__c =parentRecordId,
                    Message__c = filename,
                    Message_Type__c = 'Inbound-Message',
                    Type_of_Message__c = messageType,
                    WhatsAppMessageID__c = whatsAppMessageID,
                    Time_of_Message__c = formattedTime2,
                    Date_of_WpMessage__c = formattedDate,
                    userConsent__c = true
                );
                if (Schema.sObjectType.WhatsApp_Chat__c.fields.ContactId__c.isCreateable() && 
                    Schema.sObjectType.WhatsApp_Chat__c.fields.Related_Record_Id__c.isCreateable() &&
                    Schema.sObjectType.WhatsApp_Chat__c.fields.Message__c.isCreateable() &&
                    Schema.sObjectType.WhatsApp_Chat__c.fields.Message_Type__c.isCreateable() &&
                    Schema.sObjectType.WhatsApp_Chat__c.fields.Type_of_Message__c.isCreateable() &&
                    Schema.sObjectType.WhatsApp_Chat__c.fields.WhatsAppMessageID__c.isCreateable() &&
                    Schema.sObjectType.WhatsApp_Chat__c.fields.Time_of_Message__c.isCreateable() &&
                    Schema.sObjectType.WhatsApp_Chat__c.fields.Date_of_WpMessage__c.isCreateable() &&
                    Schema.sObjectType.WhatsApp_Chat__c.fields.Phone_Number_Id__c.isCreateable()) {

                    insert whatsappChat;
                } else {
                    System.debug('User does not have access to create fields on WhatsApp_Chat__c');
                }
                sendNotificationForContact(contact);
                EventBus.publish(chatevent);
                System.debug('WhatsApp_Chat__c record created: ' + whatsappChat.Id);
                updateContactUserConsent(contact);
            } else {
                System.debug('Unable to retrive whatsapp chat record.');
            }
        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'WhatsAppWebhook', 'saveMediaToSalesforce', e.getMessage());
        }
    }
	
    public static void sendNotificationForContact(Contact con) {
        try {
            CustomNotificationType cnType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'WhatsappNotification' WITH SECURITY_ENFORCED];
            // Id userId = Userinfo.getUserId();
            String messageContent = con.Name+' has sent a new message. Tap to view.';
            System.debug('messageContent==> '+messageContent);
            // Prepare the custom notification object
            Set<String> addressee = new Set<String>();
            addressee.add(con.OwnerId);
            Messaging.CustomNotification customNotificationObj = new Messaging.CustomNotification();
            customNotificationObj.setBody(messageContent); 
            customNotificationObj.setTitle('New Whatsapp Message Received'); 
            customNotificationObj.setNotificationTypeId(cnType.Id); 
            // customNotificationObj.setSenderId(userId); 
            customNotificationObj.setTargetId(con.Id); 
            customNotificationObj.send(addressee);
        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'WhatsAppWebhook', 'sendNotificationForContact', e.getMessage());
        }
    }
   
    public static List<WhatsAppMessage> parseMessages(String jsonString) {
        try {
            List<WhatsAppMessage> messages = new List<WhatsAppMessage>();
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
            List<Object> entries = (List<Object>) jsonMap.get('entry');
            
            if (entries != null && !entries.isEmpty()) {
                // for (Object entryObj : entries) {
                    Object entryObj = entries[0];
                    Map<String, Object> entry = (Map<String, Object>) entryObj;
                    List<Object> changes = (List<Object>) entry.get('changes');
                    
                    if (changes != null && !changes.isEmpty()) {
                        // for (Object changeObj : changes) {
                            Object changeObj = changes[0];
                            Map<String, Object> change = (Map<String, Object>) changeObj;
                            Map<String, Object> value = (Map<String, Object>) change.get('value');
                            List<Object> contacts = (List<Object>) value.get('contacts');
                            List<Object> statuses = (List<Object>) value.get('statuses');
                            
                            if (contacts != null && !contacts.isEmpty()) {
                                // for (Object contactObj : contacts) {
                                    Object contactObj = contacts[0];
                                    Map<String, Object> contact = (Map<String, Object>) contactObj;
                                    Map<String, Object> profile = (Map<String, Object>) contact.get('profile');
                                    String profileName = (String) profile.get('name');
                                    
                                    List<Object> messagesList = (List<Object>) value.get('messages');
                                    if (messagesList != null && !messagesList.isEmpty()) {
                                        // for (Object messageObj : messagesList) {
                                            Object messageObj = messagesList[0];
                                            Map<String, Object> message = (Map<String, Object>) messageObj;
                                            WhatsAppMessage msg = new WhatsAppMessage();
                                            msg.profileName = profileName;
                                            msg.timestamp = (String) message.get('timestamp');
                                            msg.wamId = (String) message.get('id');
                                            
                                            String messageType = (String) message.get('type');
                                            
                                            switch on messageType {
                                                when 'text' {
                                                    Map<String, Object> text = (Map<String, Object>) message.get('text');
                                                    msg.textBody = (String) text.get('body');
                                                    msg.textType = messageType;
                                                }
                                                when 'document' {
                                                    Map<String, Object> document = (Map<String, Object>) message.get('document');
                                                    msg.textBody = (String) document.get('filename');
                                                    msg.textType = messageType;
                                                    msg.mimeType = (String) document.get('mime_type');
                                                    msg.documentId = (String) document.get('id');
                                                }
                                                when 'image' {
                                                    Map<String, Object> image = (Map<String, Object>) message.get('image');
                                                    msg.imageBody = (String) image.get('caption'); 
                                                    msg.imageType = messageType;
                                                    msg.mimeType = (String) image.get('mime_type');
                                                    msg.imageId = (String) image.get('id');
                                                    msg.imageUrl = (String) image.get('link'); 
                                                }
                                                when 'video' {
                                                    Map<String, Object> image = (Map<String, Object>) message.get('video');
                                                    msg.videoBody = (String) image.get('caption'); 
                                                    msg.videoType = messageType;
                                                    msg.mimeType = (String) image.get('mime_type');
                                                    msg.videoId = (String) image.get('id');
                                                    msg.videoUrl = (String) image.get('link'); 
                                                }
                                                when 'audio' {
                                                    Map<String, Object> image = (Map<String, Object>) message.get('audio');
                                                    msg.audioBody = (String) image.get('caption'); 
                                                    msg.audioType = messageType;
                                                    msg.mimeType = (String) image.get('mime_type');
                                                    msg.audioId = (String) image.get('id');
                                                    msg.audioUrl = (String) image.get('link'); 
                                                }
                                                when 'button' {
                                                    Map<String, Object> button = (Map<String, Object>) message.get('button');
                                                    msg.textBody = (String) button.get('text'); 
                                                    msg.textType = messageType;
                                                }
                                                // Handle other types (images, videos, etc.) if needed
                                                when else {
                                                    // Handle unsupported message types if necessary
                                                    msg.textBody = 'Unsupported message type: ' + messageType;
                                                    msg.textType = messageType;
                                                }
                                            }
                                            messages.add(msg);
                                        // }
                                    }
                                // }
                            }

                            if(statuses != null && !statuses.isEmpty()){
                                // for(Object statusObj : statuses){
                                    Object statusObj = statuses[0];
                                    Map<String, Object> statusMap = (Map<String, Object>) statusObj;
                                    String status = (String) statusMap.get('status');
                                    String waid = (String) statusMap.get('id');

                                    WhatsApp_Chat__c waChat = [SELECT Id, WhatsAppMessageID__c FROM WhatsApp_Chat__c WHERE WhatsAppMessageID__c = :waid LIMIT 1];
                                    if(status == 'sent'){
                                        waChat.Message_Sent__c = true;
                                    } else if(status == 'delivered'){
                                        waChat.Message_Delivered__c = true;
                                    } else if(status == 'read'){
                                        waChat.Message_Seen__c = true;
                                    } else if(status == 'failed'){
                                        waChat.Message_Failed__c = true;
                                    }
                                    WhatsApp_Message_Status__e statusevent = new WhatsApp_Message_Status__e(
                                        Status__c = status,
                                        waId__c = waid
                                    );
                                    update as User waChat;
                                    EventBus.publish(statusevent);
                                // }
                            }

                            if (value.containsKey('event')) {
                                String event = (String) value.get('event');
                                String templateId = String.valueOf(value.get('message_template_id'));
                                updateWhatsAppTemplateStatus(templateId, event);
                            }
                        // }
                    }
                // }
            }
            return messages;
        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'WhatsAppWebhook', 'parseMessages', e.getMessage());
            return null;
        }
    }

    @future (callout=true)
    public static void updateWhatsAppTemplateStatus(String templateId, String event) {
        try {
            List<WhatsApp_Template__c> templates = [SELECT Id, Status__c FROM WhatsApp_Template__c WHERE Template_Id__c = :templateId WITH SECURITY_ENFORCED LIMIT 1];
            
            if (!templates.isEmpty()) {
                WhatsApp_Template__c waTemplate = templates[0];
                
                if (event == 'APPROVED') {
                    waTemplate.Status__c = 'Active-Quality Pending';
                } else if (event == 'PENDING') {
                    waTemplate.Status__c = 'In-Review';
                } else if (event == 'REJECTED') {
                    waTemplate.Status__c = 'Rejected';
                }
                
                update as User waTemplate;
            } else {
                System.debug('No WhatsApp Template found for Template Id: ' + templateId);
            }
        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'WhatsAppWebhook', 'updateWhatsAppTemplateStatus', e.getMessage());
        }
    }

    @future (callout=true)
    public static void sendEmailViaGmail(String body) {
        try {
            GmailConfig__c settings = GmailConfig__c.getOrgDefaults();
            String clientId = settings.Client_ID__c;
            String clientSecret = settings.Client_Secret__c;
            String refreshToken = settings.Refresh_Token__c;

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://oauth2.googleapis.com/token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('client_id=' + clientId +
                        '&client_secret=' + clientSecret +
                        '&refresh_token=' + refreshToken +
                        '&grant_type=refresh_token');

            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String newAccessToken = (String) jsonResponse.get('access_token');
                String newRefreshToken = (String) jsonResponse.get('refresh_token');

                String subject = 'ContentVersion Subject';
                String recipient = System.Label.GmailServiceLabel;

                String rawEmail = 'To: ' + recipient + '\n' +
                        'Subject: ' + subject + '\n' +
                        'Content-Type: text/html; charset=UTF-8\n\n' +
                        body;

                String encodedEmail = EncodingUtil.base64Encode(Blob.valueOf(rawEmail));
                String jsonBody = '{"raw":"' + encodedEmail + '"}';

                HttpRequest request = new HttpRequest();
                request.setEndpoint('https://gmail.googleapis.com/gmail/v1/users/me/messages/send');
                request.setMethod('POST');
                request.setHeader('Authorization', 'Bearer ' + newAccessToken);
                request.setHeader('Content-Type', 'application/json');
                request.setBody(jsonBody);

                Http http1 = new Http();
                HttpResponse response = http1.send(request);
            }
        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'WhatsAppWebhook', 'sendEmailViaGmail', e.getMessage());
        }
    }

    public static void updateContactUserConsent(Contact con){
        if(con.User_Consent_Received__c == false){
            if (Schema.sObjectType.Contact.fields.User_Consent_Received__c.isUpdateable()) {
                con.User_Consent_Received__c = true;
                update con;
            } else {
                System.debug('User does not have permission to update the User_Consent_Received__c field on Contact');
            }
        }
    }

    public class WhatsAppMessage {
        public String profileName { get; set; }
        public String timestamp { get; set; }
        public String wamId { get; set; }
        public String textBody { get; set; }
        public String textType { get; set; }
        public String mimeType { get; set; }
        public String documentId { get; set; }
        public String imageId { get; set; }
        public String imageUrl { get; set; }
        public String imageBody { get; set; }
        public String imageType { get; set; }
        public String videoBody { get; set; }
        public String videoId { get; set; }
        public String videoUrl { get; set; }
        public String videoType { get; set; }
        public String audioBody { get; set; }
        public String audioType { get; set; }
        public String audioId { get; set; }
        public String audioUrl { get; set; }
    }

    public class CDLWrapper{
        public String linkedEntityId;
        public String contentDocumentId;
        public CDLWrapper(String linkedEntityId, String contentDocumentId){
            this.linkedEntityId = linkedEntityId;
            this.contentDocumentId = contentDocumentId;
        }
    }
}