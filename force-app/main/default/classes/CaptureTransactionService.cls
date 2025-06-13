public with sharing class CaptureTransactionService extends AbstractTransactionService{
    private static final String BTCPAY_ENDPOINT_INVOICE_STATUS = '/stores/{storeId}/plugin/salesforce/public/invoices/{invoiceId}';
    public CaptureTransactionService(commercepayments.paymentGatewayContext gatewayContext){
        super(gatewayContext);
    }

    public override HttpRequest buildRequest() {
        HttpRequest req = new HttpRequest();
        commercepayments.CaptureRequest captureRequest = (commercepayments.CaptureRequest)gatewayContext.getPaymentRequest();
        // Get the original authorization (invoice) details
        PaymentAuthorization authObject = getAuthObjectForStatusCheck(captureRequest.paymentAuthorizationId);
        String invoiceId = extractInvoiceId(authObject.GatewayRefDetails);
        if (invoiceId == null) {
            throw new PaymentGatewayException('No BTCPay invoice ID found in authorization record');
        }
        String storeId = getBTCPayStoreId();
        String endpoint = BTCPAY_ENDPOINT_INVOICE_STATUS
            .replace('{storeId}', storeId)
            .replace('{invoiceId}', invoiceId);
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        setAuthorizationHeaders(req);
        return req;
    }

    public override commercepayments.GatewayResponse buildResponse(HttpResponse response) {
        String statusCode = String.valueOf(response.getStatusCode());
        Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        commercepayments.CaptureResponse captureResponse = new commercepayments.CaptureResponse();
        Map<String, Object> parsed = new Map<String, Object>();

        if (statusCode == '200') {
            if (responseData.containsKey('id')) parsed.put('invoice_id', String.valueOf(responseData.get('id')));
            if (responseData.containsKey('status')) parsed.put('status', String.valueOf(responseData.get('status')));
            if (responseData.containsKey('checkoutLink')) parsed.put('checkoutLink', String.valueOf(responseData.get('checkoutLink')));
            if (responseData.containsKey('amount')) parsed.put('amount', String.valueOf(responseData.get('amount')));
            if (responseData.containsKey('currency')) parsed.put('currency', String.valueOf(responseData.get('currency')));
            
            captureResponse.setGatewayResultCode(statusCode);
            captureResponse.setGatewayDate(System.now());
            captureResponse.setGatewayReferenceNumber((String) responseData.get('id'));
            captureResponse.setGatewayReferenceDetails(JSON.serialize(parsed));
            String amountStr = (String) responseMap.get('amount');
            if (amountStr != null) {
                captureResponse.setAmount(Decimal.valueOf(amountStr));
            }
            switch on invoiceStatus {
                when 'New' {
                    captureResponse.setGatewayResultCodeDescription('Invoice created but pending payment');
                    captureResponse.setSalesforceResultCodeInfo(getSalesforceResultCodeInfo('PENDING'));
                }
                when 'Settled' {
                    captureResponse.setGatewayResultCodeDescription('Bitcoin payment confirmed and settled');
                    captureResponse.setSalesforceResultCodeInfo(getSalesforceResultCodeInfo('SUCCESS'));
                }
                when 'Processing' {
                    captureResponse.setGatewayResultCodeDescription('Bitcoin payment received');
                    captureResponse.setSalesforceResultCodeInfo(getSalesforceResultCodeInfo('SUCCESS'));
                }
                when 'Expired' {
                    captureResponse.setGatewayResultCodeDescription('Bitcoin payment window expired');
                    captureResponse.setSalesforceResultCodeInfo(getSalesforceResultCodeInfo('CANCELLED'));
                }
                when 'Invalid' {
                    captureResponse.setGatewayResultCodeDescription('Bitcoin payment invalid');
                    captureResponse.setSalesforceResultCodeInfo(getSalesforceResultCodeInfo('CANCELLED'));
                }
            }
        } else {
            String message = responseMap.get('message') != null ? 
                (String) responseMap.get('message') : 'Failed to check BTCPay invoice status';
            return new commercepayments.GatewayErrorResponse(statusCode, message);
        }
        return captureResponse;
    }
    
    private String extractInvoiceId(String gatewayRefDetails) {
        try {
            Map<String, Object> refDetailsMap = (Map<String, Object>) JSON.deserializeUntyped(gatewayRefDetails);
            return (String) refDetailsMap.get('invoice_id');
        } catch (Exception e) {
            System.debug('Error extracting invoice ID: ' + e.getMessage());
            return null;
        }
    }
    
    private PaymentAuthorization getAuthObjectForStatusCheck(String authorizationId) {
        List<String> fields = new List<String>{
            'GatewayRefDetails',
            'GatewayRefNumber',
            'Amount'
        };
        if (UserInfo.isMultiCurrencyOrganization()) {
            fields.add('CurrencyIsoCode');
        }
        return (PaymentAuthorization) DaoService.getSobjectById(
            authorizationId, 
            fields, 
            PaymentAuthorization.SObjectType
        );
    }
    
    private String getBTCPayStoreId() {
        return 'your-store-id';
    }
}