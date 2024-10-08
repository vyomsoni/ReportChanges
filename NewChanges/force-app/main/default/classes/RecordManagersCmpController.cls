public with sharing class RecordManagersCmpController {

    public class RecordManagerData {
        @AuraEnabled public List<FieldDetails> fieldDetailsList;
        @AuraEnabled public List<String> metadataRecords;
    }
    
    public class FieldInfoWrapper {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
    }

    @AuraEnabled
    public static RecordManagerData getListingFields(String objectApiName) {
        try {
            RecordManagerData recordData = new RecordManagerData();
            List<FieldDetails> fieldDetailsList = new List<FieldDetails>();

            MarketingListFilterConfig__mdt filterConfig = [SELECT BlockedFields__c FROM MarketingListFilterConfig__mdt WITH SECURITY_ENFORCED LIMIT 1];

            Set<String> blockedFields = new Set<String>();
            if (filterConfig != null && filterConfig.BlockedFields__c != null) {
                blockedFields.addAll(filterConfig.BlockedFields__c.split(';'));
            }

            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();

            for (String fieldName : fieldsMap.keySet()) {
                Schema.SObjectField field = fieldsMap.get(fieldName);
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                if (blockedFields.contains(fieldName) || !fieldDescribe.isAccessible()) {
                    continue;
                }

                FieldDetails fieldDetails = new FieldDetails();
                fieldDetails.label = fieldDescribe.getLabel();
                fieldDetails.value = fieldDescribe.getName();
                fieldDetails.fieldType = String.valueOf(fieldDescribe.getType());

                if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                    List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
                    if (!referenceTo.isEmpty()) {
                        fieldDetails.referenceObjectName = referenceTo[0].getDescribe().getName();
                        fieldDetails.relationshipName = fieldDescribe.getRelationshipName(); 
                    }
                } else {
                    fieldDetails.referenceObjectName = objectApiName;
                }

                if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
                    List<PicklistValue> picklistValues = new List<PicklistValue>();
                    for (Schema.PicklistEntry picklistEntry : fieldDescribe.getPicklistValues()) {
                        PicklistValue picklistValue = new PicklistValue();
                        picklistValue.label = picklistEntry.getLabel();
                        picklistValue.value = picklistEntry.getValue();
                        picklistValues.add(picklistValue);
                    }
                    fieldDetails.picklistValues = picklistValues;
                }

                fieldDetailsList.add(fieldDetails);
            }
            recordData.fieldDetailsList = fieldDetailsList;
            List<String> metadataValues = new List<String>();

            List<recordManagerConfig__mdt> metadataRecords = [SELECT FieldsData__c, PageSize__c FROM recordManagerConfig__mdt WITH SECURITY_ENFORCED LIMIT 1];
            if (!metadataRecords.isEmpty()) {
                recordManagerConfig__mdt metadataRecord = metadataRecords[0];
                metadataValues.add(metadataRecord.FieldsData__c);
                metadataValues.add(String.valueOf(metadataRecord.PageSize__c)); 
            }

            recordData.metadataRecords = metadataValues;

            return recordData;
        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'MarketingListFilterController', 'getContactFields', e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static RecordManagerData getContactFields(String objectApiName) {
        try {
            RecordManagerData recordData = new RecordManagerData();
            List<FieldDetails> fieldDetailsList = new List<FieldDetails>();

            MarketingListFilterConfig__mdt filterConfig = [SELECT BlockedFields__c FROM MarketingListFilterConfig__mdt WITH SECURITY_ENFORCED  LIMIT 1];

            Set<String> blockedFields = new Set<String>();
            if (filterConfig != null && filterConfig.BlockedFields__c != null) {
                blockedFields.addAll(filterConfig.BlockedFields__c.split(';'));
            }

            Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();

            Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();
            for (String fieldName : fieldsMap.keySet()) {
                if (blockedFields.contains(fieldName)) {
                    continue;
                }
                Schema.SObjectField field = fieldsMap.get(fieldName);
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

                FieldDetails fieldDetails = new FieldDetails();
                fieldDetails.label = fieldDescribe.getLabel();
                fieldDetails.value = fieldDescribe.getName();
                fieldDetails.fieldType = String.valueOf(fieldDescribe.getType());

                if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                    List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
                    if (!referenceTo.isEmpty()) {
                        fieldDetails.referenceObjectName = referenceTo[0].getDescribe().getName();
                        fieldDetails.relationshipName = fieldDescribe.getRelationshipName(); // Add relationship name
                    }
                } else {
                    fieldDetails.referenceObjectName = objectApiName;
                }

                if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
                    List<PicklistValue> picklistValues = new List<PicklistValue>();
                    for (Schema.PicklistEntry picklistEntry : fieldDescribe.getPicklistValues()) {
                        PicklistValue picklistValue = new PicklistValue();
                        picklistValue.label = picklistEntry.getLabel();
                        picklistValue.value = picklistEntry.getValue();
                        picklistValues.add(picklistValue);
                    }
                    fieldDetails.picklistValues = picklistValues;
                }
                fieldDetailsList.add(fieldDetails);
            }
            recordData.fieldDetailsList = fieldDetailsList;
            List<String> metadataValues = new List<String>();
            List<recordManagerMarketingConfig__mdt> metadataRecords = [SELECT FieldsData__c, PageSize__c FROM recordManagerMarketingConfig__mdt WITH SECURITY_ENFORCED LIMIT 1];

            if (!metadataRecords.isEmpty()) {
                recordManagerMarketingConfig__mdt metadataRecord = metadataRecords[0];
                metadataValues.add(metadataRecord.FieldsData__c);
                metadataValues.add(String.valueOf(metadataRecord.PageSize__c));
            }

            recordData.metadataRecords = metadataValues;

            return recordData;
        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'MarketingListFilterController', 'getContactFields', e.getMessage());
            return null;
        }
    }

   /**
    * Class Name : FieldDetails
    * @description : this is a wrapper class to pass multiple values to the LWC component.
    */
    public class FieldDetails {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String value { get; set; }
        @AuraEnabled
        public String fieldType { get; set; }
        @AuraEnabled
        public String referenceObjectName { get; set; }
        @AuraEnabled
        public String relationshipName { get; set; }
        @AuraEnabled
        public List<PicklistValue> picklistValues { get; set; }
    }

    /**
    * Class Name : PicklistValue
    * @description : this is a wrapper class to represent picklist values with label and value.
    */
    public class PicklistValue {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String value { get; set; }
    }


   /**
   * Method Name : saveMappings
   * @description : save mapping in the of the fields.
   * @param mappingsData String value.
   * @param checkboxValue Boolean value.
   */
    @AuraEnabled
    public static void saveMappings(String checklistData ,Integer totalPages){
        try {
            //fetch records
            List<recordManagerConfig__mdt> metaList = 
            [Select MasterLabel, DeveloperName, FieldsData__c From recordManagerConfig__mdt WITH SECURITY_ENFORCED LIMIT 1];
            
            //instance of the record
            Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
            mdata.fullName = 'recordManagerConfig__mdt.'+metaList[0].DeveloperName;
            mdata.label = metaList[0].MasterLabel;
            
            //instance of the value
            Metadata.CustomMetadataValue instance = new Metadata.CustomMetadataValue();
            instance.field = 'FieldsData__c';
            instance.value = checklistData;
            //adding the value to the record
            mdata.values.add(instance);

            Metadata.CustomMetadataValue instance2 = new Metadata.CustomMetadataValue();
            instance2.field = 'PageSize__c';
            instance2.value = totalPages;
            //adding the value to the record
            mdata.values.add(instance2);

            //instance of the container
            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(mdata);
            
            //enqueue deployment to the salesforce org
            Metadata.Operations.enqueueDeployment(container, null);
        } catch (Exception e) {
            ErrorHandler.insert_ErrorData(e,'RecordManagersCmpController','saveMappings' , e.getStackTraceString());
        }
    }

  @AuraEnabled
  public static void saveMappingMarketing(String checklistData ,Integer totalPages){
    try {
        //fetch records
        List<recordManagerMarketingConfig__mdt> metaList = 
        [Select MasterLabel, DeveloperName, FieldsData__c From recordManagerMarketingConfig__mdt WITH SECURITY_ENFORCED LIMIT 1];
        
        //instance of the record
        Metadata.CustomMetadata mdata = new Metadata.CustomMetadata();
        mdata.fullName = 'recordManagerMarketingConfig__mdt.'+metaList[0].DeveloperName;
        mdata.label = metaList[0].MasterLabel;
        
        //instance of the value
        Metadata.CustomMetadataValue instance = new Metadata.CustomMetadataValue();
        instance.field = 'FieldsData__c';
        instance.value = checklistData;
        //adding the value to the record
        mdata.values.add(instance);

        Metadata.CustomMetadataValue instance2 = new Metadata.CustomMetadataValue();
        instance2.field = 'PageSize__c';
        instance2.value = totalPages;
        //adding the value to the record
        mdata.values.add(instance2);


        //instance of the container
        Metadata.DeployContainer container = new Metadata.DeployContainer();
        container.addMetadata(mdata);
        
        //enqueue deployment to the salesforce org
        Metadata.Operations.enqueueDeployment(container, null);
    } catch (Exception e) {
        ErrorHandler.insert_ErrorData(e,'RecordManagersCmpController','saveMappingMarketing' , e.getStackTraceString());
    } 
   }


@AuraEnabled
public static List<FieldDetails> getListingFieldsParent(String objectApiName) {
   List<FieldDetails> fieldDetailsList = new List<FieldDetails>();

   ListingManagerFilterConfig__mdt filterConfig = [SELECT BlockedFields__c FROM ListingManagerFilterConfig__mdt WITH SECURITY_ENFORCED  LIMIT 1];

   // Parse the blocked fields
   Set<String> blockedFields = new Set<String>();
   if (filterConfig != null && filterConfig.BlockedFields__c != null) {
       blockedFields.addAll(filterConfig.BlockedFields__c.split(';'));
   }

   // Get the Describe result for the given object
   Schema.DescribeSObjectResult objDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();

   // Get the fields map for the object
   Map<String, Schema.SObjectField> fieldsMap = objDescribe.fields.getMap();

   // Iterate through each field
   for (String fieldName : fieldsMap.keySet()) {
       if (blockedFields.contains(fieldName)) {
           continue;
       }
       Schema.SObjectField field = fieldsMap.get(fieldName);
       Schema.DescribeFieldResult fieldDescribe = field.getDescribe();

       // Create a new FieldDetails object for each field
       FieldDetails fieldDetails = new FieldDetails();
       fieldDetails.label = fieldDescribe.getLabel();
       fieldDetails.value = fieldDescribe.getName();
       fieldDetails.fieldType = String.valueOf(fieldDescribe.getType());

       // Check if the field is a reference field
       if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
           // Get the reference to the related objects
           List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
           if (!referenceTo.isEmpty()) {
               fieldDetails.referenceObjectName = referenceTo[0].getDescribe().getName();
           }
       }else{
           fieldDetails.referenceObjectName = objectApiName;
       }

       // Check if the field is a picklist
       if (fieldDescribe.getType() == Schema.DisplayType.Picklist) {
           List<PicklistValue> picklistValues = new List<PicklistValue>();
           for (Schema.PicklistEntry picklistEntry : fieldDescribe.getPicklistValues()) {
               PicklistValue picklistValue = new PicklistValue();
               picklistValue.label = picklistEntry.getLabel();
               picklistValue.value = picklistEntry.getValue();
               picklistValues.add(picklistValue);
           }
           fieldDetails.picklistValues = picklistValues;
       }

       // Add the field details object to the list
       fieldDetailsList.add(fieldDetails);
   }

   return fieldDetailsList;
}


}