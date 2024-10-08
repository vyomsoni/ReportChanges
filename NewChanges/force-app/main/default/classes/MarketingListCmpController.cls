/**
* Class Name : MarketingListCmpController
* Test Class : Pending
* Date : 21/06/2024
* Created By : Vyom Soni
* Last Modified Date : 08-07-2024
* Last Modified By : Vyom Soni
* @description : Used in the MarketingList lwc component
*/

public with sharing class MarketingListCmpController {
     /**
    * Class Name : WrapperClass
    * @description : this wrapper list set contacts and medias together.
    */
    public class WrapperClass{
        @AuraEnabled
        public List<Contact> contacts;  
        @AuraEnabled
        public Integer pageSize;
        @AuraEnabled
        public List<Map<String, String>> selectedFields;       
    }

    /**
    * Method Name : getContactData
    * @description : for the retrieve the contact data.
    * @return List<Contact>.
    */
    @AuraEnabled
    public static WrapperClass getContactData(){
        if (!Schema.sObjectType.Contact.isAccessible()) {
            throw new AuraHandledException('You do not have permission to access Contact records.');
        }
        try {
            String contactFields = 'Id,Name,Phone,Email,WhatsApp_Phone__c';
            List<Map<String, String>> configuredFields = getConfiguredFields(); // Method to get selected fields from the config
            System.debug('fields'+configuredFields);
            if (!configuredFields.isEmpty()) {
                List<String> fieldNames = new List<String>();
                
                // Convert contactFields to a Set for easier comparison and remove extra spaces
                Set<String> existingFields = new Set<String>();
                for (String field : contactFields.split(',')) {
                    existingFields.add(field.trim());
                }

                // Add fields from configuredFields if they are not already in contactFields
                for (Map<String, String> field : configuredFields) {
                    String fieldApiname = field.get('fieldApiname').trim();
                    if (!existingFields.contains(fieldApiname)) {
                        fieldNames.add(fieldApiname);
                    }
                }
                
                // If there are new fields to add, append them to contactFields
                if (!fieldNames.isEmpty()) {
                    contactFields += ', ' + String.join(fieldNames, ', ');
                }
            }

            // Fetch pageSize from the custom metadata
            Integer pageSize = getPageSizeFromConfig(); 
         
            String query = 'SELECT ' + contactFields + ' ' +'FROM Contact WITH SECURITY_ENFORCED';

            // Debug the constructed query
            System.debug('SOQL Query: ' + query);

            // Fetch the contacts with related records
            List<Contact> contacts = Database.query(query);

            WrapperClass wc = new WrapperClass();
            wc.contacts = contacts; 
            wc.pageSize = pageSize; // Include the pageSize in the WrapperClass
            wc.selectedFields = configuredFields; // Include the selected fields (APIName and Label) in the WrapperClass
        
            return wc;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

        /**
     * Method Name : getConfiguredFields
     * @description : Retrieves the configured fields (API names and labels) from custom metadata.
     * @return List<Map<String, String>>.
     */
    private static List<Map<String, String>> getConfiguredFields() {
        List<recordManagerMarketingConfig__mdt> configs = [
            SELECT FieldsData__c 
            FROM recordManagerMarketingConfig__mdt 
            LIMIT 1
        ];
        
        List<Map<String, String>> fields = new List<Map<String, String>>();
        
        if (!configs.isEmpty()) {
            recordManagerMarketingConfig__mdt config = configs[0];
            String fieldsDataJson = config.FieldsData__c;
            
            if (String.isNotBlank(fieldsDataJson)) {
                // Deserialize JSON to List<Map<String, String>>
                fields = (List<Map<String, String>>)JSON.deserialize(fieldsDataJson, List<Map<String, String>>.class);
            }
        }
        
        return fields;
    }

    // Helper method to get pageSize from metadata
    private static Integer getPageSizeFromConfig() {
        List<recordManagerMarketingConfig__mdt> configs = [
            SELECT PageSize__c 
            FROM recordManagerMarketingConfig__mdt 
            LIMIT 1
        ];
        
        if (!configs.isEmpty()) {
            recordManagerMarketingConfig__mdt config = configs[0];
            return config.PageSize__c != null ? Integer.valueOf(config.PageSize__c) : 30; // Default to 30 if not set
        }
        
        return 30; // Default to 30 if no metadata found
    }

     /**
    * Method Name : getAllFields
    * @description : get all fields of the obeject.
    * @param sObjectName String sObject name value.
    * @return String of fields Name.
    */
    private static String getAllFields(String sObjectName) {
        // Get all fields of the given sObject
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(sObjectName).getDescribe().fields.getMap();
        List<String> fieldNames = new List<String>();
        
        for (String fieldName : fieldMap.keySet()) {
            // Check if the field is accessible
            if (fieldMap.get(fieldName).getDescribe().isAccessible()) {
                fieldNames.add(fieldName);
            }
        }
        
        // Join the field names into a single comma-separated string
        return String.join(fieldNames, ', ');
    }

    // Method to get form data based on recordId, objectName, and fieldSetName
     /**
    * Method Name : getForm
    * @description : get fields from the field-set and set into wrapper class.
    * @param recordId Id value.
    * @param objectName String Object Name value.
    * @param fieldSetName String field-set name value.
    * @return String of fields Name.
    */
    @AuraEnabled
    public static FieldSetForm getForm(Id recordId, String objectName, String fieldSetName) {
        System.debug('Entering getForm method');
        FieldSetForm form = new FieldSetForm();
        form.fieldsData = getFields(recordId, objectName, fieldSetName);
        System.debug('Exiting getForm method with form: ' + form);
        return form;
    }

    /**
    * Method Name : getFields
    * @description : for the retrieve the fields apiname and labels.
    * @param recordId Id value.
    * @param objectName String Object Name value.
    * @param fieldSetName String field-set name value.
    * @return List<FormField>.
    */
    @AuraEnabled
    public static List<FormField> getFields(Id recordId, String objectName, String fieldSetName) {
        System.debug('Entering getFields method');
        Schema.SObjectType objectType = null;

        // Determine the object type from the recordId or objectName
        if (recordId != null) {
            objectType = recordId.getSObjectType();
        } else if (String.isNotBlank(objectName)) {
            objectType = Schema.getGlobalDescribe().get(objectName);
        } else {
            throw new IllegalArgumentException('Both recordId and objectName cannot be null or empty');
        }

        if (objectType == null) {
            throw new IllegalArgumentException('Object type could not be determined from recordId or objectName');
        }

        // Describe the object and get the field set map
        Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
        Map<String, Schema.FieldSet> fieldSetMap = objectDescribe.fieldSets.getMap();

        // Ensure the field set exists
        if (!fieldSetMap.containsKey(fieldSetName)) {
            throw new IllegalArgumentException('Field set name ' + fieldSetName + ' does not exist on object ' + objectType.getDescribe().getName());
        }

        // Get the fields from the field set
        Schema.FieldSet fieldSet = fieldSetMap.get(fieldSetName);
        List<Schema.FieldSetMember> fieldSetMembers = fieldSet.getFields();

        // Convert field set members to FormField objects
        List<FormField> fields = new List<FormField>();
        for (Schema.FieldSetMember fsm : fieldSetMembers) {
            fields.add(new FormField(fsm));
        }

        System.debug('Exiting getFields method with fields: ' + fields);
        return fields;
    }

     /**
    * Class Name : FieldSetForm
    * @description : this is wrapper class for set fieldsetdata.
    */
    public class FieldSetForm {
        @AuraEnabled
        public List<FormField> fieldsData { get; set; }

        public FieldSetForm() {
            fieldsData = new List<FormField>();
        }
    }

     /**
    * Class Name : FieldSetForm
    * @description : Inner class representing a field from the field set.
    */
    public class FormField {
        @AuraEnabled
        public String fieldName { get; set; }
        @AuraEnabled
        public String fieldLabel { get; set; }

        public FormField(Schema.FieldSetMember fieldSetMember) {
            this.fieldName = fieldSetMember.getFieldPath();
            this.fieldLabel = fieldSetMember.getLabel();
        }
    }

      /**
    * Class Name : sendEmail
    * @description : send to mass email
    */
    @AuraEnabled
    public static void sendEmail(String emailDataJson) {
        Map<String, Object> emailData = (Map<String, Object>) JSON.deserializeUntyped(emailDataJson);
        
        String sendMethod = (String) emailData.get('sendMethod');
        String templateId = (String) emailData.get('templateId');

        List<GmailIntegrationControllerV1.EmailWrapper> gmails = new List<GmailIntegrationControllerV1.EmailWrapper>();
        List<OutlookIntegrationController.EmailWrapper> outlookMails = new List<OutlookIntegrationController.EmailWrapper>();


        String templateBody = '';

        List<Template__c> temp = [SELECT Id, Template_Name__c,
        (SELECT Id, Template_Value_Simple__c,Value_Type__c FROM Template_Data__r WHERE Value_Type__c = 'Body Value' ORDER BY Order_No_Simple__c ASC),
        (SELECT Id, Page_Margin__c, Page_Orientation__c, Page_Size__c, Unit_of_Page_Configs__c, Show_Header__c, Show_Footer__c, Header_margin_top__c, Footer_margin_bottom__c FROM Template_Pages__r ORDER BY Page_Number__c ASC)
        FROM Template__c WHERE Id =: templateId WITH SECURITY_ENFORCED LIMIT 1 ];

        if(temp.size() > 0){
            for(Template_Data__c fieldData : temp[0].Template_Data__r){
                String value = fieldData.Template_Value_Simple__c != null ? fieldData.Template_Value_Simple__c : '';
                if(fieldData.Value_Type__c == 'Body Value'){
                    templateBody += value;
                }
            }    
        }
        
        // Explicitly cast the contacts to the correct type
        List<Object> contactListRaw = (List<Object>) emailData.get('contacts');
        List<Map<String, Object>> contacts = new List<Map<String, Object>>();
        
        for (Object contactRaw : contactListRaw) {
            contacts.add((Map<String, Object>) contactRaw);
        }

        System.debug('contacts ==> ' + contacts);
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Template__c template = [SELECT Id, Name, Label__c , Object_Name__c , Template_Status__c, Template_Body__c, Template_Type__c, Description__c, CreatedDate, Template_pattern__c, Subject__c FROM Template__c WHERE Id = :templateId WITH SECURITY_ENFORCED];
        
        for (Map<String, Object> contact : contacts) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            String contactEmail = (String) contact.get('Email');
            String contactId = (String) contact.get('id');
            
            if (contactEmail != null && contactEmail != '') {


                Map<String, Map<String, String>> mappingKeys = DataMappingControllerV2.getMappingsKeyValues(new List<String>{templateId}, contactId, true);

                Map<String, String> mappingKeyVsMappingValues = mappingKeys.get('objectNGeneral');
                Map<String, String> salesforceImages = mappingKeys.get('salesforceImages');
        
                for(String key : mappingKeyVsMappingValues.keySet()) {
                    String escapedKey = Pattern.quote(key); // Escapes special characters in the key
                    templateBody = templateBody.replaceAll(escapedKey, mappingKeyVsMappingValues.get(key));
                }
                
                for(String src : salesforceImages.keySet()) {
                    String escapedSrc = Pattern.quote(src); // Escapes special characters in the src
                    templateBody = templateBody.replaceAll(escapedSrc, salesforceImages.get(src));
                }



                if(sendMethod == 'single'){
                    email.setToAddresses(new List<String>{contactEmail});
                    email.setSubject(template.Subject__c);
                    email.setHtmlBody(templateBody);


                    emails.add(email);
                }

                else if(sendMethod == 'outlook') {
                    OutlookIntegrationController.EmailWrapper singleOutlookMail = new OutlookIntegrationController.EmailWrapper();

                    singleOutlookMail.toAddresses = new List<String>{contactEmail};
                    singleOutlookMail.subject = template.Subject__c;
                    singleOutlookMail.body = templateBody;

                    outlookMails.add(singleOutlookMail);
                }

                else if(sendMethod == 'gmail'){

                    GmailIntegrationControllerV1.EmailWrapper singleGmail = new GmailIntegrationControllerV1.EmailWrapper();
                    singleGmail.toAddresses = new List<String>{contactEmail};
                    singleGmail.subject = template.Subject__c;
                    singleGmail.body = templateBody;

                    gmails.add(singleGmail);
                }
            }
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }

        else if(!gmails.isEmpty()){
            GmailIntegrationControllerV1.requestNewAccessToken(gmails,null,null,false);
        }

        else if(!outlookMails.isEmpty()){
            OutlookIntegrationController.requestNewAccessToken(outlookMails,null,null,false);
        }
    }

}