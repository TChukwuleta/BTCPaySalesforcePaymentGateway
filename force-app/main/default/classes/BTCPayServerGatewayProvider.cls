public with sharing class BTCPayServerGatewayProvider implements commercepayments.PaymentGatewayAsyncAdapter, commercepayments.PaymentGatewayAdapter {
    public commercepayments.GatewayResponse processRequest(commercepayments.paymentGatewayContext gatewayContext){
        commercepayments.RequestType requestType;
        if(gatewayContext == null) {
           return new commercepayments.GatewayErrorResponse('400','Gateway context cannot be null');
        }
        try {
            AbstractTransactionService service = TransactionServiceAdapter.getServiceInstance(gatewayContext);
            if (service != null) {
                return service.execute();
            } else {
                return new commercepayments.GatewayErrorResponse('400', 'Service not found for request type');
            }
        } catch (Exception e) {
            System.debug('BTCPay Gateway Error: ' + e.getMessage());
            return new commercepayments.GatewayErrorResponse('500', 'Internal server error: ' + e.getMessage());
        }
    }

    public commercepayments.GatewayNotificationResponse processNotification(commercepayments.PaymentGatewayNotificationContext gatewayNotificationContext){
        try {
            commercepayments.PaymentGatewayNotificationRequest gatewayNotificationRequest = gatewayNotificationContext.getPaymentGatewayNotificationRequest();
            Blob request = gatewayNotificationRequest.getRequestBody();
            Map<String, String> headers = gatewayNotificationContext.getNotificationHeaders();
            // Or this: Map<String, String> headers = gatewayNotificationRequest.getHeaders();
            // Verify webhook
            
            // Map<String, String> headers = gatewayRequest.getHeaders();
            // String sigHeader = headers.get('BTCPay-Sig'); // or 'x-signature'

            // Step 2: Verify signature
            // String webhookSecret = 'your-shared-secret';
            // if (!verifyBTCPaySignature(sigHeader, requestBody.toString(), webhookSecret)) {
            //     throw new commercepayments.PaymentGatewayException('Invalid signature');
            // }
            // if (!verifyBTCPaySignature(request, headers)) {
            //     System.debug('BTCPay webhook signature verification failed');
            //     return new commercepayments.GatewayNotificationResponse(
            //         commercepayments.GatewayNotificationResponse.NotificationStatus.ERROR,
            //         'BTCPay webhook signature verification failed'
            //     );
            // }
            System.debug('BTCPay notification received: ' + request.toString());

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(requestBody.toString());
            String eventType = (String) payload.get('type');
            String invoiceId = (String) payload.get('invoiceId');
            String status = (String) payload.get('status');
            String storeId = (String) payload.get('storeId');
            String amountPaidStr = (String) payload.get('amountPaid');
            Decimal amount = Decimal.valueOf(amountPaidStr);
            
            commercepayments.NotificationStatus notificationStatus = null;
            if ('InvoiceSettled'.equals(eventType) || 'InvoiceProcessing'.equals(eventType)) {
                notificationStatus = commercepayments.NotificationStatus.Success;
            } else if ('InvoiceExpired'.equals(eventType) || 'InvoiceInvalid'.equals(eventType)) {
                notificationStatus = commercepayments.NotificationStatus.Failed;
            } else {
                throw new commercepayments.PaymentGatewayException('Unhandled event type: ' + eventType);
            }
            commercepayments.BaseNotification notification = new commercepayments.CaptureNotification();
            notification.setStatus(notificationStatus);
            notification.setGatewayReferenceNumber(invoiceId);
            notification.setAmount(amount);
            commercepayments.NotificationSaveResult saveResult = commercepayments.NotificationClient.record(notification);
            if (saveResult.isSuccess()) {
                system.debug('Notification accepted by platform');
            } else {
                system.debug('Errors in the result '+ Blob.valueOf(saveResult.getErrorMessage()));
            }
            commercepayments.GatewayNotificationResponse gnr = new commercepayments.GatewayNotificationResponse();
            gnr.setStatusCode(200);
            gnr.setResponseBody(Blob.valueOf('[accepted]'));
            return gnr;
        } catch (Exception e) {
            System.debug('Error processing BTCPay notification: ' + e.getMessage());
            return new commercepayments.GatewayNotificationResponse(
                commercepayments.GatewayNotificationResponse.NotificationStatus.ERROR,
                'Error processing BTCPay notification: ' + e.getMessage()
            );
        }
    }


    

    
    private static Boolean verifyBTCPaySignature(String sigHeader, String rawBody, String secret) {
        String expectedSig = 'sha256=' + EncodingUtil.convertToHex(
            Crypto.generateMac('HmacSHA256', Blob.valueOf(rawBody), Blob.valueOf(secret))
        ).toLowerCase();
        return expectedSig == sigHeader?.toLowerCase();
    }

    private Boolean verifyBTCPaySignature(Blob requestBody, Map<String, String> headers) {
        try {
            String signature = headers.get('BTCPay-Sig');
            if (String.isBlank(signature)) {
                signature = headers.get('btcpay-sig');
            }
            
            String webhookSecret = getBTCPayWebhookSecret();
            
            if (String.isBlank(signature) || String.isBlank(webhookSecret)) {
                System.debug('Missing BTCPay signature or webhook secret');
                return false;
            }
            
            // BTCPay uses HMAC-SHA256 with format: sha256=<hex>
            if (!signature.startsWith('sha256=')) {
                System.debug('Invalid BTCPay signature format');
                return false;
            }
            
            String providedSignature = signature.substring(7); // Remove 'sha256=' prefix
            
            // Generate expected signature using HMAC-SHA256
            Blob expectedSignature = Crypto.generateMac('HmacSHA256', 
                requestBody, 
                Blob.valueOf(webhookSecret));
            
            String expectedSignatureHex = EncodingUtil.convertToHex(expectedSignature);
            
            return providedSignature.equalsIgnoreCase(expectedSignatureHex);
            
        } catch (Exception e) {
            System.debug('BTCPay signature verification error: ' + e.getMessage());
            return false;
        }
    }

    // Get stored webhook secret
    private String getBTCPayWebhookSecret() {
        try {
            // Retrieve from Custom Settings - you need to create this
            BTCPay_Settings__c settings = BTCPay_Settings__c.getOrgDefaults();
            return settings?.Webhook_Secret__c;
        } catch (Exception e) {
            System.debug('Could not retrieve BTCPay webhook secret: ' + e.getMessage());
            return null;
        }
    }

    // Get invoice amount - you might need to store this during invoice creation
    // or make an API call to BTCPay Server to get invoice details
    private Double getInvoiceAmount(String invoiceId) {
        try {
            // Option 1: Query from stored payment records
            List<commercepayments__PaymentGatewayLog__c> logs = [
                SELECT commercepayments__Amount__c 
                FROM commercepayments__PaymentGatewayLog__c 
                WHERE commercepayments__GatewayReferenceNumber__c = :invoiceId
                LIMIT 1
            ];
            
            if (!logs.isEmpty() && logs[0].commercepayments__Amount__c != null) {
                return logs[0].commercepayments__Amount__c;
            }
            
            // Option 2: You could make an API call to BTCPay Server to get invoice details
            // This would require implementing BTCPay API client
            
            return null;
            
        } catch (Exception e) {
            System.debug('Error getting invoice amount: ' + e.getMessage());
            return null;
        }
    }
}