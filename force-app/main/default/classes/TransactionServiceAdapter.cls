public with sharing class TransactionServiceAdapter {
    private static  AuthorizationTransactionService  authTxnService;
    private static  CaptureTransactionService  captureTxnService;
    
    public static AbstractTransactionService getServiceInstance(commercepayments.paymentGatewayContext gatewayContext){
        commercepayments.RequestType requestType;
        requestType = gatewayContext.getPaymentRequestType();

        //Authorization Service
        if (requestType == commercepayments.RequestType.Authorize) {
            if(authTxnService ==null)
            {
                authTxnService = new AuthorizationTransactionService(gatewayContext);
            }
            return authTxnService;
        }
        //Capture Service
        else if ( requestType == commercepayments.RequestType.Capture) {
            if(captureTxnService ==null)
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