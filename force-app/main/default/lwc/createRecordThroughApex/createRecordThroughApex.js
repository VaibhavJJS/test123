import { LightningElement } from 'lwc';
import getSessional from '@salesforce/apex/CreateSessional.createDSARecord';

let timeoutId;
const debounce = (callback, delay) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(callback, delay);
};

export default class CreateRecordThroughApex extends LightningElement {

    nameApex='';
    dsaApex='';

    handleInputData(event){
        const storeName = event.target.name;
        if(storeName === 'Fname'){
           this.nameApex = event.target.value;
        }
        if(storeName === 'phone'){
            this.dsaApex = event.target.value;
        }
        
        //debounce(this.storeData.bind(this), 300);
    }

    // handleInputDataDSA(event){
    //     this.dsaApex = event.target.value;
    //     //debounce(this.storeData.bind(this), 300);
    // }

    storeData(){
        getSessional({name : this.nameApex,dsa : parseFloat(this.dsaApex)})
        .then(()=>{
            console.log('data check');
            this.nameApex='';
            this.dsaApex='';
        })
        .catch(error =>{
        console.error(error);
        });
       
    }
}