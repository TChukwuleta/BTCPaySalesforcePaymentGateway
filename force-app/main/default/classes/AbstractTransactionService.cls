public abstract class AbstractTransactionService {
    protected final commercepayments.SalesforceResultCode SUCCESS_SALESFORCE_RESULT_CODE = commercepayments.SalesforceResultCode.SUCCESS;
    protected final commercepayments.SalesforceResultCode DECLINE_SALESFORCE_RESULT_CODE = commercepayments.SalesforceResultCode.DECLINE;
    protected final commercepayments.SalesforceResultCode PENDING_SALESFORCE_RESULT_CODE = commercepayments.SalesforceResultCode.PENDING;
    protected final commercepayments.SalesforceResultCode CANCELLED_SALESFORCE_RESULT_CODE = commercepayments.SalesforceResultCode.CANCELLED;
    protected commercepayments.paymentGatewayContext gatewayContext;

    public AbstractTransactionService(commercepayments.paymentGatewayContext gatewayContext){
            this.gatewayContext = gatewayContext;
    }

    public abstract HttpRequest buildRequest();

    public abstract commercepayments.GatewayResponse buildResponse(HttpResponse response);

    public commercepayments.GatewayResponse execute() {
        HttpRequest req;
        try {
            //Building a new request
            req = buildRequest();
        } catch(Exception e) {
            return new commercepayments.GatewayErrorResponse('400', e.getMessage());
        }
        commercepayments.PaymentsHttp http = new commercepayments.PaymentsHttp();
        HttpResponse res = null;
        try {
            //Sending the request
            res = http.send(req);
        } catch(CalloutException ce) {
            return new commercepayments.GatewayErrorResponse('500', ce.getMessage());
        }
        try {
            //Parsing the response from gateway
            return buildResponse(res);
        } catch(Exception e) {
            return new commercepayments.GatewayErrorResponse('400', 'Something went wrong in the Gateway Adapter : ' + e.getMessage());
        }
    }
    
    protected void setAuthorizationHeaders(HttpRequest req){
        req.setHeader('Content-Type', 'application/json');
    }

    /**
	* Function to get Salesforce Result Code Info
	*
	* @see https://help.salesforce.com/articleView?id=custommetadatatypes_about.htm
	* @see SalesforceResultCodeInfo
	* @see CustomMetadataTypeInfo
	* @see SalesforceResultCode
	*
	* The managed package must create and maintain a Custom Metadata Type with the mappings of Gateway Result Codes and Salesforce Result Codes.
	* This adapter implementation does not use custom metadata and returns hardcoded salesforceResultCodeInfo
	* see getSalesforceResultCodeInfo(AbstractTransactionAdapter.apex) in PayeezyAdapter_CustomMetadata
	*
	*/
    protected commercepayments.SalesforceResultCodeInfo getSalesforceResultCodeInfo(String resultCode) {
        if (resultCode == null) {
            return new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.ERROR);
        }
        switch on resultCode {
            when SUCCESS_SALESFORCE_RESULT_CODE.name() {
                return new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.SUCCESS);
            }
            when DECLINE_SALESFORCE_RESULT_CODE.name() {
                return new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.DECLINE);
            }
            when PENDING_SALESFORCE_RESULT_CODE.name() {
                return new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.PENDING);
            }
            when CANCELLED_SALESFORCE_RESULT_CODE.name() {
                return new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.CANCELLED);
            }
            when else {
                return new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.ERROR);
            }
        }
    }
}