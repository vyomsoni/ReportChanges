/*
--------- Last Edited by Kajal Tiwari -------
--------- DateTime: 4/09/24 4:00 PM ---------
--------- Changes: Correct the PMD Errors ---
*/
public without sharing class WhatsAppMessageQueueable implements Queueable {
    private List<BroadcastMessageController.RecordData> recordsData;
    private Id templateId;
    private String timeOfMessage;
    public static String currentTime = System.now().format('yyyy-MM-dd HH:mm:ss');


    public WhatsAppMessageQueueable(List<BroadcastMessageController.RecordData> recordsData, Id templateId, String timeOfMessage) {
        this.recordsData = recordsData;
        this.templateId = templateId;
        this.timeOfMessage = timeOfMessage;
    }

    public void execute(QueueableContext context) {
        try {
            WhatsApp_Template__c waTemp = [SELECT Id, Name,Template_Header__c, Body__c,Template_Footer__c,Contains_Variable_Value__c	 
                                           FROM WhatsApp_Template__c WHERE Id = :templateId LIMIT 1];

            Broadcast__c broadcast = new Broadcast__c();
            insert broadcast;
            System.debug('broadcast id '+broadcast.Id);
            String messageBody='';
            for (BroadcastMessageController.RecordData data : recordsData) {
                if (data.phoneNumber != null && data.recordId != null) {
                    if(waTemp.Contains_Variable_Value__c){
                         messageBody = '{ "messaging_product": "whatsapp", "to": "'+data.phoneNumber+'", "type": "template", "template": { "name": "'+waTemp.Name+'", "language": { "code": "en_US" }, "components": [ {"type": "body", "parameters": [ { "type": "text", "text": "'+ data.recordName +'"} ] } ] } }';
                    }else{
                         messageBody = '{ "messaging_product": "whatsapp", "to": "'+data.phoneNumber+'", "type": "template", "template": { "name": "'+waTemp.Name+'", "language": { "code": "en_US" } } }';
                    }
                    sendWhatsAppMessage(data.phoneNumber, messageBody,templateId, waTemp.Name, timeOfMessage, broadcast.Id,data.recordId, data.recordName);
                }
            }
            String broadcastMessage = waTemp.Template_Header__c +'\n'+
                                      waTemp.Body__c + '\n'+
                                      waTemp.Template_Footer__c;
            broadcast.Message__c = broadcastMessage;
            try {
                if(Broadcast__c.sObjectType.getDescribe().isUpdateable()){
                    update broadcast;
                }
                System.debug('Broadcast record updated successfully.');
            } catch (Exception e) {
                System.debug('Error updating Broadcast record: ' + e.getMessage());
            }

        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'WhatsAppMessageQueueable', 'execute',currentTime);
            System.debug('Error in execute: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
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
                try {
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
                } catch (Exception e) {
                    // ExceptionLog.exception(e.getMessage(), 'WhatsAppMessageQueueable', 'sendWhatsAppMessage',currentTime);
                    System.debug('Error in sendWhatsAppMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
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