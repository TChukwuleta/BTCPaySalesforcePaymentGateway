public with sharing class AuthorizationTransactionService extends AbstractTransactionService {

    private static final String BTCPAY_ENDPOINT_INVOICES = '/stores/{storeId}/plugin/salesforce/public/invoices';
    public AuthorizationTransactionService(commercepayments.paymentGatewayContext gatewayContext){
        super(gatewayContext);
    }

    public override HttpRequest buildRequest(){
        HttpRequest req = new HttpRequest();
        String storeId = getBTCPayStoreId();
        req.setEndpoint(BTCPAY_ENDPOINT_INVOICES.replace('{storeId}', storeId));
        req.setMethod('POST');
        req.setBody(buildAuthRequestBody((commercepayments.AuthorizationRequest)gatewayContext.getPaymentRequest()));
        setAuthorizationHeaders(req);
        return req;
    }
    
    public override commercepayments.GatewayResponse buildResponse(HttpResponse response){
        commercepayments.AuthorizationResponse authResponse = new commercepayments.AuthorizationResponse();
        String statusCode = String.valueOf(response.getStatusCode());
        Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
        if (statusCode == '200' || statusCode == '201') {
            Map<String, String> parsed = new Map<String, String>();
            if (jsonResponse == null) return parsed;
        
            if (responseData.containsKey('id')) parsed.put('invoice_id', String.valueOf(responseData.get('id')));
            if (responseData.containsKey('status')) parsed.put('status', String.valueOf(responseData.get('status')));
            if (responseData.containsKey('checkoutLink')) parsed.put('checkoutLink', String.valueOf(responseData.get('checkoutLink')));
            if (responseData.containsKey('amount')) parsed.put('amount', String.valueOf(responseData.get('amount')));
            if (responseData.containsKey('currency')) parsed.put('currency', String.valueOf(responseData.get('currency')));

            authResponse.setGatewayReferenceDetails(JSON.serialize(parsed));
            authResponse.setGatewayResultCode(statusCode);
            authResponse.setGatewayDate(System.now());
            authResponse.setAmount(authRequest.amount);
            authResponse.setGatewayResultCodeDescription('BTCPay invoice created - awaiting payment');
            authResponse.setGatewayReferenceNumber((String) responseData.get('id'));
            authResponse.setSalesforceResultCodeInfo(getSalesforceResultCodeInfo('PENDING'));
            commercepayments.AuthorizationRequest authRequest = (commercepayments.AuthorizationRequest)gatewayContext.getPaymentRequest();
        } else {
            String message = responseMap.get('message') != null ? 
                (String) responseMap.get('message') : 'Failed to create BTCPay invoice';
            return new commercepayments.GatewayErrorResponse(statusCode, message);
        }
        return authResponse;
    }
    
    private String buildAuthRequestBody(commercepayments.AuthorizationRequest authRequest) {
        if (authRequest.amount == null) {
            throw new Exception('Required field missing: Amount');
        }
        String currencyIso = authRequest.currencyIsoCode;
        if (currencyIso == null) {
            try {
                currencyIso = UserInfo.getDefaultCurrency();
            } catch (Exception e) {
                currencyIso = 'USD';
            }
        }
        commercepayments.AuthApiPaymentMethodRequest paymentMethod = authRequest.paymentMethod;
        JSONGenerator jsonGeneratorInstance = JSON.createGenerator(true);
        commercepayments.GatewayErrorResponse error;
        String orderId = 'SF-' + System.currentTimeMillis();
        jsonGeneratorInstance.writeStartObject();
        jsonGeneratorInstance.writeStringField('currency', currencyIso);
        jsonGeneratorInstance.writeStringField('orderId', orderId);
        jsonGeneratorInstance.writeStringField('amount', String.valueOf(authRequest.amount.setScale(2)));
        jsonGeneratorInstance.writeStringField('merchant_ref', getMerchantRef(authRequest.additionalData));
        if (authRequest?.additionalData != null) {
            if (authRequest.additionalData.containsKey('buyerEmail')) {
                jsonGeneratorInstance.writeStringField('buyerEmail', String.valueOf(authRequest.additionalData.get('buyerEmail')));
            }
            if (authRequest.additionalData.containsKey('redirectUrl')) {
                jsonGeneratorInstance.writeStringField('redirectURL', String.valueOf(authRequest.additionalData.get('redirectUrl')));
            }
        }
        jsonGeneratorInstance.writeEndObject();
        return jsonGeneratorInstance.getAsString();
    }
    
    private String getBTCPayStoreId() {
        // Get from Named Credential or Custom Metadata
        return 'your-store-id';
    }   
    
    private String getMerchantRef(map<String,String> additionalData){
        String merchantRef='';
        if(additionalData!=null && additionalData.containsKey('merchant_ref'))
        {
            merchantRef=additionalData.get('merchant_ref');
        }
        return merchantRef;
    }
}