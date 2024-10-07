public without sharing class BroadcastMessageController {
    
    public static String currentTime = System.now().format('yyyy-MM-dd HH:mm:ss');

    @AuraEnabled(cacheable=true)
    public static List<Broadcast__c> getBroadcastRecord(){
        try {
            List<Broadcast__c> broadcast = [Select Id, Name,CreatedDate,Recipients__c,Sent__c,Read__c,Delivered__c,Failed__c from Broadcast__c WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC];
            System.debug(broadcast);
            return broadcast;

        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'BroadcastMessageController', 'getBroadcastRecord',currentTime);
            System.debug('Error in getBroadcastRecord: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
       
    }
    @AuraEnabled(cacheable=true)
    public static List<String> getObjectNames() {
        try {
            List<String> objectNames = new List<String>();
            for (Schema.SObjectType obj : Schema.getGlobalDescribe().values()) {
                objectNames.add(obj.getDescribe().getName());
            }           
            objectNames.sort();      
            return objectNames;
            
        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'BroadcastMessageController', 'getObjectNames',currentTime);
            System.debug('Error in getObjectNames: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
       
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean hasPhoneField(String objectName) {
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            Schema.DescribeSObjectResult describeResult = objType.getDescribe();
            return describeResult.fields.getMap().containsKey('WhatsApp_Phone__c');

        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'BroadcastMessageController', 'hasPhoneField',currentTime);
            System.debug('Error in hasPhoneField: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return false;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getListViews(String objectName) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        try {
            List<ListView> listViews = [SELECT Id, Name FROM ListView WHERE SObjectType = :objectName WITH SECURITY_ENFORCED];
            for (ListView lv : listViews) {
                Map<String, String> option = new Map<String, String>();
                option.put('value', lv.Id);
                option.put('label', lv.Name);
                options.add(option);
            }
        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'BroadcastMessageController', 'getListViews',currentTime);
            System.debug('Error in getListViews: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
        return options;
    }

    
    @AuraEnabled
    public static List<SObject> getListViewRecords(String objectName, String listViewId, String sessionId) {
        HttpRequest req = new HttpRequest();
        String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
        String endPoinURL = baseUrl + '/services/data/v50.0/sobjects/' + objectName + '/listviews/' + listViewId + '/describe';
        System.debug('endPoinURL ==> ' + endPoinURL);
        
        req.setEndpoint(endPoinURL);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + sessionId);

        try {       
            Http http = new Http();
            HttpResponse response = http.send(req);
            System.debug('response ==> ' + response.getBody());
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> tokenResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String query = (String) tokenResponse.get('query');
                System.debug('Query ==> ' + query);
                
                if (query != null && query.contains('WhatsApp_Phone__c')) {
                    System.debug('Phone field is included in the query.');
                } else {
                    System.debug('Phone field is not included in the query.');
                    query = query.replace('FROM Contact', ', WhatsApp_Phone__c FROM Contact');
                    System.debug('Modified Query ==> ' + query);
                }
                
                try {
                    List<SObject> objList = Database.query(query);
                    System.debug('objList ==> ' + objList);
                    System.debug('objList size ==> ' + objList.size());
                    
                    return objList;

                }  catch (Exception e) {
                    // ExceptionLog.exception(e.getMessage(), 'BroadcastMessageController', 'getListViewRecords',currentTime);
                    System.debug('Error in getListViewRecords: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
                    return null;
                }
            } else {
                System.debug('Response Error: ' + response.getStatusCode() + ' ' + response.getStatus());
            }

        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'BroadcastMessageController', 'getListViewRecords',currentTime);
            System.debug('Error in getListViewRecords: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
            return null;
        }
        
        return new List<SObject>();
    }
    
    public class RecordData {
        @AuraEnabled public String phoneNumber;
        @AuraEnabled public Id recordId;
        @AuraEnabled public String recordName;
    }


    @AuraEnabled
    public static void sendTemplateMessage(String recordsJson, Id templateId, String timeOfMessage,String headerMergeVal,List<String> mergeFieldValues) {
        try {
            List<RecordData> recordsData = (List<RecordData>) JSON.deserialize(recordsJson, List<RecordData>.class);
            System.debug('templateid in controller: '+templateId);
            WhatsAppMessageQueueable queueableJob = new WhatsAppMessageQueueable(recordsData, templateId, timeOfMessage,headerMergeVal,mergeFieldValues);
            System.enqueueJob(queueableJob);

        } catch (Exception e) {
            // ExceptionLog.exception(e.getMessage(), 'BroadcastMessageController', 'sendTemplateMessage',currentTime);
            System.debug('Error in sendTemplateMessage: ' + e.getMessage() + '\n' + e + '\n Exception line no: ' + e.getLineNumber());
        }
    }

    @AuraEnabled
    public static void scheduleTemplateMessage(String recordsJson, Id templateId, String timeOfMessage,String headerMergeVal,List<String> mergeFieldValues) {
        try {
            if (timeOfMessage.endsWith('Z')) {
                timeOfMessage = timeOfMessage.substring(0, timeOfMessage.length() - 1);
            }
            
            timeOfMessage = timeOfMessage.replace('T', ' ');
            System.debug('timeOfMessage '+timeOfMessage);
            DateTime scheduledDateTime;
            try {
                scheduledDateTime = DateTime.valueOf(timeOfMessage);
                System.debug('scheduledDateTime '+scheduledDateTime);
            } catch (Exception e) {
                throw new IllegalArgumentException('Invalid date/time format: ' + timeOfMessage);
            }
            String formattedTime = scheduledDateTime.format('hh:mm a');
            System.debug('Formatted Time (AM/PM): ' + formattedTime);

            String cronExpression = getCronExpression(scheduledDateTime);
            System.debug('cronExpression '+cronExpression);

            List<RecordData> recordsData = (List<RecordData>) JSON.deserialize(recordsJson, List<RecordData>.class);
            WhatsAppMessageQueueSchedular queueableSchedular = new WhatsAppMessageQueueSchedular(recordsData, templateId, formattedTime,headerMergeVal,mergeFieldValues);
            
            String jobName = 'BroadcastTemplateSchedule_' + System.currentTimeMillis();
            System.schedule(jobName, cronExpression, queueableSchedular);
        } catch (Exception e) {
            System.debug('Error scheduling queuable job: ' + e.getMessage());
            throw e;
        }
    }

    public static String getCronExpression(DateTime dt) {
        String cronExpression = '0 ' + 
                            dt.minute() + ' ' + 
                            dt.hour() + ' ' + 
                            dt.day() + ' ' + 
                            dt.month() + ' ' + 
                            '?' + ' ' +  
                            dt.year();
        return cronExpression;
    }

}