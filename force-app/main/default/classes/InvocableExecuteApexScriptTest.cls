@isTest
private class InvocableExecuteApexScriptTest {
    private static final String MOCK_NAMED_CREDENTIAL_EXISTED = 'TOOLING_NAMED_CRED_EXISTED';
    private static final String MOCK_NAMED_CREDENTIAL_NON_EXISTED = 'TOOLING_NAMED_CRED_NON_EXISTED';
    private static final String MOCK_NAMED_CREDENTIAL_500 = 'TOOLING_NAMED_CRED_500';
    private static final String BASE_URL_SALESFORCE = URL.getOrgDomainUrl().toExternalForm();
    private static final String TOOLING_API_SCRIPT_SUCCESS = 'Account a = [Select Name From Account Where Id = \'0015g00000tl4nqAAA\']; a.Name = \'fyufyufyu\';update a;';
    private static final String TOOLING_API_RESPONSE_SUCCESS = '{ "success" : true, "line" : -1, "compiled" : true, "column" : -1 }';
    //fail missing ;
    private static final String TOOLING_API_SCRIPT_FAIL = 'Account a = [Select Name From Account Where Id = \'0015g00000tl4nqAAA\']; a.Name = \'fyufyufyu\';update a';
    private static final String TOOLING_API_RESPONSE_FAIL = '{ "success" : false, "line" : 2, "compileProblem" : "Unexpected token \'=\'.", "compiled" : false, "column" : 8 }';
    
    private static final String INTERNAL_SERVER_ERROR_RESPONSE = '[{"errorCode":"INTERNAL_SERVER_ERROR","message":"Something went wrong"}]';

    private class responseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if((req.getEndpoint().contains(MOCK_NAMED_CREDENTIAL_EXISTED) || req.getEndpoint().contains(BASE_URL_SALESFORCE)) && req.getEndpoint().contains(EncodingUtil.urlEncode(TOOLING_API_SCRIPT_SUCCESS,'UTF-8'))) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody(TOOLING_API_RESPONSE_SUCCESS);
                res.setStatusCode(200);
            }
            else if((req.getEndpoint().contains(MOCK_NAMED_CREDENTIAL_EXISTED) || req.getEndpoint().contains(BASE_URL_SALESFORCE)) && req.getEndpoint().contains(EncodingUtil.urlEncode(TOOLING_API_SCRIPT_FAIL,'UTF-8'))) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody(TOOLING_API_RESPONSE_FAIL);
                res.setStatusCode(200);
            }
            else if(req.getEndpoint().contains(MOCK_NAMED_CREDENTIAL_NON_EXISTED)){
                CalloutException e = (CalloutException)CalloutException.class.newInstance();
                e.setMessage('Unauthorized endpoint, please check Setup->Security->Remote site settings.');
                throw e;
            }
            else {
                res.setHeader('Content-Type', 'application/json');
                res.setBody(INTERNAL_SERVER_ERROR_RESPONSE);
                res.setStatusCode(500);
            }
            return res;
        }
    }
    
    @isTest
    static void test200AsyncWithNamedCredentialSuccess() {
        Test.setMock(HttpCalloutMock.class, new responseGenerator());

        InvocableExecuteApexScript.Request request = new InvocableExecuteApexScript.Request();
        request.apexScript = TOOLING_API_SCRIPT_SUCCESS;
        request.namedCredentialApiName = MOCK_NAMED_CREDENTIAL_EXISTED;
        request.runAsynchronously = true;

        List<InvocableExecuteApexScript.Request> requests = new List<InvocableExecuteApexScript.Request>();
        requests.add(request);

        Test.startTest();
        List<InvocableExecuteApexScript.Response> responses = InvocableExecuteApexScript.invoke(requests);
        Test.stopTest();

        System.assertEquals(1, responses.size());
        InvocableExecuteApexScript.Response response = responses[0];
        System.assertNotEquals(null, response.jobId);
        AsyncApexJob asyncJob = [SELECT Id, Status FROM AsyncApexJob WHERE Id =:response.jobId LIMIT 1];
        System.assertEquals('Completed', asyncJob.Status);
    }

    @isTest
    static void test200AsyncWithNamedCredentialFail() {
        Test.setMock(HttpCalloutMock.class, new responseGenerator());

        InvocableExecuteApexScript.Request request = new InvocableExecuteApexScript.Request();
        request.apexScript = TOOLING_API_SCRIPT_SUCCESS;
        request.namedCredentialApiName = MOCK_NAMED_CREDENTIAL_NON_EXISTED;
        request.runAsynchronously = true;
        
        List<InvocableExecuteApexScript.Request> requests = new List<InvocableExecuteApexScript.Request>();
        requests.add(request);
        Boolean exceptionThrown = false;
        
        try{
            Test.startTest();
            List<InvocableExecuteApexScript.Response> responses = InvocableExecuteApexScript.invoke(requests);
            Test.stopTest();
        }
        catch(Exception e){
            exceptionThrown = true;
        }
        System.assertEquals(true, exceptionThrown);
    }

    @isTest
    static void test200SyncWithNamedCredentialSuccess() {
        Test.setMock(HttpCalloutMock.class, new responseGenerator());

        InvocableExecuteApexScript.Request request = new InvocableExecuteApexScript.Request();
        request.apexScript = TOOLING_API_SCRIPT_SUCCESS;
        request.namedCredentialApiName = MOCK_NAMED_CREDENTIAL_EXISTED;
        request.runAsynchronously = false;

        List<InvocableExecuteApexScript.Request> requests = new List<InvocableExecuteApexScript.Request>();
        requests.add(request);

        Test.startTest();
        List<InvocableExecuteApexScript.Response> responses = InvocableExecuteApexScript.invoke(requests);
        Test.stopTest();

        System.assertEquals(1, responses.size());
        InvocableExecuteApexScript.Response response = responses[0];
        System.assertEquals(true, response.success);
    }

    @isTest
    static void test200SyncWithNamedCredentialFail() {
        Test.setMock(HttpCalloutMock.class, new responseGenerator());

        InvocableExecuteApexScript.Request request = new InvocableExecuteApexScript.Request();
        request.apexScript = TOOLING_API_SCRIPT_SUCCESS;
        request.namedCredentialApiName = MOCK_NAMED_CREDENTIAL_NON_EXISTED;
        request.runAsynchronously = false;
        
        List<InvocableExecuteApexScript.Request> requests = new List<InvocableExecuteApexScript.Request>();
        requests.add(request);
        Boolean exceptionThrown = false;
        
        try{
            Test.startTest();
            List<InvocableExecuteApexScript.Response> responses = InvocableExecuteApexScript.invoke(requests);
            Test.stopTest();
        }
        catch(Exception e){
            exceptionThrown = true;
        }
        System.assertEquals(true, exceptionThrown);
    }

    @isTest
    static void test200AsyncWithoutNamedCredentialSuccess() {
        Test.setMock(HttpCalloutMock.class, new responseGenerator());

        InvocableExecuteApexScript.Request request = new InvocableExecuteApexScript.Request();
        request.apexScript = TOOLING_API_SCRIPT_SUCCESS;
        request.runAsynchronously = true;

        List<InvocableExecuteApexScript.Request> requests = new List<InvocableExecuteApexScript.Request>();
        requests.add(request);

        Test.startTest();
        List<InvocableExecuteApexScript.Response> responses = InvocableExecuteApexScript.invoke(requests);
        Test.stopTest();

        System.assertEquals(1, responses.size());
        InvocableExecuteApexScript.Response response = responses[0];
        System.assertNotEquals(null, response.jobId);
    }

    @isTest
    static void test200AsyncWithoutNamedCredentialFail() {
        Test.setMock(HttpCalloutMock.class, new responseGenerator());

        InvocableExecuteApexScript.Request request = new InvocableExecuteApexScript.Request();
        request.apexScript = TOOLING_API_SCRIPT_FAIL;
        request.runAsynchronously = true;

        List<InvocableExecuteApexScript.Request> requests = new List<InvocableExecuteApexScript.Request>();
        requests.add(request);

        Boolean exceptionThrown = false;
        
        try{
            Test.startTest();
            List<InvocableExecuteApexScript.Response> responses = InvocableExecuteApexScript.invoke(requests);
            Test.stopTest();
        }
        catch(Exception e){
            exceptionThrown = true;
        }
        System.assertEquals(true, exceptionThrown);
    }

    @isTest
    static void testNon200Async() {
        Test.setMock(HttpCalloutMock.class, new responseGenerator());

        InvocableExecuteApexScript.Request request = new InvocableExecuteApexScript.Request();
        request.apexScript = 'some-script';
        request.runAsynchronously = true;

        List<InvocableExecuteApexScript.Request> requests = new List<InvocableExecuteApexScript.Request>();
        requests.add(request);

        Boolean exceptionThrown = false;
        
        try{
            Test.startTest();
            List<InvocableExecuteApexScript.Response> responses = InvocableExecuteApexScript.invoke(requests);
            Test.stopTest();
        }
        catch(Exception e){
            exceptionThrown = true;
        }
        System.assertEquals(true, exceptionThrown);
    }

    @isTest
    static void testNon200Sync() {
        Test.setMock(HttpCalloutMock.class, new responseGenerator());

        InvocableExecuteApexScript.Request request = new InvocableExecuteApexScript.Request();
        request.apexScript = 'some-script';
        request.namedCredentialApiName = MOCK_NAMED_CREDENTIAL_500;
        request.runAsynchronously = false;

        List<InvocableExecuteApexScript.Request> requests = new List<InvocableExecuteApexScript.Request>();
        requests.add(request);

        Boolean exceptionThrown = false;
        
        try{
            Test.startTest();
            List<InvocableExecuteApexScript.Response> responses = InvocableExecuteApexScript.invoke(requests);
            Test.stopTest();
        }
        catch(Exception e){
            exceptionThrown = true;
        }
        System.assertEquals(true, exceptionThrown);
    }
}