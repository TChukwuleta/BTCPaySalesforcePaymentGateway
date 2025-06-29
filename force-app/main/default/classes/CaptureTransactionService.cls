public with sharing class CaptureTransactionService extends AbstractTransactionService{
    public CaptureTransactionService(commercepayments.paymentGatewayContext gatewayContext){
        super(gatewayContext);
    }

    public override HttpRequest buildRequest(commercepayments.paymentGatewayContext gatewayContext) {
        String body = buildInvoiceRequest((commercepayments.CaptureRequest)gatewayContext.getPaymentRequest());
        HttpRequest req = new HttpRequest();
        buildInvoiceCreationUrl(req);
        req.setBody(body);
        req.setMethod('POST');
        setAuthorizationHeaders(req);
        return req;
    }

    public override commercepayments.GatewayResponse buildResponse(HttpResponse response) {
        String statusCode = String.valueOf(response.getStatusCode());
        if (statusCode != '200' && statusCode != '201') {
            String errorMessage = 'BTCPay Server error: ' + response.getStatusCode() + ' - ' + response.getBody();
            return new commercepayments.GatewayErrorResponse(statusCode, errorMessage);
        }
        Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        Map<String, Object> parsed = new Map<String, Object>();
        commercepayments.CaptureResponse captureResponse = new commercepayments.CaptureResponse();

        String invoiceId = (String) responseData.get('id');
        String invoiceStatus = (String) responseData.get('status');
        String checkoutLink = (String) responseData.get('checkoutLink');
        parsed.put('invoice_id', invoiceId);
        parsed.put('status', invoiceStatus);
        parsed.put('checkoutLink', checkoutLink);
        if (responseData.containsKey('currency')) parsed.put('currency', String.valueOf(responseData.get('currency')));
        if (responseData.containsKey('amount')) {
            String amountValue = String.valueOf(responseData.get('amount'));
            parsed.put('amount', amountValue);
            captureResponse.setAmount(double.valueOf(amountValue));
        }
        captureResponse.setGatewayResultCode(statusCode);
        captureResponse.setGatewayDate(System.now());
        captureResponse.setAsync(true);
        captureResponse.setGatewayMessage(checkoutLink);
        captureResponse.setSalesforceResultCodeInfo(new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.Success));
        captureResponse.setGatewayReferenceNumber(invoiceId);
        captureResponse.setGatewayResultCodeDescription('Bitcoin payment pending');
        captureResponse.setGatewayReferenceDetails(JSON.serialize(parsed));
        return captureResponse;
    }

    private String buildInvoiceRequest(commercepayments.CaptureRequest captureRequest) {
        try {
            Boolean IS_MULTICURRENCY_ORG = UserInfo.isMultiCurrencyOrganization();
            PaymentAuthorization authObject = getAuthObjectForCapture(captureRequest.paymentAuthorizationId,IS_MULTICURRENCY_ORG);
        
            Map<String, Object> refDetailsMap = (Map<String, Object>) JSON.deserializeUntyped(authObject.GatewayRefDetails);
            String transactionId = (String)refDetailsMap.get('transaction_id');
            JSONGenerator jsonGeneratorInstance = JSON.createGenerator(true);
            jsonGeneratorInstance.writeStartObject();
            jsonGeneratorInstance.writeStringField('amount', String.ValueOf((captureRequest.amount*100.0).intValue()));
            jsonGeneratorInstance.writeStringField('originalReference', authObject.GatewayRefNumber);
            jsonGeneratorInstance.writeStringField('orderId', transactionId);
            jsonGeneratorInstance.writeStringField('itemDesc', 'Payment for Transaction Id: ' + transactionId);
            if (IS_MULTICURRENCY_ORG) {
                jsonGeneratorInstance.writeStringField('currency', authObject.get('CurrencyIsoCode').toString());
            } else {
                jsonGeneratorInstance.writeStringField('currency', UserInfo.getDefaultCurrency());
            }
            jsonGeneratorInstance.writeEndObject();
            return jsonGeneratorInstance.getAsString();
        } catch (Exception e) {
            System.debug('Error building BTCPay invoice request: ' + e.getMessage());
            throw e;
        }
    }

    private PaymentAuthorization getAuthObjectForCapture(String authorizationId, Boolean IS_MULTICURRENCY_ORG){
        List<String> listOfFields = new List<String>();
        listOfFields.add('GatewayAuthCode');
        listOfFields.add('GatewayRefNumber');
        listOfFields.add('GatewayRefDetails');
        if (IS_MULTICURRENCY_ORG) {
            listOfFields.add('CurrencyIsoCode');
        }
        PaymentAuthorization authObject = (PaymentAuthorization)DaoService.getSobjectById(authorizationId, listOfFields, PaymentAuthorization.SObjectType);
        return authObject;
    }

}