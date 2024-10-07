public without sharing class WhatsAppMessageQueueSchedular implements Schedulable {
    private List<BroadcastMessageController.RecordData> recordsData;
    private Id templateId;
    private String timeOfMessage;
    private String headerMergeVal;
    private List<String> mergeFieldValues;

    public WhatsAppMessageQueueSchedular(List<BroadcastMessageController.RecordData> recordsData, Id templateId, String timeOfMessage,String headerMergeVal,List<String> mergeFieldValues) {
        this.recordsData = recordsData;
        this.templateId = templateId;
        this.timeOfMessage = timeOfMessage;
        this.headerMergeVal = headerMergeVal;
        this.mergeFieldValues = mergeFieldValues;
    }
    public void execute(SchedulableContext context){
        WhatsAppMessageQueueable tempQueue = new WhatsAppMessageQueueable(recordsData,templateId,timeOfMessage,headerMergeVal,mergeFieldValues);
        System.enqueueJob(tempQueue);
    }
}