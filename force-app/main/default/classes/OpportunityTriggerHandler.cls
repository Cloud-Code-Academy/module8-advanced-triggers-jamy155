public with sharing class OpportunityTriggerHandler extends TriggerHandler {

    private List<Opportunity> newOppList;
    private List<Opportunity> oldOppList;
    private Map<Id, Opportunity> newOppMap;
    private Map<Id, Opportunity> oldOppMap;

    public OpportunityTriggerHandler() {
        this.newOppList = (List<Opportunity>) Trigger.new;
        this.oldOppList = (List<Opportunity>) Trigger.old;
        this.newOppMap = (Map<Id, Opportunity>) Trigger.newMap;
        this.oldOppMap = (Map<Id, Opportunity>) Trigger.oldMap;
       // this.setMaxLoopCount(1);

    }
    
    public override void beforeInsert() {
        // Set default Type for new Opportunities
        for (Opportunity opp : this.newOppList) {
            if (opp.Type == null){
                opp.Type = 'New Customer';
            }  
        }
    }

    public override void beforeUpdate() {
        
        for(Opportunity opp : this.newOppList){
            if(opp.Amount < 5000){
                opp.addError('Opportunity amount must be greater than 5000');
            }
        }

        //When an opportunity is updated set the primary contact on the opportunity to the contact with the title of 'CEO'.
        //Get contacts related to the opportunity account
        Set<Id> accountIds = new Set<Id>();
        for(Opportunity opp : this.newOppList){
            accountIds.add(opp.AccountId);
        }
        
        Map<Id, Contact> contacts = new Map<Id, Contact>([SELECT Id, FirstName, AccountId FROM Contact WHERE AccountId IN :accountIds AND Title = 'CEO' ORDER BY FirstName ASC]);
        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();

        for (Contact cont : contacts.values()) {
            if (!accountIdToContact.containsKey(cont.AccountId)) {
                accountIdToContact.put(cont.AccountId, cont);
            }
        }

        for(Opportunity opp : this.newOppList){
            if(opp.Primary_Contact__c == null){
                if (accountIdToContact.containsKey(opp.AccountId)){
                    opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
                }
            }
        }
    }

    public override void beforeDelete() {
     // Prevent deletion of closed Opportunities
        for (Opportunity oldOpp : this.oldOppList){
            if (oldOpp.IsClosed){
                oldOpp.addError('Cannot delete closed opportunity');
            } 
        }

        //When an opportunity is deleted prevent the deletion of a closed won opportunity if the account industry is 'Banking'.
        //Account related to the opportunities 
        Map<Id, Account> accounts = new Map<Id, Account>([  SELECT Id, Industry 
                                                            FROM Account 
                                                            WHERE Id 
                                                            IN (SELECT AccountId FROM Opportunity WHERE Id IN :this.oldOppList)]);
        for(Opportunity opp : this.oldOppList){
            if(opp.StageName == 'Closed Won'){
                if(accounts.get(opp.AccountId).Industry == 'Banking'){
                    opp.addError('Cannot delete closed opportunity');
                }
            }
        }
    }

    public override void afterInsert(){
        // Create a new Task for newly inserted Opportunities
        List<Task> taskToInsert = new List<Task>();
            for (Opportunity opp : this.newOppList){
                Task tsk = new Task();
                tsk.Subject = 'Call Primary Contact';
                tsk.WhatId = opp.Id;
                tsk.WhoId = opp.Primary_Contact__c;
                tsk.OwnerId = opp.OwnerId;
                tsk.ActivityDate = Date.today().addDays(3);
                taskToInsert.add(tsk);   
            }
            insert taskToInsert;
    }

    public override void afterUpdate() {

         // Append Stage changes in Opportunity Description
            List<Opportunity> oppToUpdate = new List<Opportunity>();
                for (Opportunity opp : this.newOppMap.values()){
                    if (opp.StageName != null && this.oldOppMap.get(opp.Id).StageName != this.newOppMap.get(opp.Id).StageName){  
                        Opportunity newOpp = new Opportunity(id = opp.Id);
                        newOpp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                        oppToUpdate.add(newOpp);
                        }               
                }
            update oppToUpdate;
        }

    public override void afterDelete() {
        OpportunityHelper.notifyOwnersOpportunityDeleted(this.oldOppList);
    }

    public override void afterUndelete() {
        OpportunityHelper.assignPrimaryContact(this.newOppMap);
    }
}