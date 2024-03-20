import { LightningElement, api } from 'lwc';
import ID_FIELD from '@salesforce/schema/DealerOpportunity__c.Id';
import MOBILE_FIELD from '@salesforce/schema/DealerOpportunity__c.Mobile__c';
import { updateRecord } from 'lightning/uiRecordApi';
import getDealerOpportuntityDetail from '@salesforce/apex/DealerOpportunityStatusConfirmation.updateDealerOpportunity'

export default class ModalPopup extends LightningElement {
    @api recordId;
    //@api showModal;
    @api fieldApiName;
    showModal = true;
    dealerOppDetail = '';
    
    handleCancel() {
        this.showModal = false;
        this.updateField('None');
        
    }

    handleReject() {
        this.showModal = true;
        this.updateField('Rejected');
        this.fetchAccountDetail();
    }

    fetchAccountDetail(){
        console.log('recordId '+this.recordId);
        getDealerOpportuntityDetail({recordId:this.recordId})
        .then(result =>{
            this.dealerOppDetail = result
            console.log(this.accDetail);
            })
            .catch(error=>{
                console.log(error);
            });

        //     const fields = {};
        // fields[ID_FIELD.fieldApiName] = this.recordId;
        // fields[MOBILE_FIELD.fieldApiName] = '9991118880';

        // const recordInput = {fields};
        // updateRecord(recordInput)
        // .then(account =>{
        //     console.log(account);
        //     //this.showToast('Success','Record Updated :- ' + this.accName + 'for account','success');
            
        // })
        // .catch(error=>{
        //     console.error('error');
        // })
    }
    
    
    updateField(value) {
        const fields = {};
        fields.Id = this.recordId;
        fields[this.fieldApiName] = value;

        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {
                // Field updated successfully
            })
            .catch(error => {
                console.error('Error updating field:', error);
            });
    }
}