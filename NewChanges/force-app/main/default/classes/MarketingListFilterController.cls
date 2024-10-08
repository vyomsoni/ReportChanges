/**
* Class Name : MarketingListFilterController
* Test Class : Pending
* Date : 23/06/2024
* Created By : Vyom Soni
* Last Modified Date : 08-07-2024
* Last Modified By : Vyom Soni
* @description : Used in MarektingListFilterCmp and MarketingListFilterAddCmp LWC components.
*/
public with sharing class MarketingListFilterController {
    /**
    * Method Name : getContactFields
    * @description : get the fields by parent object name.
    * @param ObjectApIName String value
    * @return List of Fields of all references of Contact.
    */
    @AuraEnabled
    public static List<FieldDetails> getContactFields(String objectApiName) {
        try{
            List<FieldDetails> fieldDetailsList = new List<FieldDetails>();

            MarketingListFilterConfig__mdt filterConfig = [SELECT BlockedFields__c FROM MarketingListFilterConfig__mdt WITH SECURITY_ENFORCED LIMIT 1];

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
                fieldDetails.fieldName = fieldDescribe.getLabel();
                fieldDetails.fieldAPIName = fieldDescribe.getName();
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
        }catch (Exception e) {
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
        public String fieldName { get; set; }
        @AuraEnabled
        public String fieldAPIName { get; set; }
        @AuraEnabled
        public String fieldType { get; set; }
        @AuraEnabled
        public String referenceObjectName { get; set; }
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
    * Method Name : getPicklistValues
    * @description : get static fields picklist values.
    * @param apiName string field api name value.
    * @param objectName string object api name value.
    * @return List of picklist values.
    */
    @AuraEnabled
    public static List<Map<String, String>> getPicklistValues(String apiName ,String objectName) {
        try{
            String objectApiName =objectName ;
            String fieldApiName = apiName;
            List<Map<String, String>> picklistValues = new List<Map<String, String>>();
            
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
            Schema.DescribeSObjectResult describeSObjectResult = sObjectType.getDescribe();
            Schema.DescribeFieldResult describeFieldResult = describeSObjectResult.fields.getMap().get(fieldApiName).getDescribe();
            
            List<Schema.PicklistEntry> picklistEntries = describeFieldResult.getPicklistValues();
            
            for (Schema.PicklistEntry entry : picklistEntries) {
                picklistValues.add(new Map<String, String>{'label' => entry.getLabel(), 'value' => entry.getValue()});
            }     
            return picklistValues;
        }catch(Exception e){
            ErrorHandler.insert_errordata(e, 'MarketingListFilterController', 'getPicklistValues', e.getMessage());
            return null;
        }
    }

    /**
    * Class Name : ContactWrapper
    * @description : this is a wrapper class to represent Contact records with parent record.
    */
    public class ContactWrapper {
        public Contact contact { get; set; }
        public Contact masterRecord { get; set; }
        public Contact reportTo { get; set; }
        public Account account { get; set; }
        public Individual individual { get; set; }
        public User createdby { get; set; }
        public User lastmodifyby { get; set; }
        public Listing__c purchaselisting { get; set; }
        public Account company { get; set; }
        
        
        public ContactWrapper(Contact contact, Contact masterRecord , Contact reportTo,Account account,Individual individual,User createdby,User lastmodifyby,Listing__c purchaselisting, Account company) {
            this.contact = contact;
            this.masterRecord = masterRecord;
            this.reportTo = reportTo;
            this.account = account;
            this.individual = individual;
            this.createdby = createdby;
            this.lastmodifyby = lastmodifyby;
            this.purchaselisting = purchaselisting;
            this.company = company;
        }

        /**
        * Method Name : toJson
        * @description : Convert the JSON data into string.
        * @return String of contact data.
        */
        public String toJson() {
            Map<String, Object> result = new Map<String, Object>();
            result.put('Id', contact.Id);
            result.put('Name', contact.Name);
            result.put('Contact', getAllFieldsWithValues(contact));
            result.put('MasterRecordId', getAllFieldsWithValues(masterRecord));
            result.put('ReportsToId', getAllFieldsWithValues(reportTo));
            result.put('AccountId', getAllFieldsWithValues(account));
            result.put('IndividualId', getAllFieldsWithValues(individual));
            result.put('CreatedById', getAllFieldsWithValues(createdby));
            result.put('LastModifiedById', getAllFieldsWithValues(lastmodifyby));
            result.put('Purchasing_Listing__r', getAllFieldsWithValues(purchaselisting));
            result.put('AccountId__r', getAllFieldsWithValues(company));
            return JSON.serialize(result);
        }

        /**
        * Method Name : getAllFieldsWithValues
        * @description : Get all fields with value.
        * @param obj SObject value.
        * @return map of field-name within api-name.
        */
        private Map<String, Object> getAllFieldsWithValues(SObject obj) {
            try{
                Map<String, Object> fieldMap = new Map<String, Object>();
                if (obj != null) {
                    for (SObjectField field : obj.getSObjectType().getDescribe().fields.getMap().values()) {
                        String fieldName = field.getDescribe().getName();
                        fieldMap.put(fieldName, obj.get(fieldName));
                    }
                }
                return fieldMap;
            }catch(Exception e){
                ErrorHandler.insert_errordata(e, 'MarketingListFilterController', 'getAllFieldsWithValues', e.getMessage());
                return null;
            }
        }
    }

    public class SetWrapper{
        @AuraEnabled
        public List<String> contact { get; set; }
        @AuraEnabled
        public String soqlquery { get; set; }
    }

     /**
    * Method Name : getContactsWithRelatedRecords
    * @description : get contact with related records.
    * @return List of picklist values.
    */
    @AuraEnabled
    public static SetWrapper getContactsChunked(Integer limitSize, Integer offsetSize ,String soqlquery) {
        try{
            List<String> contactJsons = new List<String>();

            String query = '';
            System.debug('dynamic');
            if(soqlquery == ''){

            // Dynamically build the SOQL query to include all fields
            String contactFields = String.escapeSingleQuotes(getAllFields('Contact'));
            String masterRecordFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('Contact', 'MasterRecord'));
            String reportToFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('Contact', 'ReportsTo'));
            String accountFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('Account', 'Account'));
            String individualFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('Individual', 'Individual'));
            String createdbyFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('User', 'CreatedBy'));
            String lastmodifybyFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('User', 'LastModifiedBy'));
            String purchaselistingFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('Listing__c', 'Purchasing_Listing__r'));
            String companyFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('Account', 'AccountId__r'));

            // Constructing the SOQL query
            query = 'SELECT ' + 
                        contactFields + ', ' + 'Contact.HasOptedOutOfEmail'+ ', ' + 'Contact.HasOptedOutOfFax' + ', ' + 'Contact.DoNotCall' + ', '+ 'Contact.Pronouns' + ', '+ 'Contact.GenderIdentity' + ', '+
                        masterRecordFields + ', ' +
                        accountFields + ', ' + 'Account.Tier'+', '+
                        reportToFields +', '+
                        individualFields +', '+
                        createdbyFields + ', '+
                        lastmodifybyFields + ', '+
                        purchaselistingFields + ', '+
                        companyFields + ' '+
                        'FROM Contact LIMIT :limitSize OFFSET :offsetSize';
            }else{
                System.debug('static');
                query = String.escapeSingleQuotes(soqlquery);
            }

            // Fetch the contacts with related records
            List<Contact> contacts = Database.query(query);

            // Iterate through the contacts and create wrapper instances
            for (Contact contact : contacts) {
                Contact relatedMasterRecord = contact.MasterRecord;
                Contact relatedReportsToId= contact.ReportsTo;
                Account relatedAccount= contact.Account;
                Individual relatedIndividual= contact.Individual;
                User relatedCreatedBy= contact.CreatedBy;
                User relatedLastModifiedBy= contact.LastModifiedBy;
                Listing__c relatedPurchaseListing= contact.Purchasing_Listing__r;
                Account relatedCompany= contact.AccountId__r;
                ContactWrapper lw = new ContactWrapper(contact,relatedMasterRecord,relatedReportsToId,relatedAccount,relatedIndividual,relatedCreatedBy,relatedLastModifiedBy,relatedPurchaseListing,relatedCompany);
                contactJsons.add(lw.toJson());
            }

            SetWrapper ls = new SetWrapper();
            ls.contact = contactJsons;
            ls.soqlquery = query;

            return ls;
        }catch(Exception e){
            // ErrorHandler.insert_errordata(e, 'MarketingListFilterController', 'getAllFieldsWithValues', e.getMessage());
            System.debug(e.getMessage());
            return null;
        }
    }

    
     /**
    * Method Name : getAllFields
    * @description : get all fields of the obeject.
    * @param sObjectName String value object name.
    * @return String of fields Name.
    */
    private static String getAllFields(String sObjectName) {
        try{
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
        }catch(Exception e){
            ErrorHandler.insert_errordata(e, 'MarketingListFilterController', 'getAllFields', e.getMessage());
            return null;
        }
    }
    

    /**
    * Method Name : getAllFieldsWithPrefix
    * @description : get all fields with prefix.
    * @param sObjectName String value object name.
    * @param prefix String value prefix value.
    * @return String of fields Name.
    */
    private static String getAllFieldsWithPrefix(String sObjectName, String prefix) {
        try{
            // Get all fields of the given sObject and prefix them for a parent relationship query
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(sObjectName).getDescribe().fields.getMap();
            List<String> fieldNames = new List<String>();
            
            for (String fieldName : fieldMap.keySet()) {
                // Check if the field is accessible
                if (fieldMap.get(fieldName).getDescribe().isAccessible()) {
                    fieldNames.add(prefix + '.' + fieldName);
                }
            }
            // Join the field names into a single comma-separated string
            return String.join(fieldNames, ', ');
        }catch(Exception e){
            ErrorHandler.insert_errordata(e, 'MarketingListFilterController', 'getAllFieldsWithPrefix', e.getMessage());
            return null;
        }
    }

    /**
    * Method Name : getTheOfferRecords
    * @description : get all offer records.
    * @return String of fields Name.
    */
    @AuraEnabled
    public static List<Inquiry__c> getTheInquiryRecords(){
        try{
            String querylist = String.escapeSingleQuotes(getAllFields('Inquiry__c'));
            String query = 'SELECT ' + querylist+' '+
                        'FROM Inquiry__c WHERE Contact__c != NULL';
            List<Inquiry__c> contacts = Database.query(query);
            return contacts;
        }catch(Exception e){
            ErrorHandler.insert_errordata(e, 'MarketingListFilterController', 'getTheInquiryRecords', e.getMessage());
            return null;
        }
    }

    /**
    * Method Name : getStaticFields
    * @description : get the static fields from the custom metadata.
    * @return String of JSON data.
    */
    @AuraEnabled
    public static String getStaticFields() {
        try{
            // Check if the user has read access to MarketingListFilterConfig__mdt object
            if (!Schema.MarketingListFilterConfig__mdt.SObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have permission to access MarketingListFilterConfig__mdt.');
            }
            // Check if the user has read access to StaticFields__c field
            if (!Schema.MarketingListFilterConfig__mdt.StaticFields__c.getDescribe().isAccessible()) {
                throw new AuraHandledException('You do not have permission to access StaticFields__c.');
            }
            // Perform the SOQL query
            MarketingListFilterConfig__mdt filterConfig = [SELECT StaticFields__c FROM MarketingListFilterConfig__mdt WITH SECURITY_ENFORCED LIMIT 1];
            return filterConfig.StaticFields__c;
        }catch(Exception e){
            ErrorHandler.insert_errordata(e, 'MarketingListFilterController', 'getStaticFields', e.getMessage());
            return null;
        }
    }
}