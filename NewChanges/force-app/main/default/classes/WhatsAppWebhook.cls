@RestResource(urlMapping='/EX/webhooks/v1/*')
global without sharing class WhatsAppWebhook {

    public static String currentTime = System.now().format('yyyy-MM-dd HH:mm:ss');
    public static String phoneNumberId = '';

    @HttpGet // GET
    global static void doGet() {
        RestResponse response = RestContext.response;
        RestRequest request = RestContext.request;
        if(request.params.get('hub.verify_token') == 'WHATSAPPTOKEN'){
            response.responseBody = Blob.valueOf( request.params.get('hub.challenge') );
        }
    }

    @HttpPost
    global static void doPost() {
        // Verify Token (Replace with your Verify Token)
        String verifyToken = '7fa1634d4f849b8ced3a249ec4ce8bb7db4d8046';
        if (RestContext.request.headers.get('hub.verify_token') != verifyToken) {
            System.debug('InDoPost Method If condition');
            RestContext.response.statusCode = 403;
        }
        // Get WhatsApp's raw JSON data
        String jsonString = RestContext.request.requestBody.toString();
        try {
            WhatsAppWebhookController.processWhatsAppPayload(jsonString);
        } catch (Exception e) {
            System.debug('Error processing WhatsApp payload: ' + e.getMessage());
        }
    }
}