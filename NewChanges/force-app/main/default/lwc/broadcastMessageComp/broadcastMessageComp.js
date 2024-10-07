import { LightningElement, track, wire, api } from 'lwc';
import getBroadcastRecord from '@salesforce/apex/BroadcastMessageController.getBroadcastRecord';
import hasPhoneField from '@salesforce/apex/BroadcastMessageController.hasPhoneField';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchUserSessionId from '@salesforce/apex/ApiCallLightningComponent.fetchUserSessionId';
import getTemplateRecords from '@salesforce/apex/WhatsappChatController.getTemplateRecords';
import getListViews from '@salesforce/apex/BroadcastMessageController.getListViews';
import getListViewRecords from '@salesforce/apex/BroadcastMessageController.getListViewRecords';
import sendTemplateMessage from '@salesforce/apex/BroadcastMessageController.sendTemplateMessage';
import scheduleTemplateMessage from '@salesforce/apex/BroadcastMessageController.scheduleTemplateMessage';
import { loadStyle } from 'lightning/platformResourceLoader';
import COLORS from '@salesforce/resourceUrl/datatableStyle';
import { NavigationMixin } from 'lightning/navigation';
import MulishFontCss from '@salesforce/resourceUrl/MulishFontCss';

const columns = [
    { label: 'Broadcast Name', fieldName: 'recordLink', hideDefaultActions: 'true', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
    { label: 'Created At', fieldName: 'CreatedDate', hideDefaultActions: 'true', cellAttributes: { class: { fieldName: 'createdClass' } } },
    { label: 'Recipients', fieldName: 'Recipient', hideDefaultActions: 'true', cellAttributes: { class: { fieldName: 'recipientClass' }, iconName: 'utility:user' } },
    { label: 'Sent', fieldName: 'Sent', hideDefaultActions: 'true', cellAttributes: { class: { fieldName: 'sentClass' }, iconName: 'utility:routing_offline' } },
    { label: 'Delivered', fieldName: 'Delivered', hideDefaultActions: 'true', cellAttributes: { class: { fieldName: 'deliveredClass' }, iconName: 'utility:routing_offline' } },
    { label: 'Read', fieldName: 'Read', hideDefaultActions: 'true', cellAttributes: { class: { fieldName: 'readClass' }, iconName: 'utility:routing_offline' } },
    {
        label: 'Failed', fieldName: 'Failed', hideDefaultActions: 'true',
        cellAttributes: { class: { fieldName: 'failedClass' }, iconName: 'utility:routing_offline' }
    },
];

const recordcol = [
    { label: 'Name', fieldName: 'Name', hideDefaultActions: 'true' },
    { label: 'WhatsApp Phone', fieldName: 'WhatsApp_Phone__c' , hideDefaultActions: 'true'}
];
const selectedrecordcol = [
    { label: 'Name', fieldName: 'Name' , hideDefaultActions: 'true'},
    { label: 'WhatsApp Phone', fieldName: 'WhatsApp_Phone__c', hideDefaultActions: 'true' },
    { label: 'Type', fieldName: 'ObjectName' , hideDefaultActions: 'true'},
    { fieldName: 'delete', type: 'button', hideDefaultActions: 'true', innerWidth: 20, typeAttributes: { variant: "base", name: 'delete', iconName: 'utility:delete', }, cellAttributes: { alignment: 'center' } }

];


export default class BroadcastMessageComp extends NavigationMixin(LightningElement) {

    @track data = [];
    @track recorddata = [];
    @track allRecords = [];
    @track sessionId = '';
    @track paginatedRecorddata = [];
    @track paginatedBroadcast = [];
    @track selectedRecords = [];
    @track listViewOptions = [];
    @track paginatedSelectedRecords = [];
    selectedRows = [];
    selectedRowsTemp = [];
    columns = columns;
    @track recordcol = recordcol;
    @track selectedrecordcol = selectedrecordcol;
    record = {};
    // @track objectOptions = [
        // { label: 'Account', value: 'Account' },
        // { label: 'Contact', value: 'Contact' },
        // { label: 'Lead', value: 'Lead' },
        // { label: 'User', value: 'User' },
        // { label: 'Listing', value: 'Listing__c' },
        // { label: 'Opportunity', value: 'Opportunity' }
    // ];
    @track selectedObject = 'Contact';
    @track hasRecords = false;
    @track broadcastEdited = false;
    @track currentPage = 1;
    @track pageSize = 10;
    @track currentPage2 = 1;
    @track pageSize2 = 5;
    @track currentBroadcast = 1;
    @track selectedListView;
    @track templateId;
    @track hasBroadcast = false;
    @track broadcastRecord = true;
    @track hasBroadcastRecord = false;
    @track noselected = true;
    @track showTemplate = false;
    @track selectedPhoneNumbers;
    @track selectedContactIds;
    phoneNumberToIdMap = new Map();
    @track isLoading = false;
    @track alldata = [];
    @track selectedRecord = false;
    @track templateHeader = '';
    @track templateBody = '';
    @track templateFooter = '';
    @track today;
    @track minTime;
    @track selectedDate = '';
    @track selectedTime = '';
    @track nameMatches;
    @track phoneMatches;
    @track searchTerm;
    @track isShowSchedule = false;
    @track isShowNextSchedule = false;
    @track isMainModal = true;

    connectedCallback() {
        this.isLoading = true;
        loadStyle(this, MulishFontCss)
        .then(() => {
            console.log('Css loaded successfully');
        })
        .catch(error => {
            console.log('Error loading style:', error);
        });
        fetchUserSessionId()
            .then(result => {
                this.sessionId = result;
            })
            .catch(error => {
                console.error('Error fetching user session:', error.body);
            });

        this.getBroadcastRecords();
        this.updatePaginatedBroadcast();
        this.isLoading = false;
        this.updatePaginatedData();
        this.updatePaginatedSelectedData();
        this.handleObjectChange();
    }
    renderedCallback() {
        if (this.isCssLoaded) return
        this.isCssLoaded = true
        loadStyle(this, COLORS).then(() => {
            console.log("Loaded Successfully")
        }).catch(error => {
            console.error("Error in loading the colors")
        })
        this.setMinDate();
    }

    getBroadcastRecords() {
        getBroadcastRecord()
            .then((result) => {
                // this.data = result;
                this.data = this.processData(result);
                console.log('data==> ', this.data);

                if (this.data != '') {
                    this.updatePaginatedBroadcast();
                    this.hasBroadcastRecord = true;
                }
                console.log('sucess to load data.');
            })
            .catch(error => {
                console.error('error: ', error.body.message);
            });
    }

    handleBroadcast() {
        this.hasBroadcast = true;
        this.broadcastRecord = false;
    }


    processData(records) {
        const options = { month: 'short', day: 'numeric', hour: 'numeric', minute: 'numeric', hour12: true };
        const formatter = new Intl.DateTimeFormat('en-US', options);

        return records.map(record => {
            return {
                ...record,
                "recordLink": record.Id ? `/${record.Id}` : '',
                "CreatedDate": record.CreatedDate ? formatter.format(new Date(record.CreatedDate)) : '',
                "Recipient": record.Recipients__c || '0',
                "Sent": record.Sent__c ? `${record.Sent__c}%` : '0%',
                "Delivered": record.Delivered__c ? `${record.Delivered__c}%` : '0%',
                "Read": record.Read__c ? `${record.Read__c}%` : '0%',
                "Failed": record.Failed__c ? `${record.Failed__c}%` : '0%',
                "recipientClass": "datatable-recipient table",
                "sentClass": 'datatable-sent table',
                "deliveredClass": 'datatable-delivered table',
                "readClass": 'datatable-read table',
                "failedClass": 'datatable-failed table slds-icon_large'
            };
        });
    }

    updatePaginatedBroadcast() {
        const recordArray = Array.from(this.data);
        const startIdx = (this.currentBroadcast - 1) * this.pageSize;
        const endIdx = this.currentBroadcast * this.pageSize;

        this.paginatedBroadcast = recordArray.slice(startIdx, Math.min(endIdx, recordArray.length));

        if (this.paginatedBroadcast.length === 0 && this.currentBroadcast > 1) {
            this.currentBroadcast--;
            this.updatePaginatedBroadcast();
        }
    }

    @wire(getListViews, { objectName: '$selectedObject' })
    wiredListViews({ error, data }) {
        if (data) {
            this.listViewOptions = data.map(option => ({
                label: option.label,
                value: option.value
            }));
        } else if (error) {
            console.error('Error fetching list views:', error);
        }
    }

    handleObjectChange() {
        this.selectedObject = 'Contact';
        // console.log('Selected Object:', this.selectedObject);

        this.selectedRows = [];
        this.recorddata = [];
        this.paginatedRecorddata = [];
        this.selectedRecords = [];
        this.paginatedSelectedRecords = [];
        this.currentPage = 1;
        this.currentPage2 = 1;
        this.hasRecords = false;
        this.selectedListView = undefined;

        this.fetchListViews();
        // this.fetchListViewRecords();
        this.isLoading = false;

    }

    handleListViewChange(event) {
        this.selectedListView = event.detail.value;
        console.log('list view ',this.selectedListView);
        
        this.fetchListViewRecords();
    }

    handleRowSelection(event) {
        const currentlySelectedRows = event.detail.selectedRows.map(row => row.Id);

        this.selectedRowsTemp = this.selectedRowsTemp.filter(rowId =>
            currentlySelectedRows.includes(rowId) || !this.currentPageRowIds.includes(rowId)
        );
        this.selectedRowsTemp = [...new Set([...this.selectedRowsTemp, ...currentlySelectedRows])];
        console.log('All Selected Rows:', this.selectedRowsTemp, 'Length:', this.selectedRowsTemp.length);
        const selectedRecordDetails = event.detail.selectedRows.map(row => {
            return {
                Id: row.Id,
                Phone: row.WhatsApp_Phone__c
            };
        });

        console.log('Selected Record Details:', selectedRecordDetails);
    }

    preselectRowsOnPageChange(currentPageRows) {
        if (!currentPageRows || !Array.isArray(currentPageRows)) {
            console.error('currentPageRows is undefined or not an array:', currentPageRows);
            return;
        }


        console.log('preselectRowsOnPageChange: ', JSON.stringify(currentPageRows));

        // Check if the rows have an 'Id' property
        const rowIds = currentPageRows.map(row => row.Id);
        if (rowIds.some(id => id === undefined)) {
            console.error('One or more rows do not have an Id:', rowIds);
            return;
        }

        console.log('currentPageRows Ids: ', JSON.stringify(rowIds));

        try {
            // Save current page row IDs
            this.currentPageRowIds = rowIds;
            console.log('currentPageRowIds: ', JSON.stringify(this.currentPageRowIds));

            // Filter rows that were previously selected
            const rowsToPreselect = currentPageRows.filter(row =>
                this.selectedRowsTemp.includes(row.Id)
            );

            console.log('rowsToPreselect: ', JSON.stringify(rowsToPreselect));

            // Preselect the filtered rows in the datatable
            this.template.querySelector('lightning-datatable').selectedRows = rowsToPreselect.map(row => row.Id);
        } catch (error) {
            console.error('Error during row selection: ', error);
        }

    }

    handleKeyUp(event) {
        try {
            this.searchTerm = event.target.value.trim().toLowerCase();
    
            if (this.searchTerm !== '') {
                const selectedIds = new Set(this.selectedRecords.map(record => record.Id));
    
                const filteredData = this.alldata.filter((e) => {
                    let Name = e.Name ? e.Name.trim().toLowerCase() : '';
                    let Phone = e.WhatsApp_Phone__c ? e.WhatsApp_Phone__c.trim().toLowerCase() : '';    
                    return (Name.includes(this.searchTerm) || Phone.includes(this.searchTerm)) && !selectedIds.has(e.Id);
                });
    
                this.paginatedRecorddata = filteredData.slice(0, 10);
                console.log('Filtered pagination==>', JSON.stringify(this.paginatedRecorddata));
    
            } else {
                this.paginatedRecorddata = this.alldata.filter(e => !this.selectedRecords.some(selected => selected.Id === e.Id)).slice(0, 10);
            }
    
            this.paginatedRecorddata = this.paginatedRecorddata.map((record) => {
                return {
                    ...record,
                    isSelected: this.selectedRecords.some(selected => selected.Id === record.Id) 
                };
            });
    
        } catch (error) {
            console.log('Error:', JSON.stringify(error));
        }
    }
    
    
    fetchListViews() {
        if (this.selectedObject) {
            getListViews({ objectName: this.selectedObject })
                .then(result => {
                    this.listViewOptions = result.map(option => ({
                        label: option.label,
                        value: option.value
                    }));
                })
                .catch(error => {
                    console.error('Error fetching list views:', error);
                    this.showToast('Error', 'An error occurred while fetching list views.', 'error');
                });
        }
    }

    fetchListViewRecords() {
        this.isLoading = true;
        if (!this.selectedObject || !this.selectedListView) return;

        getListViewRecords({
            objectName: this.selectedObject,
            listViewId: this.selectedListView,
            sessionId: this.sessionId
        })
            .then(result => {
                console.log('result==> ', result);

                if (result) {
                    this.alldata = result;
                }
                console.log('all Data==>' + JSON.stringify(result));
                console.log('all Data==>' + JSON.stringify(this.alldata));

                this.selectedRowsTemp = [];

                const filteredRecords = result.filter(record =>
                    !this.selectedRecords.some(selected => selected.Id === record.Id)
                );

                this.recorddata = filteredRecords;

                this.originalRecordPositions = new Map();
                this.recorddata.forEach((record, index) => {
                    this.originalRecordPositions.set(record.Id, index);
                });
           
                if (this.recorddata.length === 0) {
                    this.isLoading = false;
                    console.warn('No records found for the selected list view.');
                } else {
                    this.isLoading = false;
                    console.log('Filtered Records:', this.recorddata);
                    console.log('Filtered recorddata size==> ', this.recorddata.length);
                }

                this.hasRecords = this.recorddata.length > 0;
                console.log(this.hasRecords);

                this.updatePaginatedData();
                this.isLoading = false;

                if (!this.hasRecords) {
                    this.isLoading = false;
                    this.showToast('Info', 'No records found for the selected list view', 'info');
                }
            })
            .catch(error => {
                this.showToast('Error', 'Error fetching records', 'error');
                console.log('error ', error);
                this.hasRecords = false;
                this.isLoading = false;
            });
    }

    checkPhoneField() {
        hasPhoneField({ objectName: this.selectedObject })
            .then(hasField => {
                console.log('hasField, ', hasField);

                if (hasField) {
                    console.log('enter in hasfield to fetch data..');
                } else {
                    this.showToast('Error', 'Selected object does not have a Phone field.', 'error');
                }
            })
            .catch(error => {
                console.error('Error checking phone field:', error);
                this.showToast('Error', 'An error occurred while checking for the Phone field.', 'error');
            });
    }

    get addRecordDisabled(){
        return this.selectedRowsTemp.length === 0;
    }
    handleAddSelected() {
        if (this.selectedRowsTemp.length === 0) {
            this.showToast('Warning', 'No records selected to add.', 'warning');
            return;
        }

        const validRecords = this.recorddata
            .filter(record => this.selectedRowsTemp.includes(record.Id) && record.WhatsApp_Phone__c && record.WhatsApp_Phone__c.trim() !== '')
            .map(record => {

                return {
                    ...record,
                    ObjectName: this.selectedObject,
                    ListViewName: this.selectedListView
                };
            });


        if (validRecords.length === 0) {
            this.showToast('Error', 'No selected records have a phone number.', 'error');
            this.selectedRows = [];
            this.selectedRowsTemp = [];
            return;
        }

        this.selectedRecords = [...this.selectedRecords, ...validRecords];
        console.log('selected length ', this.selectedRecords.length);

        this.recorddata = this.recorddata.filter(record =>
            !this.selectedRowsTemp.includes(record.Id) ||
            !(record.WhatsApp_Phone__c && record.WhatsApp_Phone__c.trim() !== '')
        );

        this.selectedRows = [];
        this.selectedRowsTemp = [];


        if (!this.allRecords[this.selectedObject]) {
            this.allRecords[this.selectedObject] = {};
        }
        if (!this.allRecords[this.selectedObject][this.selectedListView]) {
            this.allRecords[this.selectedObject][this.selectedListView] = [];
        }
        this.allRecords[this.selectedObject][this.selectedListView] = this.recorddata;

        this.updatePaginatedData();
        this.updatePaginatedSelectedData();

        this.showToast('Success', 'Selected records with phone number added.', 'success');
    }

    updatePaginatedData() {
        const recordArray = Array.from(this.recorddata);
        const totalRecords = recordArray.length;
        const startIdx = (this.currentPage - 1) * this.pageSize;
        const endIdx = this.currentPage * this.pageSize;

        this.paginatedRecorddata = recordArray.slice(startIdx, Math.min(endIdx, totalRecords));
        if (this.paginatedRecorddata.length === 0 && this.currentPage > 1) {
            this.currentPage--;
            this.updatePaginatedData();
            console.log('this is pagination call');

        }
        if (this.paginatedRecorddata.length > 0) {
            console.log('this is paginatedRecorddata call' + this.paginatedRecorddata.length);
            this.preselectRowsOnPageChange(this.paginatedRecorddata);

        }

        console.log('Current Page:', this.currentPage);
        console.log('Paginated Record Data:', this.paginatedRecorddata);
    }

    updatePaginatedSelectedData() {
        console.log('update pagination called.');
        const recordArray = Array.from(this.selectedRecords);
        const startIdx = (this.currentPage2 - 1) * this.pageSize2;
        const endIdx = this.currentPage2 * this.pageSize2;

        this.paginatedSelectedRecords = recordArray.slice(startIdx, Math.min(endIdx, recordArray.length));
        console.log('this.paginatedSelectedRecords ', this.paginatedSelectedRecords, ' Length: ', this.paginatedSelectedRecords.length);
        if (this.paginatedSelectedRecords.length > 0) {
            this.noselected = false;
        }
        if (this.paginatedSelectedRecords.length === 0 && this.currentPage2 > 1) {
            this.currentPage2--;
            this.updatePaginatedSelectedData();
        }
    }

    handlePageChange(event) {
        const direction = event.target.dataset.direction;
        if (direction === 'next') {
            this.currentPage++;
        } else if (direction === 'prev' && this.currentPage > 1) {
            this.currentPage--;
        }
        this.updatePaginatedData();
    }

    handlePageChange2(event) {
        const direction = event.target.dataset.direction;
        if (direction === 'next') {
            this.currentPage2++;
        } else if (direction === 'prev' && this.currentPage2 > 1) {
            this.currentPage2--;
        }
        this.updatePaginatedSelectedData();
    }

    handleBroadcastChange(event) {
        const direction = event.target.dataset.direction;
        if (direction === 'next') {
            this.currentBroadcast++;
        } else if (direction === 'prev' && this.currentBroadcast > 1) {
            this.currentBroadcast--;
        }
        this.updatePaginatedBroadcast();
    }

    get totalNumberOfPages1() {
        if (this.pageSize > 0) {
            return Math.ceil(this.recorddata.length / this.pageSize);
        }
        return 1;
    }

    @api
    get disablePrevButtons1() {
        return this.currentPage === 1;
    }
    @api
    get disableNextButtons1() {
        return (
            this.currentPage === this.totalNumberOfPages1 ||
            this.totalNumberOfPages1 === 0
        );
    }

    get totalNumberOfBroadcast() {
        if (this.pageSize > 0) {
            return Math.ceil(this.data.length / this.pageSize);
        }
        return 1;
    }

    @api
    get disablePrevBroadcast() {
        return this.currentBroadcast === 1;
    }
    @api
    get disableNextBroadcast() {
        return (
            this.currentBroadcast === this.totalNumberOfBroadcast ||
            this.totalNumberOfBroadcast === 0
        );
    }

    get totalNumberOfPages2() {
        if (this.pageSize2 > 0) {
            return Math.ceil(this.selectedRecords.length / this.pageSize2);
        }
        return 1;
    }

    @api
    get disablePrevButtons2() {
        return this.currentPage2 === 1;
    }

    @api
    get disableNextButtons2() {
        return (
            this.currentPage2 === this.totalNumberOfPages2 ||
            this.totalNumberOfPages2 === 0
        );
    }
    @api
    get disableCreateBroadcast() {
        const isDisabled = this.selectedRecords.length === 0;
        this.noselected = isDisabled;
        return isDisabled;
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }


    handleDeleteAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'delete') {
            this.removeRecordById(row.Id);
        }
    }

    removeRecordById(rowId) {
        const removedRecord = this.selectedRecords.find(record => record.Id === rowId);
        if (removedRecord) {
            this.selectedRecords = this.selectedRecords.filter(record => record.Id !== rowId);

            const originalObject = removedRecord.ObjectName;
            console.log('originalObject ', originalObject);

            const originalListView = removedRecord.ListViewName;
            console.log('originalListView ', originalListView);



            if (originalObject && originalListView) {
                this.returnToOriginalList(removedRecord, originalObject, originalListView);
            }

            this.updatePaginatedData();
            this.updatePaginatedSelectedData();
            this.disableCreateBroadcast;
        }
    }

    returnToOriginalList(record, objectName, listViewName) {
        if (this.selectedObject === objectName && this.selectedListView === listViewName) {
            const originalPosition = this.originalRecordPositions.get(record.Id);
            
            if (!this.recorddata.some(existingRecord => existingRecord.Id === record.Id)) {
                if (originalPosition !== undefined) {
                    this.recorddata.splice(originalPosition, 0, { ...record });
                } else {
                    this.recorddata.push({ ...record });
                }
            }
        } else {
            if (!this.allRecords[objectName]) {
                this.allRecords[objectName] = {};
            }
            if (!this.allRecords[objectName][listViewName]) {
                this.allRecords[objectName][listViewName] = [];
            }
            this.allRecords[objectName][listViewName].push({ ...record });
        }
    }
    
    
    handleSendMessage() {
       console.log('this is handleSendMessage');
       
        this.showTemplate = true;
        this.isMainModal=true;
        this.isShowNextSchedule=false;
    }
    
    lookupRecord(event) {
        console.log(event);
        const selectedLookupRecord = event.detail.selectedRecord;

        if (selectedLookupRecord) {
            console.log('Selected Record Value on Parent Component is ' + JSON.stringify(selectedLookupRecord));
            this.templateId = selectedLookupRecord.Id;
            console.log('this.templateId ', this.templateId);
            getTemplateRecords({ templateId: this.templateId })
                .then(data => {
                    if (data) {
                        this.templateHeader = data.Template_Header__c;
                        this.templateBody = data.Body__c;
                        this.templateFooter = data.Template_Footer__c;
                        this.selectedRecord = true;
                    } else {
                        this.selectedRecord = false;
                    }

                })
                .catch(error => {
                    this.selectedRecord = false;
                    console.error('Error fetching template:', error);
                    this.showToast('Error', 'Something went wrong. No able to load messages.', 'error');

                });

        } else {
            this.selectedRecord = false;
        }
    }

    BacktoSendMessage(){
        console.log('BacktoSendMessage');
        this.isShowNextSchedule = false;
        this.isMainModal = true;
    }
    handleCloseTemplate() {
        console.log('logtrue');
        this.selectedRecord = false;
        this.showTemplate = false;
        this.isMainModal = true;
        this.isShowNextSchedule = false;
        this.paginatedSelectedRecords ;
    }

    handleAddTemplate() {
        console.log('Enter in template sending...');

        if (this.selectedRecords.length === 0) {
            this.showToast('Warning', 'No records selected to send messages.', 'warning');
            return;
        }

        const currentDate = new Date();
        const hours = currentDate.getHours();
        const minutes = currentDate.getMinutes();
        const ampm = hours >= 12 ? 'PM' : 'AM';
        const formattedHours = hours % 12 || 12;
        const formattedMinutes = minutes < 10 ? '0' + minutes : minutes;
        const timeString = formattedHours + ':' + formattedMinutes + ' ' + ampm;
        const currentTime = timeString;

        console.log('Current time:', currentTime);

        const recordsData = this.selectedRecords.map(record => {
            return {
                phoneNumber: record.WhatsApp_Phone__c,
                recordName: record.Name,
                recordId: record.Id
            };
        });

        const recordsJson = JSON.stringify(recordsData);
        console.log('recordsJson ', recordsJson);

        sendTemplateMessage({
            recordsJson: recordsJson,
            templateId: this.templateId,
            timeOfMessage: currentTime

        })
            .then(() => {
                this.handleCloseTemplate();
                this.isLoading = true;
                this.getBroadcastRecords();
                this.updatePaginatedBroadcast();
                this.selectedRecords = [];
                this.paginatedSelectedRecords = [];
                this.selectedRecord = false;
                this.isLoading = false;
                this.isShowSchedule = false;
                this.isShowNextSchedule = false;

                this.showToast('Success', 'Messages sent successfully!', 'success');

            })
            .catch(error => {
                console.error('Error sending messages:', error.body.message);
                this.showToast('Error', 'Failed to send messages', 'error');
            });
    }


    setMinDate() {
        const d = new Date();
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const date = String(d.getDate()).padStart(2, '0');
        this.today = `${year}-${month}-${date}`;
        console.log('Today:', this.today);
    }

    setMinTime() {
        const timeInput = this.template.querySelector('input[type="time"]');
        if (timeInput) {
            const now = new Date();
            const hours = now.getHours().toString().padStart(2, '0');
            const minutes = now.getMinutes().toString().padStart(2, '0');
            this.minTime = `${hours}:${minutes}`;
            console.log('Min Time:', this.minTime);
            // timeInput.setAttribute('min', minTime);
        }
    }

    onDateChange(event) {
        this.selectedDate = event.target.value;
        console.log('selected date==> ', this.selectedDate);
    }

    onTimeChange(event) {
        this.selectedTime = event.target.value;
        console.log('selected time==> ', this.selectedTime);
    }

    handleSchedule() {
        if (this.selectedDate == '' || this.selectedTime == '') {
            this.showToast('Error', 'Select Date and Time', 'error');
            return;
        }
        const formattedDate = this.selectedDate;
        const formattedTime = this.selectedTime + ':00';

        // Combine date and time
        const scheduleDateTime = `${formattedDate}T${formattedTime}`;
        console.log('scheduleDateTime==> ', scheduleDateTime);

        const scheduleDate = new Date(scheduleDateTime);
        console.log('Schedule Date Object:', scheduleDate);

        const currentDate = new Date();
        console.log('Current Date Object:', currentDate);

        if (scheduleDate < currentDate) {
            this.showToast('Error', 'Scheduled date and time should be in the future.', 'error');
            return;
        }

        // const formattedDateTime = scheduleDate.toISOString().slice(0, -1); 
        const recordsData = this.selectedRecords.map(record => {
            return {
                phoneNumber: record.WhatsApp_Phone__c,
                recordName: record.Name,
                recordId: record.Id
            };
        });

        const recordsJson = JSON.stringify(recordsData);
        console.log('recordsJson ', recordsJson.
            length);

        scheduleTemplateMessage({
            recordsJson: recordsJson,
            templateId: this.templateId,
            timeOfMessage: scheduleDateTime
        })
            .then(result => {
                console.log('Job scheduled successfully.');
                this.showTemplate = false;
                this.selectedRecords = [];
                this.paginatedSelectedRecords = [];

                this.dispatchEvent(new ShowToastEvent({
                    title: "Success",
                    message: "Message scheduled successfully on "+ `${formattedDate} ${formattedTime}`,
                    variant: "success"
                }));
            })
            .catch(error => {
                console.error('Error scheduling job:', error.body);
            });
    }

    // handleScheduleTemp(){
    //     this.isShowSchedule=true;
    //     this.showTemplate=false;
    // }
    handleSchedulePopup() {
        this.isShowNextSchedule = true;
        this.isMainModal = false;
    }
    hideModalBox() {
        this.isShowSchedule = false;
    }
    hideModalBox2() {
        console.log('this is ');
        this.selectedRecord = false;
        this.showTemplate = false;
        this.isMainModal = true;
        this.isShowNextSchedule = false;
    }

    backToControlCenter(event) {
        try {
            event.preventDefault();
            let componentDef = {
                componentDef: "c:estateXpertControlCenter",
            };
            let encodedComponentDef = btoa(JSON.stringify(componentDef));
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/one/one.app#' + encodedComponentDef
                }
            });
        } catch (error) {
            console.log('error--> ',error);
        }
    }
}