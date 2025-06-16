public with sharing class BTCPayServerGatewayProvider implements CommercePayments.PaymentGatewayAdapter {
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
}
