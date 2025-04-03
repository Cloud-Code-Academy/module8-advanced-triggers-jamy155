public with sharing class OpportunityHelper {

    public static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        
        Set<String> ownerIds = new Set<String>();
        for (Opportunity opp : opps) {
            ownerIds.add(opp.OwnerId);
        }

        Map <Id, User> owners = new Map<Id, User>([SELECT Id, Email FROM User WHERE Id IN :ownerIds]);

        
        
        for (Opportunity opp : opps){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[]{};
            toAddresses.add(owners.get(opp.OwnerId).Email);
            mail.setToAddresses(toAddresses);
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }        
        
        try {
            Messaging.sendEmail(mails);
        } catch (Exception e){
            System.debug('Exception: ' + e.getMessage());
        }
        System.debug('**** Mails Sent *****');
    }

    public static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {        
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        Set<Id> accountIds = new Set<Id>();

        for (Opportunity opp : oppNewMap.values()){
            accountIds.add(opp.AccountId);
        }
        List<Contact> contacts = new List<Contact>([SELECT Id, AccountId FROM Contact WHERE AccountId IN :accountIds AND Title = 'VP Sales']);



        for (Opportunity opp : oppNewMap.values()){            
           // Contact primaryContact = [SELECT Id, AccountId FROM Contact WHERE Title = 'VP Sales' AND AccountId = :opp.AccountId LIMIT 1];
            Contact primaryContact = null;
            for (Contact con : contacts){
                if (con.AccountId == opp.AccountId){
                    primaryContact = con;
                    break;
                }
            }
            if (opp.Primary_Contact__c == null){
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                oppToUpdate.Primary_Contact__c = primaryContact.Id;
                oppMap.put(opp.Id, oppToUpdate);
            }
        }
        update oppMap.values();
    }

}