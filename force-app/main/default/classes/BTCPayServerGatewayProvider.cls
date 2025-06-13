public with sharing class BTCPayServerGatewayProvider implements CommercePayments.PaymentGatewayAdapter {
    public commercepayments.GatewayResponse processRequest(commercepayments.paymentGatewayContext gatewayContext){
        commercepayments.RequestType requestType;
        if(gatewayContext==null) {
           return new commercepayments.GatewayErrorResponse('400','Gateway context cannot be null');
        }
        
        AbstractTransactionService service = TransactionServiceAdapter.getServiceInstance(gatewayContext);
        if(service!=null){ 
            return service.execute();
        } else {
            return new commercepayments.GatewayErrorResponse('400','Service not found');
        } 
    }
}
