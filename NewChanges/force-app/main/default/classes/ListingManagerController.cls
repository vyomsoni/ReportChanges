/**
* Class Name : ListingManagerController
* Date : 03-06-2024
* Created By : Vyom Soni
* Last Modified Date : 19-06-2024
* Last Modified By : Vyom Soni
* @description : Used in the ListingManager lwc component
*/

public with sharing class ListingManagerController {
    /**
    * Class Name : WrapperClass
    * @description : this wrapper list set listing and medias together.
    */
    public class WrapperClass{
        @AuraEnabled
        public List<Listing__c> listings;  
        @AuraEnabled
        public Map<Id, String> medias;  
        @AuraEnabled
        public Integer pageSize;
        @AuraEnabled
        public List<Map<String, String>> selectedFields;       
    }
    /**
    * Method Name : getListingData
    * @description : for the retrieve the listing data.
    * @return List<Listing__c>.
    */
    @AuraEnabled
    public static WrapperClass getListingData(){
        if (!Schema.sObjectType.Listing__c.isAccessible()) {
        throw new AuraHandledException('You do not have permission to access Listing records.');
    }
        try {
            String listingFields = 'Id,City__c ,Bathrooms__c,Listing__c.Property__c,Country__c,State__c,Street__c,Name';
            List<Map<String, String>> configuredFields = getConfiguredFields(); // Method to get selected fields from the config
            System.debug('fields'+configuredFields);
            if (!configuredFields.isEmpty()) {
                List<String> fieldNames = new List<String>();
                
                // Convert listingFields to a Set for easier comparison and remove extra spaces
                Set<String> existingFields = new Set<String>();
                for (String field : listingFields.split(',')) {
                    existingFields.add(field.trim());
                }

                // Add fields from configuredFields if they are not already in listingFields
                for (Map<String, String> field : configuredFields) {
                    String fieldApiname = field.get('fieldApiname').trim();
                    if (!existingFields.contains(fieldApiname)) {
                        fieldNames.add(fieldApiname);
                    }
                }
                
                // If there are new fields to add, append them to listingFields
                if (!fieldNames.isEmpty()) {
                    listingFields += ', ' + String.join(fieldNames, ', ');
                }
            }

            // Fetch pageSize from the custom metadata
            Integer pageSize = getPageSizeFromConfig(); 

            String query = 'SELECT ' + listingFields + ' FROM Listing__c WITH SECURITY_ENFORCED';
            System.debug('SOQL Query: ' + query);
            // Fetch the listings with related records
            List<Listing__c> listing = Database.query(query);
            Set<Id> propertyIds = new Set<Id>();     

            for(Listing__c listingrec :listing) {
                Id propertyId = (Id)listingrec.get('Property__c');
                if (propertyId != null) {
                    propertyIds.add(propertyId);
                }
            }  

            if (!Schema.sObjectType.Property_File__c.isAccessible()) {
                throw new AuraHandledException('You do not have permission to access Property File records.');
            }

            // Check if the user has read access to the necessary fields of Property_File__c
            if (!Schema.sObjectType.Property_File__c.fields.BaseUrl__c.isAccessible() ||
                !Schema.sObjectType.Property_File__c.fields.Property__c.isAccessible()) {
                throw new AuraHandledException('You do not have permission to access required fields of Property File records.');
            }

            List<Property_File__c> medias = [SELECT Id, BaseUrl__c, Property__c FROM Property_File__c SECURITY_ENFORCED WHERE Property__c IN:propertyIds ];

            Map<Id, String> propertyMediaUrlsMap = new Map<Id, String>();
            for (Property_File__c media : medias) {
                    propertyMediaUrlsMap.put(media.Property__c,media.BaseUrl__c);
            }
            WrapperClass wc = new WrapperClass();
            wc.listings = listing;
            wc.medias = propertyMediaUrlsMap;
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
        List<recordManagerConfig__mdt> configs = [
            SELECT FieldsData__c 
            FROM recordManagerConfig__mdt 
            LIMIT 1
        ];
        
        List<Map<String, String>> fields = new List<Map<String, String>>();
        
        if (!configs.isEmpty()) {
            recordManagerConfig__mdt config = configs[0];
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
        List<recordManagerConfig__mdt> configs = [
            SELECT PageSize__c 
            FROM recordManagerConfig__mdt 
            LIMIT 1
        ];
        
        if (!configs.isEmpty()) {
            recordManagerConfig__mdt config = configs[0];
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
    public static String getAllFields(String sObjectName) {
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

}