/**
Created by: Raja Bhandari
Description: Provide logic to add user, contact and account when user is creating case for someone else whose user doesn't exist.
#####################
Modification Details: 
Name    ||    Reason    ||     Date 


#####################
**/
public without sharing class AccessTypeCTRL {
    
    /**
    Description: get Id of the contact for the current user
    **/
    @AuraEnabled
    public static String provideCurrentUserConId(){
        Contact con = [Select Id from Contact where Email =: UserInfo.getUserEmail()]; 
        return con.Id;
    }
        
    /**
    Description: insert the records necessary to proceed and create case
    **/
    @AuraEnabled
    public static String insertAccAndCon(AccessRecordWrapper accessRecordWrapperObj){
        
        try{
            List<Account> accList = new List<Account>();
            
            if(accessRecordWrapperObj.accesslevel == 4){
                accList = [Select Id From Account where AccountNumber = '1000' limit 1];
            }else{
                accList = [Select Id From Account where AccountNumber =: accessRecordWrapperObj.accountNumber limit 1];
            }
            
            List<Contact> conList = new List<Contact>();
            conList = [Select Id From Contact where Email =: accessRecordWrapperObj.emailAddr limit 1];
            
            String accId = '';
            
            if(acclist.size() == 0){
                Account acc = new Account();
                
                if(accessRecordWrapperObj.accesslevel == 4){
                    acc.Name = 'Cisco';
                    acc.AccountNumber = '1000';
                }else{
                    acc.Name = accessRecordWrapperObj.companyName;
                    acc.AccountNumber = accessRecordWrapperObj.accountNumber;
                }
                insert acc;
            }else{
                accId = acclist[0].Id;
            }
            
            System.debug('insertAccAndCon > accId > '+accId); 
            
            String conId = '';
            
            if(conList.size()  == 0 ){
                Contact conObj = new Contact();
                
                conObj.AccountId = accId;
                conObj.AccessLevel__c = accessRecordWrapperObj.accesslevel;
                conObj.CCOID__c =    accessRecordWrapperObj.ccoId;
                conObj.CiscoUniversalID__c = accessRecordWrapperObj.ciscoUniversalId;
                conObj.Email = accessRecordWrapperObj.emailAddr;
                conObj.FirstName = accessRecordWrapperObj.firstName;
                conObj.LastName = accessRecordWrapperObj.lastName;
                conObj.JobTitle__c = accessRecordWrapperObj.jobTitle;
                
                insert conObj;
                
                conId = conObj.Id;
                
                Profile associateProfile = [Select Id From Profile where Name='Custom Customer Community User' limit 1];
                
                User usrObj = new User(
                    ProfileId = associateProfile.Id,
                    FederationIdentifier = accessRecordWrapperObj.emailAddr,
                    FirstName = accessRecordWrapperObj.firstName,
                    LastName = accessRecordWrapperObj.lastName,
                    Email = accessRecordWrapperObj.emailAddr,
                    Alias = String.valueof(accessRecordWrapperObj.firstName.substring(0,1) + accessRecordWrapperObj.lastName.substring(0,1)) + String.valueOf(Math.random()).substring(0,5),
                    Isactive = true,
                    Username = accessRecordWrapperObj.emailAddr + '.' + Label.Organization_Type,
                    EmailEncodingKey = 'UTF-8',
                    LanguageLocaleKey = 'en_US',
                    LocaleSidKey = 'en_US',
                    TimeZoneSidKey = 'America/Los_Angeles',
                    ContactId = conId,
                    // Prefs
                    ReceivesAdminInfoEmails = false,
                    ReceivesInfoEmails = false,
                    UserPermissionsKnowledgeUser = true
                    //UserPreferencesContentNoEmail = true,
                    //UserPreferencesContentEmailAsAndWhen = true
                );
                
                insert usrObj;
                
                System.debug('usrObj >>> '+usrObj);
                
                conObj.User__c = usrObj.Id;
                Update conObj;
            }else{
                conId = conList[0].Id;
            }

            return conId;
        }catch (Exception ex) {
            system.debug('ex.getMessage() >'+ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    /**
    Description: Return the wrapper to show details of contact found in cisco api call 
    **/
    @AuraEnabled
    public static AccessRecordWrapper getContactAPI(String emailId){
        try{
            Authentication_Credential__mdt authencationHeader = [Select Id,
                                                                 Method__c,
                                                                 Query_Params__c,
                                                                 Authentication_Info_Record__c,
                                                                 EndPoint__c 
                                                                 From Authentication_Credential__mdt
                                                                 Where MasterLabel = 'Contact API' 
                                                                 limit 1];
            
            
            
            String accesstoken = Access_Token_For_API__c.getInstance('ContactAPIAccessToken').Access_Token__c;
            if(!String.isBlank(accesstoken) || Test.isRunningTest()){
                Http httpObj = new Http();
                HttpRequest httpReqObj = new HttpRequest();
                httpReqObj.setMethod(authencationHeader.Method__c);
                httpReqObj.setHeader('Authorization', 'Bearer '+accesstoken);
                httpReqObj.setEndPoint(authencationHeader.EndPoint__c+'?EmailAddress='+emailId);
                httpReqObj.setTimeOut(120000);
                
                HttpResponse  httpResponseObj = httpObj.send(httpReqObj);
                
                if(httpResponseObj.getStatusCode() == 200 && !String.isBlank(httpResponseObj.getBody())){
                    Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(httpResponseObj.getBody());
                    system.debug('Contact Map > '+responseMap);
                    
                    if(responseMap.get('ContactDetailsView') != null){
                        AccessRecordWrapper accessRecordWrapper = new AccessRecordWrapper();
                        
                        Object contactDetailsViewObjectFields = responseMap.get('ContactDetailsView');
                        Map<String,Object> contactDetailsViewFieldsMap = (Map<String,Object>)(contactDetailsViewObjectFields);
                        
                        Object registrationInfoObjectFields = contactDetailsViewFieldsMap.get('RegistrationInfo');
                        Map<String,Object> registrationInfofieldsMap = (Map<String,Object>)(registrationInfoObjectFields);
                        
                        accessRecordWrapper.emailAddr = (String) registrationInfofieldsMap.get('EmailAddress');
                        accessRecordWrapper.firstName = (String) registrationInfofieldsMap.get('FirstName');
                        accessRecordWrapper.lastName = (String) registrationInfofieldsMap.get('LastName');
                        accessRecordWrapper.accesslevel = Decimal.valueOf((String)registrationInfofieldsMap.get('AccessLevel'));
                        accessRecordWrapper.ciscoUniversalId = (String) registrationInfofieldsMap.get('CISCOUniversalID');
                        accessRecordWrapper.ccoId = (String) registrationInfofieldsMap.get('CCOID');
                        accessRecordWrapper.jobTitle = (String) registrationInfofieldsMap.get('JobTitle');
                        
                        if(contactDetailsViewFieldsMap.get('PartnerBe') != null){
                            Object partnerBeAttrObjectFields = contactDetailsViewFieldsMap.get('PartnerBe');
                            Map<String,Object> partnerBeAttrfieldsMap = (Map<String,Object>)(partnerBeAttrObjectFields);
                            
                            Object partyAttrObjectFields = partnerBeAttrfieldsMap.get('Party');
                            Map<String,Object> partyAttrfieldsMap = (Map<String,Object>)(partyAttrObjectFields);    
                            
                            Object partyReferenceAttrObjectFields = partyAttrfieldsMap.get('PartyReference');
                            Map<String,Object> partyReferenceAttrObjectFieldsfieldsMap = (Map<String,Object>)(partyReferenceAttrObjectFields); 
                            
                            Object partyIdAttrObjectFields = partyReferenceAttrObjectFieldsfieldsMap.get('PartyID');
                            Map<String,Object> partyIdAttrObjectFieldsfieldsMap = (Map<String,Object>)(partyIdAttrObjectFields); 
                            
                            Object partyNameAttrObjectFields = partyReferenceAttrObjectFieldsfieldsMap.get('PartyName');
                            Map<String,Object> partyNameAttrObjectFieldsfieldsMap = (Map<String,Object>)(partyNameAttrObjectFields);
                            
                            
                            Object orgAttributesObjectFields = contactDetailsViewFieldsMap.get('OrgAttributes');
                            Map<String,Object> orgAttributesfieldsMap = (Map<String,Object>)(orgAttributesObjectFields);
                            
                            accessRecordWrapper.companyName = (String) partyNameAttrObjectFieldsfieldsMap.get('Name');
                            accessRecordWrapper.accountNumber = (String) partyIdAttrObjectFieldsfieldsMap.get('Identifier');
                        }
                        else if(accessRecordWrapper.accesslevel == 4){
                            accessRecordWrapper.companyName = 'Cisco';
                            accessRecordWrapper.accountNumber = '1000';
                        }
                        return accessRecordWrapper;
                    }
                }
            }
            return null;
        }catch (Exception ex) {
            system.debug('ex.getMessage() >'+ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        }
    }
    
    
    /**
    Description: Wrapper to show records data on UI
    **/
    public class AccessRecordWrapper{
        @AuraEnabled
        public String companyName {get;set;}
        @AuraEnabled
        public String accountNumber {get;set;}
        @AuraEnabled
        public String emailAddr {get;set;}
        @AuraEnabled
        public String firstName {get;set;}
        @AuraEnabled
        public String lastName {get;set;}
        @AuraEnabled
        public Decimal accesslevel {get;set;}
        @AuraEnabled
        public String ciscoUniversalId {get;set;}   
        @AuraEnabled
        public String ccoId {get;set;}  
        @AuraEnabled
        public String jobTitle {get;set;} 
    }
}
