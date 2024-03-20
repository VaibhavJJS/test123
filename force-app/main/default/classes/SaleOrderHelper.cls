public class SaleOrderHelper 
{   
    private static final string FIELD_SALEORDER_OPPORTUNITYID = 'OpportunityId__c';

    public static void validateData(Boolean isInsert, Boolean isUpdate, Boolean isDelete, List<dmpl__SaleOrder__c> newEntries, List<dmpl__SaleOrder__c> oldEntries)
    {
        if(isInsert)
        {
            Map<Id, dmpl__SaleOrder__c> existingSaleOrders = new Map<Id, dmpl__SaleOrder__c>(querySaleOrders(extractIds(newEntries, FIELD_SALEORDER_OPPORTUNITYID), new List<Id>()));
            for(dmpl__SaleOrder__c lineEntry : newEntries)
            {
                if(isAlreadyUtilized(existingSaleOrders.values(), lineEntry.OpportunityId__c))
                    lineEntry.addError(System.label.Validation_OpportunityIsUtilized);
            }
        }
        
        if(isUpdate){
            validateOutstandingAmount(newEntries);
            List<dmpl__SaleOrder__c> modifiedObjects = DocumentHelper.getObjectsByFilter(DocumentHelper.getModifiedNewObjects('dmpl__Status__c',oldEntries,newEntries),'dmpl__Status__c','Booked');
           if(modifiedObjects.size()>0){
            validateAdvanceAmount(newEntries,oldEntries);
           } 
            
             List<dmpl__SaleOrder__c> approvedObjects= DocumentHelper.getObjectsByFilter(newEntries, 'dmpl__Status__c', 'Invoicing');
            approvedObjects = DocumentHelper.getObjectsByFilter(approvedObjects, 'PerformReleaseInvoice__c', true);
          if(approvedObjects.size()>0){
            validateReformReleaseInvoice(approvedObjects);
           } 
        }
    }

    public static void postData(Boolean isInsert, Boolean isUpdate, Boolean isDelete, List<dmpl__SaleOrder__c> newEntries, List<dmpl__SaleOrder__c> oldEntries)
    { 
        if(isInsert||isUpdate){
            servicablePostalCode(newEntries);
        }
        if(isInsert){
            setSaleExecutive(newEntries);
        }
        
        if(isUpdate){
            setAdvanceAmount(newEntries);
        }
    }

    public static void afterPostData(Boolean isInsert, Boolean isUpdate, Boolean isDelete, List<dmpl__SaleOrder__c> newEntries, List<dmpl__SaleOrder__c> oldEntries)
    {
        if(isInsert || isUpdate)
        {
          // getPurchaseOrdFromSO(newEntries);
        }
        if(isInsert)
        {
            getPurchaseOrdFromSO(newEntries);
        }
    }

    private static List<dmpl__SaleOrder__c> querySaleOrders(List<Id> saleOrderIds)
    {
        return[
            SELECT
            Id,
            Name,
            dmpl__AccountId__c,
            dmpl__AccountId__r.dmpl__Email__c
            From dmpl__SaleOrder__c
            WHERE Id IN : saleOrderIds
        ];
    }
    
    private static void setSaleExecutive(List<dmpl__SaleOrder__c> newEntries)
    {
        List<dmpl__Resource__c> getResource = [SELECT Id,dmpl__DefaultPartnerAccountId__c,dmpl__DefaultBranchId__c,dmpl__UserId__c 
                                               FROM dmpl__Resource__c 
                                               WHERE dmpl__DefaultPartnerAccountId__c IN:DocumentHelper.extractIds(newEntries, 'dmpl__PartnerAccountId__c') AND
                                               dmpl__DefaultBranchId__c IN:DocumentHelper.extractIds(newEntries, 'dmpl__BranchId__c') AND
                                               dmpl__UserId__c != null];
        
        for(dmpl__SaleOrder__c headerEntry:newEntries)
        {
            for(dmpl__Resource__c getResourceLoop:getResource)
            {
                if(headerEntry.dmpl__PartnerAccountId__c == getResourceLoop.dmpl__DefaultPartnerAccountId__c && 
                   headerEntry.dmpl__BranchId__c == getResourceLoop.dmpl__DefaultBranchId__c && 
                   getResourceLoop.dmpl__UserId__c != null && 
                   headerEntry.dmpl__SalesExecutiveId__c == null)
                {
                    //headerEntry.dmpl__SalesExecutiveId__c = getResourceLoop.dmpl__UserId__c;
                }
            }
        }
    }
    
    private static Boolean isAlreadyUtilized(List<dmpl__SaleOrder__c> existingSaleOrders, Id opportunityId)
    {
        for(dmpl__SaleOrder__c saleOrder : existingSaleOrders)
            if(saleOrder.OpportunityId__c == opportunityId)
            return true;
        
        return false;
    }
    
    /*private static void createServiceLeadOnBooking(List<dmpl__SaleOrder__c> newEntries, List<dmpl__SaleOrder__c> oldEntries){
        List<dmpl__ServiceLead__c> leads = new List<dmpl__ServiceLead__c>();
        for(dmpl__SaleOrder__c saleOrder : newEntries){
            dmpl__ServiceLead__c serviceLead = new dmpl__ServiceLead__c();
            {
                serviceLead.dmpl__BranchId__c = saleOrder.dmpl__BranchId__c;
                serviceLead.dmpl__PartnerAccountId__c = saleOrder.dmpl__PartnerAccountId__c;
                serviceLead.dmpl__LeadType__c = 'Extended Warranty';
                leads.add(serviceLead);
            }
            if(leads.size()>0){
                insert leads;
            }
        }
    }*/
    
    public static void validateOutstandingAmount(List<dmpl__SaleOrder__c> newEntries)
    {
        for(dmpl__SaleOrder__c order : newEntries){
            if(order.dmpl__OutstandingAmount__c > 0 && order.dmpl__status__c == 'Fulfilment'){
                  order.addError('Cannot Release For Fulfilment until Outstanding Amount is Paid.');              
            }
        }
    }
    
     public static void getPurchaseOrdFromSO(List<dmpl__SaleOrder__c> newEntries){
        List<dmpl__SaleOrder__c> soWithPurchaseOrd= DocumentHelper.getObjectsWithNotNull(newEntries,'PurchaseOrderId__c');
         system.debug('100');
        if(soWithPurchaseOrd.size()> 0){
            Map<Id,Id> mapPurchaseOrdIdVsSaleorderIds = new Map<Id,Id>();
            
            for(dmpl__SaleOrder__c saleOrder:soWithPurchaseOrd)
            {
                mapPurchaseOrdIdVsSaleorderIds.put(saleOrder.PurchaseOrderId__c,saleOrder.Id);
            }
            if(!System.isFuture() && !System.isBatch())
            {
                createSaleOrderLinesFromPurchaseOrder(mapPurchaseOrdIdVsSaleorderIds);
                system.debug('111');
            }
                
        }
    }
   @future
    public static void createSaleOrderLinesFromPurchaseOrder(Map<Id,Id> mapPurchaseOrdIdVsSaleorderIds){
        List<dmpl__SaleOrderLine__c> saleOrderLines = new List<dmpl__SaleOrderLine__c>();
        Map<Id,List<dmpl__PurchaseOrderLine__c>>  mapPurchaseOrdIdListPurchaseOrderLine = new Map<Id,List<dmpl__PurchaseOrderLine__c>>();
        List<dmpl__PurchaseOrderLine__c> purchaseOrder = [SELECT Id,dmpl__ItemId__c,dmpl__SKUId__c,dmpl__PendingQuantity__c,dmpl__TaxGroupId__c,dmpl__PurchaseOrderId__c,dmpl__UnitCost__c
                                                      FROM dmpl__PurchaseOrderLine__c
                                                      WHERE dmpl__PurchaseOrderId__c IN : mapPurchaseOrdIdVsSaleorderIds.keySet() AND dmpl__PendingQuantity__c > 0];
        
        system.debug('purchaseOrder'+purchaseOrder);
        for(dmpl__PurchaseOrderLine__c purchaseOLI : purchaseOrder){
                                                          
                                                          if(!mapPurchaseOrdIdListPurchaseOrderLine.containsKey(purchaseOLI.dmpl__PurchaseOrderId__c)){
                                                              mapPurchaseOrdIdListPurchaseOrderLine.put(purchaseOLI.dmpl__PurchaseOrderId__c, new List<dmpl__PurchaseOrderLine__c>());
                                                          }
                                                          mapPurchaseOrdIdListPurchaseOrderLine.get(purchaseOLI.dmpl__PurchaseOrderId__c).add(purchaseOLI);										  
                                                          
                                                      }
        
        system.debug('132');
        for(String purchaseId : mapPurchaseOrdIdListPurchaseOrderLine.keySet() ){
            for(dmpl__PurchaseOrderLine__c  purchaseOLI : mapPurchaseOrdIdListPurchaseOrderLine.get(purchaseId) ){
                if(mapPurchaseOrdIdVsSaleorderIds.containsKey(purchaseId) && mapPurchaseOrdIdVsSaleorderIds.get(purchaseId) != null ){ 
                    system.debug('136');
                    dmpl__SaleOrderLine__c saleOLI = new dmpl__SaleOrderLine__c();
                    saleOLI.dmpl__ItemId__c = purchaseOLI.dmpl__ItemId__c;
                    saleOLI.dmpl__SKUId__c = purchaseOLI.dmpl__SKUId__c;
                    saleOLI.dmpl__Quantity__c = purchaseOLI.dmpl__PendingQuantity__c;
                    saleOLI.dmpl__TaxGroupId__c = purchaseOLI.dmpl__TaxGroupId__c;
                    saleOLI.dmpl__PurchaseOrderLineId__c= purchaseOLI.Id;
                    saleOLI.dmpl__UnitPrice__c = purchaseOLI.dmpl__UnitCost__c;
                    if(mapPurchaseOrdIdVsSaleorderIds.containsKey(purchaseId)){
                        saleOLI.dmpl__SaleOrderId__c = mapPurchaseOrdIdVsSaleorderIds.get(purchaseId);
                    }
                    saleOrderLines.add(saleOLI);
                    
                }
            } 
        }
        if(saleOrderLines.size()>0){
            SecurityHelperCustom.ensureCanCreateObject('dmpl__SaleOrderLine__c');
            SecurityHelperCustom.ensureCanCreateFields(new List<String>{
                'dmpl__SKUId__c',
                    'dmpl__PurchaseOrderLineId__c',
                    'dmpl__ItemId__c',
                    'dmpl__SaleOrderId__c',
                    'dmpl__Quantity__c',
                    'dmpl__TaxGroupId__c'
                    }, 'dmpl__SaleOrderLine__c');   
            insert saleOrderLines;
        }
    }
    
    private static void servicablePostalCode(List<dmpl__SaleOrder__c> newEntries)
    {
        List<String> postalCodeIds = extractIds(newEntries, 'dmpl__BillingPostalCode__c');
        List<dmpl__PostalCode__c> postalCodes = [Select Id,Name,dmpl__City__c,dmpl__Country__c,dmpl__Region__c,dmpl__State__c from dmpl__PostalCode__c Where Name IN: postalCodeIds];

        for(dmpl__SaleOrder__c order : newEntries)
        {
            for(dmpl__PostalCode__c postalCode : postalCodes)
                {
                    if(order.dmpl__BillingPostalCode__c == postalCode.Name)
                    {
                        order.dmpl__BillingRegion__c = postalCode.dmpl__Region__c;
                        order.dmpl__BillingState__c = postalCode.dmpl__State__c;
                        order.dmpl__BillingCity__c = postalCode.dmpl__City__c;
                        order.dmpl__BillingCountry__c = postalCode.dmpl__Country__c;
                    }
                }
            }
    }
@TestVisible
     private static void validateReformReleaseInvoice(List<dmpl__SaleOrder__c> newEntries)
    {
        Map<Id, dmpl__SaleOrder__c> entriesMap = new Map<Id, dmpl__SaleOrder__c>(newEntries);
        List<dmpl__SaleOrderLine__c> soLines = querySOLines(DocumentHelper.extractIds(newEntries,'Id'));
        if(soLines.size()>0){
            for(dmpl__SaleOrderLine__c lineEntry : soLines){
               	dmpl__SaleOrder__c currentSO = entriesMap.get(lineEntry.dmpl__SaleOrderId__c);
                currentSO.addError('Pending Fulfilment Allocation Quantity should be zero for Releasing Order');
            }
        }
        for(dmpl__SaleOrder__c saleOrder : newEntries){
            saleOrder.PerformReleaseInvoice__c = FALSE;
        }
    }
    
    private static List<dmpl__SaleOrderLine__c> querySOLines(List<Id> saleOrderIds)
    {
        return[
            SELECT
            Id, dmpl__SaleOrderId__c
            From dmpl__SaleOrderLine__c
            WHERE dmpl__SaleOrderId__c IN : saleOrderIds
            AND dmpl__PendingFulfilmentAllocationQuantity__c > 0
            AND dmpl__ItemId__r.dmpl__TrackInventory__c = true
        ];
    }
    private static List<dmpl__SaleOrder__c> querySaleOrders(List<Id> opportunityIds, List<Id> saleOrderIds)
    {   
        return [SELECT Id, 
                Name,
                OpportunityId__c,
                OpportunityId__r.OwnerId,     
                dmpl__PartnerAccountId__c,
                //dmpl__PartnerAccountId__r.WarehouseBranchId__c,
                dmpl__BranchId__c, 
                dmpl__TotalOrderAmount__c,
                dmpl__OutstandingAmount__c,
                dmpl__Status__c,
                (SELECT 
                 Id,
                 Name
                //  IsReceivedByHMCL__c,
                //  IsPreBookingCancelled__c
                 FROM dmpl__Payments__r
                ),
                (
                    SELECT
                    dmpl__ItemId__c,
                    dmpl__PendingFulfilmentOrderQuantity__c,
                    dmpl__Quantity__c,
                    dmpl__ItemId__r.Name,
                    //dmpl__ItemId__r.DisableInvoicing__c,
                    dmpl__ItemId__r.dmpl__TrackInventory__c,
                    dmpl__SKUId__c 
                    FROM
                    dmpl__SaleOrderLines__r
                )
                FROM dmpl__SaleOrder__c
                WHERE OpportunityId__c IN : opportunityIds OR Id IN : saleOrderIds];
    }

    public static void createSaleOrderFromOpportunity(List<Opportunity> opportunities)
    {
        createSaleOrders(opportunities);
    }
    
    public static void validateAdvanceAmount(List<dmpl__SaleOrder__c> newEntries, List<dmpl__SaleOrder__c> oldEntries)
    {
        for(dmpl__SaleOrder__c order : newEntries){
            if(order.dmpl__AdvanceAmount__c == null || order.dmpl__AdvanceAmount__c < 500 ){
                order.addError('Cannot Book Order Without Advance Amount.');
            }
        }
    }
    
    public static void setAdvanceAmount(List<dmpl__SaleOrder__c> newEntries)
    {
        for(dmpl__SaleOrder__c order : newEntries){
            if(order.dmpl__AdvanceAmount__c == null && order.dmpl__TotalCreditAmount__c > 0 ){
                order.dmpl__AdvanceAmount__c = order.dmpl__TotalCreditAmount__c;
            }
        }
    }

    @testVisible
    private static void createSaleOrders(List<Opportunity> opportunities) 
    {
        Set<Id> opportunityId = new Set<Id>();
        Map<Id, Id> saleOrderIdMap = new Map<Id, Id>(); 
        List<dmpl__SaleOrder__c> fetchedSaleOrders = new List<dmpl__SaleOrder__c>();
        List<dmpl__SaleOrderLine__c> newSaleOrderLines = new List<dmpl__SaleOrderLine__c>();
        List<dmpl__OpportunityLine__c> opptyLines = new List<dmpl__OpportunityLine__c>();
        Map<Id,List<dmpl__OpportunityLine__c>> mapOfOpptyLines = new Map<Id,List<dmpl__OpportunityLine__c>>();
        List<dmpl__SaleOrder__c> newSaleOrders = new List<dmpl__SaleOrder__c>();
        List<dmpl__Resource__c> resources = queryResources(UserInfo.getUserId());
        for(Opportunity opportunity : opportunities)
        {
            dmpl__Resource__c currentResource = getResource(resources, UserInfo.getUserId());
            ExceptionLogHelper.logMessage('currentResource '+currentResource);
            if(currentResource == null){
                opportunity.addError('You are not eligible to convert opportunity to Sale Order, Kindly contact your administrator!');
            }
            else{
            newSaleOrders.add(new dmpl__SaleOrder__c(
                dmpl__PartnerAccountId__c = opportunity.dmpl__PartnerAccountId__c,
                dmpl__BranchId__c = opportunity.dmpl__BranchId__c,
                dmpl__AccountId__c = opportunity.AccountId,
                dmpl__RequiredDate__c = opportunity.dmpl__TentativeBuyingDate__c,
                dmpl__SalesExecutiveId__c = currentResource == null ? null : currentResource.Id,
                //OwnerId = currentResource.dmpl__UserId__c,
                OpportunityId__c = opportunity.Id,
                dmpl__BillingPostalCode__c = opportunity.dmpl__PostalCode__c,
                dmpl__ContactId__c = opportunity.ContactId__c,
                dmpl__BillingCity__c = opportunity.dmpl__City__c,
                dmpl__BillingState__c = opportunity.dmpl__State__c
            ));
                opportunityId.add(opportunity.Id);
                
        }
        }
        if(newSaleOrders.size() > 0)
        {   ExceptionLogHelper.logMessage('newSaleOrders '+newSaleOrders);
            insert newSaleOrders;   
        }
        system.debug(opportunityId);
        if(opportunityId != null && !opportunityId.isEmpty()){
            createSaleOrderLinesForOpportunity(opportunityId);
          
    }
    }
    
    @Future private static void createSaleOrderLinesForOpportunity(Set<Id> opportunityId)
    {
        Map<Id, Id> saleOrderIdMap = new Map<Id, Id>();
        Set<Id> itemIdSet = new Set<Id>();
        
        List<dmpl__SaleOrder__c> fetchedSaleOrders = new List<dmpl__SaleOrder__c>();
        List<dmpl__SaleOrderLine__c> newSaleOrderLines = new List<dmpl__SaleOrderLine__c>();
        List<dmpl__OpportunityLine__c> opptyLines = new List<dmpl__OpportunityLine__c>();
        Map<Id,List<dmpl__OpportunityLine__c>> mapOfOpptyLines = new Map<Id,List<dmpl__OpportunityLine__c>>();
        opptyLines = [SELECT
                    dmpl__Amount__c,
                    dmpl__Discount__c,
                    dmpl__DiscountAmount__c,
                    dmpl__ItemComponentId__c,
                    dmpl__ItemId__c,
                    dmpl__OpportunityId__c,
                    dmpl__PackageOpportunityLineId__c,
                    dmpl__Quantity__c,
                    dmpl__SKUId__c,
                    dmpl__UnitPrice__c,
                    dmpl__ItemComponentId__r.dmpl__IsSelected__c,
                    dmpl__ItemComponentId__r.dmpl__IsMandatory__c,
                    Id,
                    Name,
                    OwnerId,
                    dmpl__ItemId__r.dmpl__itemtype__c
                    FROM
                    dmpl__OpportunityLine__c
                     WHERE dmpl__OpportunityId__c IN:opportunityId];
        system.debug(opptyLines);
        for(dmpl__opportunityline__c opportunityLine : opptyLines){
            itemIdSet.add(opportunityLine.dmpl__ItemId__c);
        }
        Map<Id, dmpl__item__c> mapOfItem = new Map<Id, dmpl__item__c>([SELECT ID, dmpl__itemType__c FROM dmpl__item__c WHERE ID IN:itemIdSet]);
       
        fetchedSaleOrders = [SELECT ID, opportunityId__c From dmpl__saleorder__c WHERE opportunityid__c IN:opportunityId];
        system.debug(fetchedSaleOrders);
        for(dmpl__saleOrder__c order : fetchedSaleOrders){
            saleOrderIdMap.put(order.OpportunityId__c,order.id);
        }
        system.debug(saleOrderIdMap);
        for(dmpl__opportunityline__c opportunityLine : opptyLines){
            system.debug(opportunityLine.dmpl__OpportunityId__c);
            if(opportunityId.contains(opportunityLine.dmpl__OpportunityId__c) && opportunityLine.dmpl__PackageOpportunityLineId__c == null || (opportunityLine.dmpl__ItemComponentId__c != null && !opportunityLine.dmpl__ItemComponentId__r.dmpl__IsSelected__c && !opportunityLine.dmpl__ItemComponentId__r.dmpl__IsMandatory__c)){
                Decimal quantity = opportunityLine.dmpl__Quantity__c == null ? 0 : opportunityLine.dmpl__Quantity__c;
                Integer quant = Integer.valueOf(quantity);
                dmpl__item__c items = mapOfItem.get(opportunityLine.dmpl__ItemId__c);
                if(items.dmpl__itemType__c == 'Product'){
                    system.debug('Check'+items);
                for (Integer i = 0; i < quant; i++) {
                newSaleOrderLines.add(new dmpl__SaleOrderLine__c(
                            dmpl__ItemId__c = opportunityLine.dmpl__ItemId__c,
                            dmpl__Quantity__c = 1,
                            dmpl__SaleOrderId__c = saleOrderIdMap.get(opportunityLine.dmpl__OpportunityId__c),
                            dmpl__DiscountAmount__c = opportunityLine.dmpl__DiscountAmount__c,
                            //dmpl__UnitPrice__c = opportunityLine.dmpl__UnitPrice__c,
                            OpportunityLineId__c = opportunityLine.Id,
                            dmpl__ItemComponentId__c = opportunityLine.dmpl__ItemComponentId__c
                        ));
            }
            }
                else if(items.dmpl__itemType__c != 'Product'){
                    newSaleOrderLines.add(new dmpl__SaleOrderLine__c(
                            dmpl__ItemId__c = opportunityLine.dmpl__ItemId__c,
                            dmpl__Quantity__c = opportunityLine.dmpl__Quantity__c == null ? 0 : opportunityLine.dmpl__Quantity__c,
                            dmpl__SaleOrderId__c = saleOrderIdMap.get(opportunityLine.dmpl__OpportunityId__c),
                            dmpl__DiscountAmount__c = opportunityLine.dmpl__DiscountAmount__c,
                            //dmpl__UnitPrice__c = opportunityLine.dmpl__UnitPrice__c,
                            OpportunityLineId__c = opportunityLine.Id,
                            dmpl__ItemComponentId__c = opportunityLine.dmpl__ItemComponentId__c
                        ));
                    
                }   
            }
            

        }
        system.debug(newSaleOrderLines);
        if(newSaleOrderLines.size() > 0)
        {
           
            insert newSaleOrderLines;
        }
       
    }    
 
 
    /* private static void createRelatedRecordsFromOpportunity(List<dmpl__SaleOrder__c> newSaleOrders)
    {
        List<Opportunity> relatedOpportunities = queryOpportunities(DocumentHelper.extractIds(newSaleOrders, 'OpportunityId__c'));
        SaleOrderLineHelper.createSaleOrderLinesFromOpportunity(relatedOpportunities, newSaleOrders);
    }*/    

    private static List<String> extractIds(List<SObject> records, string fieldName)
    {
        List<String> resultIds = new List<String>();
        for(SObject record : records){
            if(record.get(fieldName) != null && !resultIds.contains((String)record.get(fieldName))){
                resultIds.Add((String)record.get(fieldName));
            }
        }
        return resultIds;
    }

    private static dmpl__Resource__c getResource(List<dmpl__Resource__c> resources, Id salesExecutiveUserId)
    {
        for(dmpl__Resource__c resource : resources)
            if(resource.dmpl__UserId__c == salesExecutiveUserId)
            return resource;
        
        return null;
    }

    private static List<dmpl__Resource__c> queryResources(Id currentUserId)
    {
        return [SELECT Id,
                Name,
                dmpl__DefaultBranchId__c,
                dmpl__DefaultPartnerAccountId__c,
                dmpl__EffectiveFromDate__c,
                dmpl__EffectiveTillDate__c,
                dmpl__ExternalId__c,
                dmpl__IsActive__c,
                OwnerId,
                dmpl__Phone__c,
                dmpl__ResourceType__c,
                dmpl__UserId__c
                FROM dmpl__Resource__c
                //WHERE dmpl__UserId__c IN : resourceIds
                WHERE dmpl__UserId__c = : currentUserId
                AND dmpl__IsActive__c = true
                AND dmpl__UserId__r.IsActive = true
                ORDER BY ID DESC];
    }

    private static List<Opportunity> queryOpportunities(List<Id> opportunityIds)
    {   
        return [SELECT
                AccountId,
                // AlternateMobileNumber__c,
                 Amount,
                 CampaignId,
                // CancellationReason__c,
                // CloseDate,
                // Contact__c,
                ContactId,
                ContractId,
                CreatedById,
                CreatedDate,
                Description,
                //Discovery_Completed__c,
                //District__c,
                dmpl__Age__c,
                dmpl__AnnualIncome__c,
                dmpl__AreaLocality__c,
                dmpl__BranchId__c,
                dmpl__City__c,
                dmpl__Country__c,
                dmpl__DateOfBirth__c,
                dmpl__DiscountGroupId__c,
                dmpl__DocumentDate__c,
                dmpl__EducationalQualification__c,
                dmpl__Email__c,
                dmpl__ExpectedEMI__c,
                dmpl__FamilyMembersCount__c,
                dmpl__FeaturesInterested__c,
                dmpl__Gender__c,
                dmpl__Industry__c,
                dmpl__InterestedInFinance__c,
                dmpl__InterestedInInsurance__c,
                dmpl__InterestedInTradeIn__c,
                dmpl__LeadCampaignId__c,
                dmpl__LeadDate__c,
                dmpl__LeadId__c,
                dmpl__LostReason__c,
                dmpl__LostSubReason__c,
                dmpl__Make__c,
                dmpl__Mobile__c,
                dmpl__MobilePhone__c,
                dmpl__Model__c,
                dmpl__Occupation__c,
                dmpl__PartnerAccountId__c,
                dmpl__PostalCode__c,
                dmpl__PreferredFinancerId__c,
                dmpl__PreferredInsurerId__c,
                dmpl__PriceListId__c,
                dmpl__ProductInterestedId__c,
                dmpl__ProductInterestedValue__c,
                dmpl__Purpose__c,
                dmpl__Rating__c,
                dmpl__Region__c,
                dmpl__SalesExecutiveId__c,
                dmpl__SKUId__c,
                dmpl__State__c,
                dmpl__TentativeBudget__c,
                dmpl__TentativeBuyingDate__c,
                dmpl__TotalAmount__c,
                dmpl__TradeInExpectedValuation__c,
                dmpl__TradeInMakeYear__c,
                dmpl__TradeInProductBrand__c,
                dmpl__TradeInProductModel__c,
                //ExistingVehicle__c,
                ExpectedRevenue,
                //FinanceStatus__c,
                Fiscal,
                FiscalQuarter,
                FiscalYear,
                ForecastCategory,
                ForecastCategoryName,
                HasOpenActivity,
                HasOpportunityLineItem,
                HasOverdueTask,
                Id,
                IsClosed,
                //IsCreatedFromLead__c,
                IsDeleted,
                IsPrivate,
                //IsSaleOrderCreated__c,
                IsWon,
                LastActivityDate,
                LastAmountChangedHistoryId,
                LastCloseDateChangedHistoryId,
                LastModifiedById,
                LastModifiedDate,
                LastReferencedDate,
                LastViewedDate,
                LeadSource,
                Name,
                NextStep,
                OwnerId,
                Pricebook2Id,
                Probability,
                // ProductConfigurationDate__c,
                // Remarks__c,
                StageName,
                SyncedQuoteId,
                SystemModstamp,
                // Tehsil__c,
                TotalOpportunityQuantity,
                Type,
                (
                    SELECT
                    dmpl__Amount__c,
                    dmpl__Discount__c,
                    dmpl__DiscountAmount__c,
                    dmpl__ItemComponentId__c,
                    dmpl__ItemId__c,
                    dmpl__OpportunityId__c,
                    dmpl__PackageOpportunityLineId__c,
                    dmpl__Quantity__c,
                    dmpl__SKUId__c,
                    dmpl__UnitPrice__c,
                    dmpl__ItemComponentId__r.dmpl__IsSelected__c,
                    dmpl__ItemComponentId__r.dmpl__IsMandatory__c,
                    Id,
                    Name,
                    OwnerId
                    FROM
                    dmpl__OpportunityLines__r
                )
                FROM
                Opportunity WHERE Id IN : opportunityIds];
    }
}