/**
* Class Name : ListingManagerFilterController
* Test Class : Pending
* Created By : Vyom Soni
* Last Modified Date : 07-06-2024
* Last Modified By : Vyom Soni
* @description : Used in portalMappingComponent and portalMappingLandingPage LWC components
*/

public with sharing class ListingManagerFilterController {

    /**
    * Method Name : getListingFields
    * @description : get the fields by parent object name.
    * @param ObjectApIName String value.
    * @return List of Fields of all references of Listing.
    */
    @AuraEnabled
    public static List<FieldDetails> getListingFields(String objectApiName) {
        try{
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
        }catch(Exception e){
            ErrorHandler.insert_errordata(e, 'ListingManagerFilterController', 'getListingFields', e.getMessage());
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
            ErrorHandler.insert_errordata(e, 'ListingManagerFilterController', 'getPicklistValues', e.getMessage());
            return null;
        }
    }

    /**
    * Class Name : ListingWrapper
    * @description : this is a wrapper class to represent listing records with parent record.
    */
    public class ListingWrapper {
        public Listing__c listing { get; set; }
        public Contact contact { get; set; }
        public Property__c property { get; set; }
        public Account account { get; set; }
        public RecordType recordtype { get; set; }
        public User createdby { get; set; }
        public User lastmodifyby { get; set; }
        
        public ListingWrapper(Listing__c listing, Contact contact,Property__c property , Account account,RecordType recordtype,User createdby,User lastmodifyby ) {
            this.listing = listing;
            this.contact = contact;
            this.property = property;
            this.account = account;
            this.recordtype = recordtype;
            this.createdby = createdby;
            this.lastmodifyby = lastmodifyby;
        }

          /**
            * Method Name : toJson
            * @description : Convert the JSON data into string.
            * @return String of listing data.
            */
        public String toJson() {
            Map<String, Object> result = new Map<String, Object>();
            result.put('Id', listing.Id);
            result.put('Name', listing.Name);
            result.put('Listing__c', getAllFieldsWithValues(listing));
            result.put('Contact__r', getAllFieldsWithValues(contact));
            result.put('Property__r', getAllFieldsWithValues(property));
            result.put('Account__r', getAllFieldsWithValues(account));
            result.put('RecordTypeId', getAllFieldsWithValues(recordtype));
            result.put('CreatedBy', getAllFieldsWithValues(createdby));
            result.put('LastModifiedById', getAllFieldsWithValues(lastmodifyby));
            return JSON.serialize(result);
        }

        /**
        * Method Name : getAllFieldsWithValues
        * @description : Get all fields with value.
        * @param obj SObject value.
        * @return map of field-name within api-name.
        */
        public Map<String, Object> getAllFieldsWithValues(SObject obj) {
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
                ErrorHandler.insert_errordata(e, 'ListingManagerFilterController', 'getAllFieldsWithValues', e.getMessage());
                return null;
            }
        }
    }

    public class SetWrapper{
        @AuraEnabled
        public List<String> listing { get; set; }
        @AuraEnabled
        public String soqlquery { get; set; }
    }

     /**
    * Method Name : getListingsWithRelatedRecords
    * @description : get listing with related records.
    * @return List of picklist values.
    */
    @AuraEnabled
    public static SetWrapper getListingsChunked(Integer limitSize, Integer offsetSize ,String soqlquery) {
        try{

            List<String> listingJsons = new List<String>();
            String query = '';
            System.debug('dynamic');
            if(soqlquery == ''){
                // Dynamically build the SOQL query to include all fields
                String listingFields = String.escapeSingleQuotes(getAllFields('Listing__c'));
                String contactFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('Contact', 'Contact__r'));
                String propertyFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('Property__c', 'Property__r'));
                String accountFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('Account', 'Account__r'));
                String recordTypeFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('RecordType', 'RecordType'));
                String createdbyFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('User', 'CreatedBy'));
                String lastmodifybyFields =  String.escapeSingleQuotes(getAllFieldsWithPrefix('User', 'LastModifiedBy'));
        
                // Constructing the SOQL query
                query = 'SELECT ' + listingFields + ', ' +
                            contactFields + ', ' +'Contact__r.HasOptedOutOfEmail'+ ', ' + 'Contact__r.HasOptedOutOfFax' + ', ' + 'Contact__r.DoNotCall' + ', '+ 'Contact__r.Pronouns' + ', '+ 'Contact__r.GenderIdentity' + ', '+
                            propertyFields + ', ' +
                            accountFields + ', ' +'Account__r.Tier'+', '+
                            recordTypeFields +', '+
                            createdbyFields + ', '+
                            lastmodifybyFields + ' '+
                            'FROM Listing__c  LIMIT :limitSize OFFSET :offsetSize';
                System.debug('dynamic');
            }else{
                System.debug('static');
                query = String.escapeSingleQuotes(soqlquery);
            }
    
            // Debug the constructed query
            System.debug('SOQL Query: ' + query);
    
            // Fetch the listings with related records
            List<Listing__c> listings = Database.query(query);
    
            // Iterate through the listings and create wrapper instances
            for (Listing__c listing : listings) {
                Contact relatedContact = listing.Contact__r;
                Property__c relatedProperty = listing.Property__r;
                Account relatedAccount= listing.Account__r;
                RecordType relatedRecordType= listing.RecordType;
                User relatedCreatedBy= listing.CreatedBy;
                User relatedLastModifiedBy= listing.LastModifiedBy;
                ListingWrapper lw = new ListingWrapper(listing, relatedContact, relatedProperty,relatedAccount,relatedRecordType,relatedCreatedBy,relatedLastModifiedBy);
                listingJsons.add(lw.toJson());
            }
            SetWrapper ls = new SetWrapper();
            ls.listing = listingJsons;
            ls.soqlquery = query;
            // Debug the listing wrapper records
            System.debug('ls.soqlquery: ' + query);
    
            return ls;
        }catch(Exception e){
            ErrorHandler.insert_errordata(e, 'ListingManagerFilterController', 'getListingsWithRelatedRecords', e.getMessage());
            return null;
        }
    }

    
     /**
    * Method Name : getAllFields
    * @description : get all fields of the obeject.
    * @param sObjectName String value object name.
    * @return String of fields Name.
    */
    public static String getAllFields(String sObjectName) {
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
            ErrorHandler.insert_errordata(e, 'ListingManagerFilterController', 'getAllFields', e.getMessage());
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
    public static String getAllFieldsWithPrefix(String sObjectName, String prefix) {
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
            ErrorHandler.insert_errordata(e, 'ListingManagerFilterController', 'getAllFieldsWithPrefix', e.getMessage());
            return null;
        }
    }

   /**
    * Method Name : getTheOfferRecords
    * @description : get all offer records.
    * @return String of fields Name.
    */
    @AuraEnabled
    public static List<Offer__c> getTheOfferRecords(){
        try{
            String querylist = String.escapeSingleQuotes(getAllFields('Offer__c'));
            String query = 'SELECT ' + querylist+' '+
                           'FROM Offer__c WHERE Listing__c != NULL';
            List<Offer__c> listings = Database.query(query);
            return listings;
        }catch(Exception e){
            ErrorHandler.insert_errordata(e, 'ListingManagerFilterController', 'getTheOfferRecords', e.getMessage());
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
        ListingManagerFilterConfig__mdt filterConfig = [SELECT StaticFields__c FROM ListingManagerFilterConfig__mdt WITH SECURITY_ENFORCED LIMIT 1];
        return filterConfig.StaticFields__c;
    }

    @AuraEnabled
    public static String getCurrencyISOCode() {
        // Get the currency ISO code of the current user
       try {
            // Query the CurrencyIsoCode field for the current user
            String currencyIsoCode = [SELECT CurrencyIsoCode FROM User WHERE Id = :UserInfo.getUserId()].CurrencyIsoCode;
            return currencyIsoCode;
        } catch (Exception e) {
            ErrorHandler.insert_errordata(e, 'ListingManagerFilterController', 'getCurrencyISOCode', e.getMessage());
            return null;
        }
    }
    
}