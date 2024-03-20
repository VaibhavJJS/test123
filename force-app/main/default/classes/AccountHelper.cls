public class AccountHelper {
    Public static void PostData(Boolean isInsert,Boolean isUpdate,Boolean isDelete,List<Account> newEntries,Map<Id,Account> oldMapList,List<Account> oldEntries)
    {
        //VideoONE(newEntries);
        if(isUpdate)
        {
           VideoNine(newEntries,oldMapList); 
        }
        
    }
    
    Public static void afterPostData(Boolean isInsert,Boolean isUpdate,Boolean isDelete,List<Account> newEntries,Map<Id,Account> oldMapList,List<Account> oldEntries)
    {
       if(isInsert)
       {
          VideoFour(newEntries); 
          VideoEight(newEntries); //check
       }
        if(isUpdate)
        {
            VideoThirteen(newEntries,oldMapList);
            VideoSeventeen(newEntries,oldMapList);
        }
        
    }
     private static void VideoONE(List<Account> newEntry)
     {
         for(Account acc : newEntry)
         {
             dateTime d1 = acc.close_date__c;
             string dayOfWeek = d1.format('EEEE');
             integer days = d1.day();
             system.debug('d1'+d1);
             system.debug('dayOfWeek'+dayOfWeek);
             if(acc.Industry == 'Energy' || acc.Industry == 'Media')
             {
                 acc.Rating = 'Hot';
             }
         }
     }
    
    private static void VideoFour(List<Account> newEntry)
    {
        List<Contact> emptyCon = new list<Contact>();
        for(Account acc : newEntry)
        {
            contact con = new contact();
            con.LastName = acc.Name;
            con.AccountId = acc.Id;
            emptyCon.add(con);
        }
        
        Insert emptyCon;
    }
    private static void VideoEight(List<Account> newEntry)
    {
        List<Contact> emptyCon = new list<Contact>();
        List<Opportunity> emptyOpp = new list<Opportunity>();
        for(Account acc : newEntry)
        {
            if(acc.New_Contact__c == True)
            {
               contact con = new contact();
            con.LastName = acc.Name;
            con.AccountId = acc.Id;
            emptyCon.add(con); 
            }
            if(acc.New_Opportunity__c == True)
            {
                Opportunity opp = new Opportunity();
                opp.Name = 'Test';
               opp.StageName = 'Prospecting';
               opp.CloseDate = system.today();
               opp.Amount = 2000;
                emptyOpp.add(opp);
            }
        }
        Insert emptyCon;
        Insert emptyOpp;
    }
    
    private static void VideoNine(List<Account> newEntry,Map<Id,Account> oldMap)
    {
        for(Account acc : newEntry)
        {
            if(acc.Phone != oldMap.get(acc.Id).Phone)
            {
                acc.Description = 'Phone is updated old value is ' + oldMap.get(acc.Id).Phone + 'and updated value is ' + acc.Phone;
            }
        }
    }
    
    private static void VideoThirteen(List<Account> newEntry,Map<Id,Account> oldMap)
    {
        Map<Id,Account> accId = new Map<Id,Account>();
        List<Contact> empConList = new List<Contact>();
        for(Account acc : newEntry)
        {
            if(acc.Phone != oldMap.get(acc.Id).Phone)
            {
                accId.put(acc.Id,acc);
            }
        }
        
        List<Contact> conList = [SELECT Id,AccountId,HomePhone FROM Contact WHERE AccountId IN: accId.keyset()]; 
        for(Contact con : conList)
        {
            con.HomePhone = accId.get(con.AccountId).Phone;
            empConList.add(con);
        }
        
        update empConList;
    }
    
    private static void VideoSeventeen(List<Account> newEntry,Map<Id,Account> oldMap)
    {
        Map<Id,Account> accId = new Map<Id,Account>();
        List<Opportunity> empOppList = new List<Opportunity>();
        for(Account acc : newEntry)
        {
            if(acc.Active__c != oldMap.get(acc.Id).Active__c && acc.Active__c == 'No')
            {
                accId.put(acc.Id,acc);
            }
        }
        List<Opportunity> oppList = [SELECT Id,AccountId,StageName FROM Opportunity WHERE AccountId IN: accId.keyset() AND StageName != 'Closed Won']; 
        for(Opportunity opp : oppList)
        {
            opp.StageName = 'Closed Lost';
            empOppList.add(opp);
        }
        
        update empOppList;
    }

}