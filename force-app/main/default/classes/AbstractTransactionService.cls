public abstract class AbstractTransactionService {
    protected final commercepayments.SalesforceResultCode SUCCESS_SALESFORCE_RESULT_CODE = commercepayments.SalesforceResultCode.SUCCESS;
    protected final commercepayments.SalesforceResultCode DECLINE_SALESFORCE_RESULT_CODE = commercepayments.SalesforceResultCode.DECLINE;
    private static final String CREATE_BTCPAY_INVOICE_PATH = '/stores/{0}/plugin/salesforce/public/invoices/create';
    protected commercepayments.paymentGatewayContext gatewayContext;

    public AbstractTransactionService(commercepayments.paymentGatewayContext gatewayContext){
            this.gatewayContext = gatewayContext;
    }

    public abstract HttpRequest buildRequest(commercepayments.paymentGatewayContext gatewayContext);

    public abstract commercepayments.GatewayResponse buildResponse(HttpResponse response);

    public commercepayments.GatewayResponse execute() {
        HttpRequest req;
        try {
            req = buildRequest();
        } catch(Exception e) {
            return new commercepayments.GatewayErrorResponse('400', e.getMessage());
        }
        commercepayments.PaymentsHttp http = new commercepayments.PaymentsHttp();
        HttpResponse res = null;
        try {
            res = http.send(req);
        } catch(CalloutException ce) {
            return new commercepayments.GatewayErrorResponse('500', ce.getMessage());
        }
        try {
            return buildResponse(res);
        } catch(Exception e) {
            return new commercepayments.GatewayErrorResponse('400', 'Something went wrong in the Gateway Adapter : ' + e.getMessage());
        }
    }
    
    protected void setAuthorizationHeaders(HttpRequest req){
        req.setHeader('Content-Type', 'application/json');
    }

    protected void buildInvoiceCreationUrl(HttpRequest req) {
        String baseUrl = getBTCPayServerUrl();
        String storeId = getBTCPayStoreId();
        String fullUrl = baseUrl + String.format(CREATE_BTCPAY_INVOICE_PATH, new String[] { storeId });
        req.setEndpiont(fullUrl);
    }
    
    protected String getBTCPayServerUrl() {
        BTCPay_Settings__c settings = BTCPay_Settings__c.getOrgDefaults();
        return settings?.Server_URL__c;
    }

    protected String getBTCPayStoreId() {
        BTCPay_Settings__c settings = BTCPay_Settings__c.getOrgDefaults();
        return settings?.Store_ID__c;
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
            return new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.SystemError);
        }
        switch on resultCode {
            when 'SUCCESS' { 
                return new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.SUCCESS);
            }
            when 'DECLINE' {
                return new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.DECLINE);
            }
            when else {
                return new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.ValidationError);
            }
        }
    }
}