public without sharing class WhatsAppMessageQueueable implements Queueable {
    private List<BroadcastMessageController.RecordData> recordsData;
    private Id templateId;
    private String timeOfMessage;
    private String headerMergeVal;
    private List<String> mergeFieldValues;
    public static String currentTime = System.now().format('yyyy-MM-dd HH:mm:ss');


    public WhatsAppMessageQueueable(List<BroadcastMessageController.RecordData> recordsData, Id templateId, String timeOfMessage,String headerMergeVal,List<String> mergeFieldValues) {
        this.recordsData = recordsData;
        this.templateId = templateId;
        this.timeOfMessage = timeOfMessage;
        this.headerMergeVal = headerMergeVal;
        this.mergeFieldValues = mergeFieldValues;
    }

    public void execute(QueueableContext context) {
        try {
            WhatsApp_Template__c waTemp = [SELECT Id, Name,Template_Header__c,Body__c,Template_Footer__c, Contains_Variable_Value__c,Language__c, Category__c, Total_Merge_Fields__c,Body_Merge_Field_Count__c,Type_of_Buttons__c FROM WhatsApp_Template__c WHERE Id = :templateId LIMIT 1];

            Broadcast__c broadcast = new Broadcast__c();
            insert broadcast;
            System.debug('broadcast id '+broadcast.Id);
            String messageBody='';
            for (BroadcastMessageController.RecordData data : recordsData) {
                if (data.phoneNumber != null && data.recordId != null) {
                    Boolean hasCopyCodeButton = false;

                    if (!String.isBlank(waTemp.Type_of_Buttons__c)) {
                        List<String> buttonTypes = waTemp.Type_of_Buttons__c.split('\n'); 
            
                        for (String buttonType : buttonTypes) {
                            if (buttonType.trim().contains('COPY_CODE')) {
                                hasCopyCodeButton = true;
                            }
                        }
                    }
        
                    if(waTemp.Category__c == 'Authentication'){
                        String otpVal = generateOTP();
                         messageBody = '{ "messaging_product": "whatsapp", "to": "' + data.phoneNumber + '", "type": "template", "template": { "name": "' + waTemp.Name + '", "language": { "code": "' + waTemp.Language__c + '" }, "components": [ ' +
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
                        messageBody = '{ "messaging_product": "whatsapp", "to": "' + data.phoneNumber + '", "type": "template", "template": { "name": "' + waTemp.Name + '", "language": { "code": "' + waTemp.Language__c + '" }, "components": [ ';
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
                    sendWhatsAppMessage(data.phoneNumber, messageBody,templateId, waTemp.Name, timeOfMessage, broadcast.Id,data.recordId, data.recordName);
                }
            }
            String broadcastMessage = waTemp.Template_Header__c +'\n'+
                                      waTemp.Body__c + '\n'+
                                      waTemp.Template_Footer__c;
            broadcast.Message__c = broadcastMessage;
            if(Broadcast__c.sObjectType.getDescribe().isUpdateable()){
                update broadcast;
            }
        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsAppMessageQueueable', 'execute',currentTime);
            System.debug('Error in execute: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
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
    

    @future(callout=true)
    private static void sendWhatsAppMessage(String toPhone, String messageBody,String templateId, String messageText, String timeOfMessage, String broadcastId,String objRecordId, String recordName) {
        String isTestApp = System.Label.Whatsapp_test_app_toggle;
        String accessToken = '';
        String endpoint = '';

        if (isTestApp == 'true') {
            accessToken = System.Label.Test_WA_Accesstoken;
            endpoint = System.Label.Test_WA_endpoint;
        } else if (isTestApp == 'false') {
            accessToken = System.Label.access_token_for_whatsapp;
            endpoint = System.Label.whatsapp_endpoint;
        }

        try {
            if ((accessToken != '') && (endpoint != '')) {
                HttpRequest httpReq = new HttpRequest();
                httpReq.setEndpoint(endpoint);
                httpReq.setMethod('POST');
                httpReq.setHeader('Content-Type', 'application/json');
                httpReq.setHeader('Authorization', 'Bearer ' + accessToken);
                httpReq.setBody(messageBody);
                Contact con = [Select Id, Name from Contact where Id =: objRecordId WITH SECURITY_ENFORCED];

                Http http = new Http();
                HttpResponse response = http.send(httpReq);
                String reponseBody = response.getBody();
                Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(reponseBody);
                List<Object> messages = (List<Object>) jsonMap.get('messages');
                Map<String, Object> firstMessage = (Map<String, Object>) messages[0];
                String whatsAppMessageID = (String) firstMessage.get('id');
                System.debug('WhatsApp Message ID: ' + whatsAppMessageID);

                if (response.getStatusCode() == 200) {
                    WhatsApp_Chat__c whatsappMsg = new WhatsApp_Chat__c(
                        Message_Type__c = 'Outbound-Message',
                        Message__c = messageText,
                        Time_of_Message__c = timeOfMessage,
                        WhatsAppMessageID__c = whatsAppMessageID,
                        Template__c=templateId,
                        Record_Name__c = recordName,
                        Related_Record_Id__c = objRecordId,
                        ContactId__c = (con.Id != null) ? con.Id : '',
                        Type_of_Message__c = 'Broadcast',
                        Broadcast__c = broadcastId,
                        Status__c = 'Success',
                        Date_of_WpMessage__c = Datetime.now().format('d MMM yyyy')
                    );
                    if(WhatsApp_Chat__c.sObjectType.getDescribe().isCreateable()){
                        insert whatsappMsg;
                    }
                } else {
                    System.debug('Failed to send message: ' + response.getBody());
                }
            } else {
                System.debug('Access token or endpoint not set.');
            }
        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsAppMessageQueueable', 'sendWhatsAppMessage',currentTime);
            System.debug('Error in sendWhatsAppMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }

   
}