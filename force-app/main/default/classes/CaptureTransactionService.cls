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
            String errorMessage = 'BTCPay Server error: ' + res.getStatusCode() + ' - ' + res.getBody();
            return new commercepayments.GatewayErrorResponse(statusCode, errorMessage);
        }
        Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        Map<String, Object> parsed = new Map<String, Object>();
        commercepayments.CaptureResponse captureResponse = new commercepayments.CaptureResponse();

        String invoiceId = (String) invoiceResponse.get('id');
        String invoiceStatus = (String) invoiceResponse.get('status');
        String checkoutLink = (String) invoiceResponse.get('checkoutLink');
        parsed.put('invoice_id', invoiceId);
        parsed.put('status', invoiceStatus);
        parsed.put('checkoutLink', checkoutLink);
        if (responseData.containsKey('currency')) parsed.put('currency', String.valueOf(responseData.get('currency')));
        if (responseData.containsKey('amount')) {
            String amountValue = String.valueOf(responseData.get('amount'));
            parsed.put('amount', amountValue);
            captureResponse.setAmount(double.valueOf(amountValue));
        }
        captureResponse.setGatewayAuthCode(checkoutLink);
        captureResponse.setGatewayResultCode(statusCode);
        captureResponse.setGatewayDate(System.now());
        captureResponse.setGatewayReferenceNumber(invoiceId);
        captureResponse.setGatewayResultCodeDescription('Bitcoin payment pending');
        captureResponse.setGatewayReferenceDetails(JSON.serialize(parsed));
        return captureResponse;
    }

    private String buildInvoiceRequest(commercepayments.CaptureRequest captureRequest) {
        try {
            Map<String, Object> invoiceRequest = new Map<String, Object>();
            invoiceRequest.put('amount', captureRequest.getAmount());
            invoiceRequest.put('currency', captureRequest.getCurrencyIsoCode());
            invoiceRequest.put('orderId', captureRequest.getGatewayReferenceNumber());
            invoiceRequest.put('itemDesc', 'Payment for Order: ' + captureRequest.getGatewayReferenceNumber());
            return JSON.serialize(invoiceRequest);
        } catch (Exception e) {
            System.debug('Error building BTCPay invoice request: ' + e.getMessage());
            throw e;
        }
    }

}