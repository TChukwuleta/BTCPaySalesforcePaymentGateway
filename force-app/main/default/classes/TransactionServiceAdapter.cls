public with sharing class TransactionServiceAdapter {
    private static  CaptureTransactionService  captureTxnService;
    
    public static AbstractTransactionService getServiceInstance(commercepayments.paymentGatewayContext gatewayContext){
        commercepayments.RequestType requestType = gatewayContext.getPaymentRequestType();
        if (requestType == commercepayments.RequestType.Capture) { // Handle if later for authorization.. || requestType == commercepayments.RequestType.Authorize
            if(captureTxnService == null)
            {
                captureTxnService = new CaptureTransactionService(gatewayContext);
            }
            return captureTxnService;
        }
        else {
            return null;
        }
    }
}