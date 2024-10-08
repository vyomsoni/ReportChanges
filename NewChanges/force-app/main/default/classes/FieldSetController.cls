public with sharing class FieldSetController {
    @AuraEnabled
    public static FieldSetForm getForm(Id recordId, String objectName, String fieldSetName) {
        FieldSetForm form = new FieldSetForm();        
        form.fields = getFields(recordId, objectName, fieldSetName);
        return form;
    }
    
    public static List<FormField> getFields(Id recordId, String objectName, String fieldSetName) {
        Schema.SObjectType objectType = null;
        if (recordId != null) {
            objectType = recordId.getSobjectType();
        }
        else if (objectName != null && String.isNotBlank(objectName)) {
            objectType = Schema.getGlobalDescribe().get(objectName);
        }
        Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
        Map<String, Schema.FieldSet> fieldSetMap = objectDescribe.fieldSets.getMap();
        Schema.FieldSet fieldSet = fieldSetMap.get(fieldSetName);
        List<Schema.FieldSetMember> fieldSetMembers = fieldSet.getFields();
        List<FormField> fields = new List<FormField>();
        for (Schema.FieldSetMember fsm : fieldSetMembers) {
            FormField f = new FormField(fsm);
            fields.add(f);
        }
        return fields;
    }
    
    public class FieldSetForm {
        @AuraEnabled
        public List<FormField> fields { get; set; }
        public FieldSetForm() {
            fields = new List<FormField>();
        }
    }

    public class FilterWrapper {
        @AuraEnabled
        public Map<String,List<Listing__c>> records  { get; set; }
        @AuraEnabled
        public Map<Id, String> medias { get; set; }
    }

    @AuraEnabled
    public static FilterWrapper fetchListings(Property__c listin){
        try {
            Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get('MVEX__Property__c').getDescribe().fields.getMap();
            String fieldList = '';
            for (String fieldName : fieldsMap.keySet()) {
                fieldList += fieldName + ', ';
            }
            fieldList = fieldList.removeEnd(', '); 
            // Add related child records from Listings__r relationship
            fieldList += ', (SELECT Id, Name FROM MVEX__Listings__r WHERE MVEX__Status__c = \'Active\')';
            String query = 'SELECT ' + fieldList + ' FROM MVEX__Property__c WHERE ';
            // Add conditions based on input property fields
            if (listin.Name != null && listin.Name != '') {
                if (String.isNotBlank(listin.Name)) {
                    query += ' Name LIKE \'%' + listin.Name + '%\' AND ';
                }
                query = query.removeEnd(' AND ');
            } else {
                return null;
            }
            String escapeQuery = String.escapeSingleQuotes(query);
            List<Property__c> listinglst = Database.query(escapeQuery);
            if (listinglst.isEmpty()) {
                return null;
            }
            Set<Id> propertyIds = new Set<Id>();
            for (Property__c listingRec : listinglst) {
                Id propertyId = listingRec.Id;
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
            List<Property_File__c> medias = [SELECT Id, BaseUrl__c, Property__c FROM Property_File__c WHERE Property__c IN :propertyIds WITH SECURITY_ENFORCED];
            Map<Id, String> propertyMediaUrlsMap = new Map<Id, String>();
            for (Property_File__c media : medias) {
                propertyMediaUrlsMap.put(media.Property__c, media.BaseUrl__c);
            }
            Map<String,List<Listing__c>> lstMap = new Map<String,List<Listing__c>>();
            List<Listing__c> lstIds = new List<Listing__c>();
            String addrField;
            for(Property__c c:listinglst){   
                if(c.Listings__r!=null && !c.Listings__r.isEmpty()){
                    for(Listing__c p : c.Listings__r){
                        addrField = '';
                        if(c.City__c!=null && c.City__c!='' && String.isNotBlank(c.City__c)){
                            addrField += c.City__c + ', '; 
                        }
                        else{
                            addrField += '';
                        }
                        if(c.State__c!=null && c.State__c!='' && String.isNotBlank(c.State__c)){
                            addrField += c.State__c + ', '; 
                        }
                        else{
                            addrField += '';
                        }
                        if(c.Country__c!=null && c.Country__c!='' && String.isNotBlank(c.Country__c)){
                            addrField += c.Country__c + ', '; 
                        }
                        else{
                            addrField += '';
                        }

                        String propertyJson = JSON.serialize(c);
                        if(!lstMap.containsKey(c.Id+'::'+c.Name+'::'+addrField)){
                            lstMap.put(c.Id+'::'+c.Name+'::'+addrField+'::'+propertyJson,new List<Listing__c>());
                        }
                        lstMap.get(c.Id+'::'+c.Name+'::'+addrField+'::'+propertyJson).add(p);  
                    }
                }
                else{
                    addrField = '';
                    if(c.City__c!=null && c.City__c!='' && String.isNotBlank(c.City__c)){
                        addrField += c.City__c + ', '; 
                    }
                    else{
                        addrField += '';
                    }
                    if(c.State__c!=null && c.State__c!='' && String.isNotBlank(c.State__c)){
                        addrField += c.State__c + ', '; 
                    }
                    else{
                        addrField += '';
                    }
                    if(c.Country__c!=null && c.Country__c!='' && String.isNotBlank(c.Country__c)){
                        addrField += c.Country__c + ', '; 
                    }
                    else{
                        addrField += '';
                    }
                    String propertyJson = JSON.serialize(c);
                    lstMap.put(c.Id+'::'+c.Name+'::'+addrField+'::'+propertyJson,new List<Listing__c>());
                }
            }

            FilterWrapper wc = new FilterWrapper();
            wc.medias = propertyMediaUrlsMap;
            wc.records = lstMap;
            return wc; 
        } catch (Exception e) {
            System.debug('error-->>'+e.getMessage()+'---'+e.getStackTraceString());
            return null;
            
        }
    }

    @AuraEnabled
    public static List<Map<String, String>> fetchContacts(Contact listin, String soqlquery) {
        try {
            String query = '';
            if ((listin.FirstName != null && listin.FirstName != '') || String.isNotBlank(listin.LastName)) {
                query = 'SELECT ' + soqlquery + ' FROM Contact WHERE ';
                if (String.isNotBlank(listin.FirstName)) {
                    query += ' FirstName LIKE \'%' + listin.FirstName + '%\' AND ';
                }
                if (String.isNotBlank(listin.LastName)) {
                    query += ' LastName LIKE \'%' + listin.LastName + '%\' AND ';
                }
                query = query.removeEnd(' AND ');
            } else {
                return null;
            }
            String escapeQuery = String.escapeSingleQuotes(query);
            List<Contact> listinglst = Database.query(escapeQuery);
            if (listinglst.isEmpty()) {
                return null;
            }
            List<String> fieldNames = soqlquery.split(',');
            List<Map<String, String>> contactList = new List<Map<String, String>>();
            for (Contact c : listinglst) {
                Map<String, String> contactMap = new Map<String, String>();
                for (String fieldName : fieldNames) {
                    String fieldValue = String.valueOf(c.get(fieldName.trim()));
                    contactMap.put(fieldName.trim(), fieldValue);
                }
                contactList.add(contactMap);
            }
            return contactList;
        } catch (Exception e) {
            System.debug('error-->>' + e.getMessage() + '---' + e.getStackTraceString());
            return null;
        }
    }

}