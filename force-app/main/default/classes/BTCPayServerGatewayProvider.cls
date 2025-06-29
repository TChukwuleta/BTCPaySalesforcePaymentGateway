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
            Map<String, String> headers = gatewayNotificationRequest.getHeaders();
            // Verify webhook
            
            System.debug('BTCPay notification received: ' + request.toString());

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(request.toString());
            String eventType = (String) payload.get('type');
            String invoiceId = (String) payload.get('invoiceId');
            String status = (String) payload.get('status');
            String storeId = (String) payload.get('storeId');
            String amountPaidStr = (String) payload.get('amountPaid');
            Double amount = Double.valueOf(amountPaidStr);
            
            commercepayments.NotificationStatus notificationStatus = null;
            if ('InvoiceSettled'.equals(eventType) || 'InvoiceProcessing'.equals(eventType)) {
                notificationStatus = commercepayments.NotificationStatus.Success;
            } else if ('InvoiceExpired'.equals(eventType) || 'InvoiceInvalid'.equals(eventType)) {
                notificationStatus = commercepayments.NotificationStatus.Failed;
            } else {
                throw new CalloutException('Unhandled event type: ' + eventType);
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
            throw new CalloutException('Error processing BTCPay notification: ' + e.getMessage());
        }
    }
}