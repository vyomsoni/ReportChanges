import { LightningElement, track, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getWhatsAppMessages from '@salesforce/apex/WhatsappChatController.getWhatsAppMessages';
import getContactDetails from '@salesforce/apex/WhatsappChatController.getContactDetails';
import getTemplateRecords from '@salesforce/apex/WhatsappChatController.getTemplateRecords';
import sendMessageWithText from '@salesforce/apex/WhatsAppIntegration.sendMessageWithText';
import sendDocumentByUrl from '@salesforce/apex/WhatsAppIntegration.sendDocumentByUrl';
import sendAudioByUrl from '@salesforce/apex/WhatsAppIntegration.sendAudioByUrl';
import createContentDistribution from '@salesforce/apex/WhatsAppIntegration.createContentDistribution';
import sendTemplateMessage from '@salesforce/apex/WhatsAppIntegration.sendTemplateMessage';
import WhatsAppAttachIcon from '@salesforce/resourceUrl/whatsapp_attachIcon';
import whatsappAudioIcon from '@salesforce/resourceUrl/whatsappAudioIcon';
import loadingTickIcon from '@salesforce/resourceUrl/messageLoadTick';
import singleTickIcon from '@salesforce/resourceUrl/singleTickIcon';
import doubleCheckedIcon from '@salesforce/resourceUrl/doubleCheckedIcon';
import 	blueDoubleTick from '@salesforce/resourceUrl/blueDoubleTick';
import SmileIconWhatsapp from '@salesforce/resourceUrl/SmileIconWhatsapp';
import PlusIcon from '@salesforce/resourceUrl/plus_icon';
import NoPreviewAvailable from '@salesforce/resourceUrl/NoPreviewAvailable';
import getEmojiData from '@salesforce/apex/EmojiDataController.getEmojiData';

export default class WhatsappChat extends NavigationMixin(LightningElement) {
    @api recordId;
    // @api templateId;
    @api id;
    @track objectApiName;
    @track isLoading = false;
    @track messages = [];
    @track messagesByDate = [];
    @track phoneNumberToSend;
    @track emojis;
    @track showEmojis = false;
    @track showAttachment = false;
    @track showTick = false;
    @track attachIcon = WhatsAppAttachIcon;
    @track loadingTick = loadingTickIcon;
    @track singleTick = singleTickIcon;
    @track doubleTick = doubleCheckedIcon;
    @track blueTick = blueDoubleTick;
    @track headphone = whatsappAudioIcon;
    @track showUpload = false;
    @track smileIcon = SmileIconWhatsapp;
    @track NoPreviewAvailable = NoPreviewAvailable;
    @track PlusIcon = PlusIcon;
    @track differentObj;
    @track date = '';
    @track currentTime = '';
    @track contentDocumentId;
    @track showTemplate = false;
    @track templateId = '';
    @track isDisabled = true;
    @track selectedRecord=false;
    @track containsMergeFields = false;
    @track mergeFieldCount = false;
    @track mergeFieldArray = [];
    @track headerMergeFieldExists = false;
    @track mergeFieldValues = new Map();
    @track headerVarLabel = '{{1}}';
    @track headerMergeValue ='';
    @track maxHeaderMerge = 60;


    @wire(CurrentPageReference) pageRef;
    acceptedFormats = ['.mp3', '.m4a', '.ogg', '.txt', '.xls', '.xlsx', '.doc', '.docx', '.ppt', '.pptx', '.pdf', '.jpeg', '.png', '.jpg', '.3gp', '.mp4'];
    InboundMessagestype = 'Inbound-Message';
    OutboundMessagestype = 'Outbound-Message';
    inputValue = '';
    subscription = {};
    templateHeader = '';
    templateBody = '';
    templateFooter = '';


    connectedCallback() {
        this.isLoading = true;
        const d = new Date();

        const options = { day: 'numeric', month: 'long', year: 'numeric' };
        const formattedDate = d.toLocaleDateString('en-IN', options);
        this.date = formattedDate;

        if (this.pageRef) {
            console.log(this.pageRef.attributes);
            this.id = this.pageRef.attributes.recordId;
            this.objectApiName =  this.pageRef.attributes.objectApiName;
            console.log('id:' + this.id)

            getContactDetails({ contactId: this.id })
                .then(data => {
                    if (data) {
                        console.log('Contact Data==>',data);
                        this.phoneNumberToSend = data.MVEX__WhatsApp_Phone__c;
                        console.log('this.phoneNumberToSend'+this.phoneNumberToSend);
                        if(data.MVEX__User_Consent_Received__c == true){
                            console.log('User Consent Yes');
                            this.isDisabled = false;
                        } else{
                            console.log('User Consent No');
                            this.isDisabled = true; 
                        }
                        console.log('contactPhone ==> ', this.phoneNumberToSend);
                        this.fetchMessages();
                    }
                })
                .catch(error => {
                    console.log('Error:' + error);
                    this.isLoading = false;
                });
        } else {
            this.showToastError('Record Id is not available');
            this.isLoading = false;
        }
        this.handleSubscribe();
        this.registerErrorListener();

    }

    handleSubscribe() {
        const channel = '/event/MVEX__ChatMessageEvent__e';
        const statusChannel = '/event/MVEX__WhatsApp_Message_Status__e';
        console.log('channel ==> ' + channel);

        subscribe(channel, -1, (response) => {
            console.log('response ==> ' , response);
            this.isDisabled = !(response.data.payload.MVEX__userConsent__c);
            this.handleMessage();
        }).then(response => {
            this.subscription = response;
        });

        subscribe(statusChannel, -1, (response) => {
            console.log('response ==> ' , response);
            console.log(response.data.payload);
            this.handleMessage();
        }).then(response => {
            // this.subscription = response;
        });
    }

    handleMessage() {
        console.log('In the handlemessage');
        this.fetchMessages();
    }
    
    lookupRecord(event){
        console.log(event);
        const selectedRecord = event.detail.selectedRecord;

        if (selectedRecord) {
            console.log('Selected Record Value on Parent Component is ' + JSON.stringify(selectedRecord));
            this.templateId = selectedRecord.Id;
            console.log('this.templateId ',this.templateId );
            getTemplateRecords({templateId:this.templateId})
            .then(data => {
                if(data){
                    this.templateHeader = data.MVEX__Template_Header__c;
                    this.templateBody = data.MVEX__Body__c;
                    this.templateFooter = data.MVEX__Template_Footer__c;
                
                    if(this.templateBody == '' || this.templateBody == null){
                        this.showToastError('No Preview for this template');
                        
                    }else{
                        this.headerMergeFieldExists = parseInt(data.MVEX__Header_Merge_Field_Count__c, 10) > 0;
                        this.mergeFieldCount = parseInt(data.MVEX__Total_Merge_Fields__c, 10); 
                        this.bodymergeFieldCount = parseInt(data.MVEX__Body_Merge_Field_Count__c, 10); 
                    
                        this.containsMergeFields = this.headerMergeFieldExists || this.mergeFieldCount > 0;
                        
                        this.selectedRecord = true;
                    
                        console.log(this.headerMergeFieldExists, ' this.headerMergeFieldExists');
                        console.log(this.bodyMergeFieldCount, ' this.bodyMergeFieldCount');
    
                    
                        if(this.bodymergeFieldCount > 0){   
                            const count = this.bodymergeFieldCount; 
                            this.mergeFieldArray = Array.from({ length: count }, (v, i) => ({
                                label: `{{${i + 1}}}`,
                                placeholder: `Enter value for Body {{${i + 1}}}`
                            }));
                        }
                    }
                   
                } else {
                    this.selectedRecord = false;
                }
                
            })
            .catch(error => {
                this.selectedRecord=false;
                console.error('Error fetching template:', error);
                this.showToastError('Something went wrong. No able to load messages.');
            });
            
        }else{
            this.selectedRecord=false;
            this.mergeFieldCount=false;
        }
    }


    handleMergeFieldChange(event) {
        const fieldLabel = event.target.dataset.label; 
        const fieldValue = event.target.value;  
    
        this.mergeFieldValues.set(fieldLabel, fieldValue);
        console.log('fieldlabel ',fieldLabel);
       
    }
    handleHeaderMergeFieldChange(event){
        this.headerMergeValue =  event.target.value;  
    }

    get currentHeaderMerge() {
        return this.headerMergeValue.length;
    }

    fetchMessages() {
        getWhatsAppMessages({ objectName: this.objectApiName, id: this.id })
            .then(data => {
                console.log('Fetched Data:', JSON.stringify(data, null, 2)); 
                if (data) {
                    try {
                        const processedData = this.processMessageData(data);
                        console.log('Processed Data:', JSON.stringify(processedData, null, 2));

                        const groupedMessages = {};
                        Object.keys(processedData).forEach(date => {
                            const messages = processedData[date];
                            console.log('messages', messages);
                            const sortedMessages = [];
                            messages.forEach(message => {
                                // console.log('inner msg ::' , message);
                                const timeParts = message.timeOfMessage.split(' ');
                                const timeOfDay = timeParts[1]; // AM or PM
                                const time = timeParts[0]; // HH:MM

                                const messageObject = {
                                    ...message,
                                    time,
                                    timeOfDay,
                                    showloadingTick: (message.messageType !== 'Inbound-Message')&&(message.msgLoadTick === 'true'),
                                    showSingleTick: message.msgSent === 'true',
                                    showDoubleTick: message.msgDelivered === 'true',
                                    showBlueTick: message.msgRead === 'true'
                                };
                                // console.log('msg object', messageObject);
                                sortedMessages.push(messageObject);
                            });

                            groupedMessages[date] = sortedMessages.map(message => {
                                const cssClass = message.messageType === 'Inbound-Message' ? 'InboundMessagestype' : 'OutboundMessagestype';
                                const messageContainerClass = message.messageType === 'Inbound-Message' ? 'chat-message-1 ' : 'chat-message ';
                                const timeClass = message.messageType === 'Inbound-Message' ? 'time-inbound' : 'time-outbound';

                                return {
                                    ...message,
                                    cssClass,
                                    messageContainerClass,
                                    timeClass
                                };
                            });
                        });

                        console.log('groupedMessages ==> ', groupedMessages);

                        this.messagesByDate = Object.keys(groupedMessages).map(date => ({
                            date,
                            messages: groupedMessages[date]
                        }));
                        this.scrollToBottom();
                        this.isLoading = false;
                    } catch (error) {
                        this.showToastError('Something wrong while processing messages.');
                        this.isLoading = false;
                    }
                } else{
                    console.log('unable to fetch data');
                    this.isLoading = false;
                }
            })
            .catch(error => {
                console.error('Error fetching messages:', error);
                this.showToastError('Something went wrong. No able to load messages.');
                this.isLoading = false;
            });
    }

    processMessageData(data) {
        const processedData = {};

        Object.keys(data).forEach(date => {
            processedData[date] = data[date].map(message => {
                // console.log(message);
                // Determine if the message is text, document, image, vide, audio or template

                const isText = message.typeOfMessage === 'Text';
                const isButton = message.typeOfMessage === 'button';
                const isDocument = message.typeOfMessage === 'Document';
                const isImage = message.typeOfMessage === 'Image';
                const isVideo = message.typeOfMessage === 'Video';
                const isAudio = message.typeOfMessage === 'Audio';
                let isTemplate = false;
                console.log('message.templateIdVal ',message.templateIdVal);
                
                if (message.templateIdVal || message.templateHeader || message.templateBody || message.templateFooter) {
                    isTemplate = true;
                }             
                console.log('isTemplate ',isTemplate);
                
                
                let fileData = null;
                if ((isDocument || isImage || isVideo || isAudio) && message.fileData) {
                    try {
                        fileData = JSON.parse(message.fileData);
                        const fileName = fileData.fileName;
                        return {
                            ...message,
                            isText: isText || isButton,
                            isButton,
                            isDocument,
                            isImage,
                            isVideo,
                            isAudio,
                            fileName,
                            isTemplate,
                            contentDocumentId: fileData.documentId,
                            fileUrl: `/sfc/servlet.shepherd/version/download/${fileData.contentVersionId}?as=${fileName}`,
                            fileThumbnail: `/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${fileData.contentVersionId}`
                        };
                    } catch (error) {
                        console.error('Error parsing file data:', error);
                        this.showToastError('Something went wrong. Please try again.');
                    }
                }

                // Ensure that all messages, including text messages, are included
                return {
                    ...message,
                    isText: isText || isButton,
                    isButton,
                    isDocument,
                    isImage,
                    isVideo,
                    isAudio,
                    isTemplate
                };
            });
        });
        return processedData;
    }
    
    registerErrorListener() {
        onError(error => {
            console.error('Received error from server:', error);
        });
    }

    disconnectedCallback() {
        unsubscribe(this.subscription, response => {
            console.log('Unsubscribed from platform event channel', response);
        });

    }

    handleInputChange(event) {
        this.inputValue = event.target.value;
        console.log(value);
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            this.inputValue = event.target.value;
            // console.log('inputValue ==> ', this.inputValue);
            this.handleSend(event);
            this.fetchMessages();
        }
    }

    handleSend() {
        console.log('clicked');

        if (!this.inputValue) {
            this.showToastError('Please enter a message');
            return;
        }

        if (!this.phoneNumberToSend) {
            this.showToastError('Selected Contact’s Phone number is Null or Invalid, Please check and try again.');
            this.inputValue = '';
            return;
        }

        const currentDate = new Date();
        const hours = currentDate.getHours();
        const minutes = currentDate.getMinutes();
        const ampm = hours >= 12 ? 'PM' : 'AM';
        const formattedHours = hours % 12 || 12;
        const formattedMinutes = minutes < 10 ? '0' + minutes : minutes;
        const timeString = formattedHours + ':' + formattedMinutes + ' ' + ampm;
        this.currentTime = timeString;


        if (this.inputValue && this.phoneNumberToSend) {
            const sendMessageParams = {
                toPhone: this.phoneNumberToSend,
                messageText: this.inputValue,
                contactId: this.id,
                Message: this.inputValue,
                timeOfMessage: this.currentTime
            };

            sendMessageWithText(sendMessageParams)
                .then((result) => {
                    if (result == true) {
                        console.log('Message sent successfully');
                        this.inputValue = '';
                        this.fetchMessages();
                        this.scrollToBottom();
                        this.showEmojis = false;
                        this.showTick=true;
                    }
                })
                .catch(error => {
                    console.error('Error sending WhatsApp message:', error);
                    this.showToastError('Something went wrong. Please try again.');

                });
        }else{
            this.showToastError('Not able to get input message or contacts phone number. ');
        }
    }

    @wire(getEmojiData)
    wiredEmojiData({ error, data }) {
        if (data) {
            this.processEmojiData(data);
        } else if (error) {
            console.error('Error fetching emoji data:', error);
            this.showToastError('Error fetching emojis.');
        }
    }

    processEmojiData(data) {
        try {
            const parsedData = JSON.parse(data);
            this.emojis = parsedData.map(emoji => ({
                char: emoji.emoji,
                name: emoji.annotation,
                unicode: emoji.shortcodes.join(',')
            }));
        } catch (e) {
            console.error('Error parsing JSON:', e);
        }
    }

    handleEmoji(event) {
        if(this.showAttachment==true){
            this.showAttachment=false;
        }
        this.showEmojis = !this.showEmojis;
    }

    handleEmojiHide() {
        this.showEmojis = false;
        this.showAttachment = false;
    }

    handleEmojiSelection(event) {
        console.log('handleEmojiSelection');
        
        event.stopPropagation();
        const emojiChar = event.target.textContent;
        console.log('emojiChar ',emojiChar);
        
        this.inputValue = this.inputValue ? this.inputValue + emojiChar : emojiChar; 
        this.showEmojis = false;

    }

    handleAttach() {
        if(this.showEmojis==true){
            this.showEmojis=false;
        }
        this.showAttachment = !this.showAttachment;
        console.log(' this.showAttachment ', this.showAttachment);
        
    }

    handlePreview(event) {
        const contentDocumentId = event.target.dataset.id;

        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: contentDocumentId
            }
        });
    }

    handleUploadFinished(event) {
        
        const uploadedFiles = event.detail.files;
        if(uploadedFiles != null){
            uploadedFiles.forEach(file => {
                this.uploadFile(file);
                this.showAttachment = false;
            });
        }else{
            this.showToastError('Something went wrong. Please try again');
        }
    }

    uploadFile(file) {
        console.log('File object:', file);
        console.log('Document Name:', file.documentName);

        const currentDate = new Date();
        const hours = currentDate.getHours();
        const minutes = currentDate.getMinutes();
        const ampm = hours >= 12 ? 'PM' : 'AM';
        const formattedHours = hours % 12 || 12;
        const formattedMinutes = minutes < 10 ? '0' + minutes : minutes;
        const timeString = formattedHours + ':' + formattedMinutes + ' ' + ampm;
        this.currentTime = timeString;

        const fileData = {
            fileName: file.name,
            documentId: file.documentId,
            contentVersionId: file.contentVersionId,
            mimeType: file.mimeType
        };

        console.log('fileData==> ', fileData);

        // Determine the type of file
        const isDocument = file.mimeType.includes('application') || file.mimeType.includes('text');
        const isImage = file.mimeType.includes('image');
        const isVideo = file.mimeType.includes('video');
        const isAudio = file.mimeType.includes('audio');
      
        createContentDistribution({ contentDocumentId: fileData.documentId, contactId: this.id })
            .then(publicUrl => {
                if (isDocument || isImage || isVideo) {
                    sendDocumentByUrl({
                        toPhone: this.phoneNumberToSend,
                        fileName: fileData.fileName,
                        documentUrl: publicUrl,
                        contactId: this.id,
                        message: publicUrl,
                        timeOfMessage: this.currentTime,
                        fileData: JSON.stringify(fileData)
                    })
                        .then(result => {
                            console.log('Document sent successfully', result);
                            this.fetchMessages();
                            this.scrollToBottom();
                            console.log('fetch called..');
                        })
                        .catch(error => {
                            console.error('Error sending document', error);
                            this.showToastError('Something went wrong. Please try again.');

                        });
                }
                else if (isAudio) {
                    sendAudioByUrl({
                        toPhone: this.phoneNumberToSend,
                        fileName: fileData.fileName,
                        audioUrl: publicUrl,
                        contactId: this.id,
                        message: publicUrl,
                        timeOfMessage: this.currentTime,
                        fileData: JSON.stringify(fileData)
                    })
                        .then(result => {
                            console.log('Audio sent successfully', result);
                            this.fetchMessages();
                            this.scrollToBottom();
                            console.log('fetch called..');
                        })
                        .catch(error => {
                            console.error('Error sending audio', error);
                            this.showToastError('Something went wrong. Please try again.');

                        });
                }else{
                    this.showToastError('Something went wrong. Please try again.');
                }
            })
            .catch(error => {
                this.showToastError('Error while storing file in salesforce.');
            });
    }

    handleImageError(event){
        event.target.onerror=null; 
        event.target.src=this.NoPreviewAvailable;
    }

    addTemplate(){
        this.showEmojis = false;
        this.showAttachment = false;
        this.showTemplate = true;
    }

    handleAddTemplate(){
        console.log('click to send template...');
        
        if(this.templateId == ''){
            this.showToastError('Please select a template');
        }else{
            const currentDate = new Date();
            const hours = currentDate.getHours();
            const minutes = currentDate.getMinutes();
            const ampm = hours >= 12 ? 'PM' : 'AM';
            const formattedHours = hours % 12 || 12;
            const formattedMinutes = minutes < 10 ? '0' + minutes : minutes;
            const timeString = formattedHours + ':' + formattedMinutes + ' ' + ampm;
            this.currentTime = timeString;
            const paramsArray = Array.from(this.mergeFieldValues.values());
            console.log('paramsArray ',paramsArray);
            
            console.log(this.templateId, this.phoneNumberToSend, this.currentTime, this.id);
            sendTemplateMessage({
                tempId: this.templateId,
                toPhone: this.phoneNumberToSend,
                contactId: this.id,
                timeOfMessage: this.currentTime,
                fileData: null,
                headerMergeVal:this.headerMergeValue,
                mergeFieldValues: paramsArray
            })
            .then((result) => {
                this.fetchMessages();
                this.scrollToBottom();
                this.selectedRecord=false;
                this.showTemplate = false;
                this.mergeFieldCount=false;
            })
            .catch(error => {
                console.error('Error sending template WhatsApp message:', error);
                this.showToastError('Something went wrong. Please try again.');
                this.mergeFieldCount=false;
            });
        }
    }
    
    handleCloseTemplate(){
        this.showTemplate = false;
        this.selectedRecord=false;
        this.mergeFieldCount=false;
    }

    scrollToBottom() {
        // Using JavaScript to scroll to the bottom of the chat box
        setTimeout(() => {
            const chatBox = this.template.querySelector('.chat-box');
            console.log('chatBox ==> ' + chatBox);
            if (chatBox) {
                chatBox.scrollTop = chatBox.scrollHeight;
            }
        }, 0);
    }

    showToastError(message) {
        const toastEvent = new ShowToastEvent({
            title: 'Error',
            message,
            variant: 'error'
        });
        this.dispatchEvent(toastEvent);
    }
}