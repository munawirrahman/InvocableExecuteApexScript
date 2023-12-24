public class InvocableExecuteApexScript implements Queueable, Database.AllowsCallouts{
    // Constants for REST API
    private static final String NON_NAMED_CREDENTIAL_ENDPOINT = URL.getOrgDomainUrl().toExternalForm() + '/services/data/{0}/tooling/executeAnonymous/?anonymousBody={1}';
    private static final String NAMED_CREDENTIAL_ENDPOINT = 'callout:{0}/services/data/{1}/tooling/executeAnonymous/?anonymousBody={2}';
    private static final String OAUTH_TOKEN = '{!$Credential.OAuthToken}';
    private static final String GET_METHOD = 'GET';
    private static final String AUTHORIZATION = 'Authorization';
    private static final String BEARER = 'Bearer ';
    private static final Integer REQUEST_TIMEOUT_MS = 120000;

    // Constants for error message
    private static final String NON_200_ERROR_MESSAGE = 'Callout returns non 200. Status code is : {0}  with response body : {1}';

    // Map Key
    private static final String ENDPOINT_KEY = 'ENDPOINT';
    private static final String AUTH_HEADER_KEY = 'AUTH_HEADER';

    // Other Constants
    private static final String UTF8_ENCODING = 'UTF-8';
    private static final String DEFAULT_API_VERSION = 'v59.0';

    // Request class for invocable method
    public class Request {
        @InvocableVariable(label='Apex Script' required=true)
        public String apexScript;

        @InvocableVariable(label='Named Credential API Name')
        public String namedCredentialApiName;

        @InvocableVariable(label='API Version (Example: v59.0, if empty, automatically defaulted to v59.0')
        public String apiVersion;

        @InvocableVariable(label='Run Asynchronously? (If Named Credential is empty, automatically defaulted to True. If Named Credential is not empty, automatically defaulted to False. If True, will output Job Id only)')
        public Boolean runAsynchronously;
    }
    
    // Response class for invocable method
    public class Response {
        @InvocableVariable(label='(Async) Job ID')
        public Id jobId;

        @InvocableVariable(label='(Sync) Line')
        public Integer line;

        @InvocableVariable(label='(Sync) Column')
        public Integer column;

        @InvocableVariable(label='(Sync) Compiled')
        public Boolean compiled;

        @InvocableVariable(label='(Sync) Success')
        public Boolean success;

        @InvocableVariable(label='(Sync) Compile Problem')
        public String compileProblem;

        @InvocableVariable(label='(Sync) Exception Stack Trace')
        public String exceptionStackTrace;

        @InvocableVariable(label='(Sync) Exception Message')
        public String exceptionMessage;
    }

    // Custom exception class
    public class InvocableExecuteApexScriptException extends Exception {}

    // Invocable method for executing Apex Script
    @InvocableMethod(label='Invocable Execute Apex Script' description='Execute Apex Script within Flow (Synchronously or Asynchronously)' iconName='slds:standard:code_playground' callout=true)
    public static List<Response> invoke(List<Request> requests) {
        List<Response> responseList = new List<Response>();
        
        for (Request curRequest : requests) {
            Response response = new Response();
            
            // Determine API version and if the execution should be asynchronous
            String apiVersion = String.isBlank(curRequest.apiVersion) ? DEFAULT_API_VERSION : curRequest.apiVersion;
            Boolean isRunAsync = curRequest.runAsynchronously == true || String.isBlank(curRequest.namedCredentialApiName) ? true : false;
            
            if (isRunAsync) {
                // Asynchronous execution
                response.jobId = sendRequestAsync(curRequest.namedCredentialApiName, apiVersion, curRequest.apexScript);
            } else {
                // Synchronous execution
                response = sendRequestSync(curRequest.namedCredentialApiName, apiVersion, curRequest.apexScript);
            }
            
            // Add response to the list
            responseList.add(response);
        }
        
        return responseList;
    }

    // Asynchronous execution of the request
    public static Id sendRequestAsync(String namedCredentialApiName, String apiVersion, String apexScript) {
        return System.enqueueJob(new InvocableExecuteApexScript(namedCredentialApiName, apiVersion, apexScript));
    }

    /* Queueable related codes starts here */
    private String namedCredentialApiName;
    private String apiVersion;
    private String apexScript;

    public InvocableExecuteApexScript(String namedCredentialApiName, String apiVersion, String apexScript){
        this.namedCredentialApiName = namedCredentialApiName;
        this.apiVersion = apiVersion;
        this.apexScript = apexScript;
    }
    
    public void execute(QueueableContext context) {
        Response response = sendRequestSync(namedCredentialApiName, apiVersion, apexScript);

        // Throw error on Queueable Job Status Detail
        if(!response.success){
            throwException(JSON.serialize(response, true)); //suppress null values to clear room for Job Status Detail (ExtendedStatus)
        }
    }
    /* Queueable related codes ends here */

    // Synchronous execution of the request
    public static Response sendRequestSync(String namedCredentialApiName, String apiVersion, String apexScript) {
        Response response = new Response();
        
        // Send the request and get the response
        HttpResponse calloutResult = sendRequest(namedCredentialApiName, apiVersion, apexScript);
        
        if (calloutResult.getStatusCode() == 200) {
            // If the status code is 200, deserialize the response
            response = (Response) System.JSON.deserialize(calloutResult.getBody(), Response.class);
        } else {
            // If the status code is not 200, throw an exception with details
            List<String> params = new List<String>{String.valueOf(calloutResult.getStatusCode()), calloutResult.getBody()};
            throwException(String.format(NON_200_ERROR_MESSAGE, params));
        }
        
        return response;
    }

    // Common method to send the HTTP request
    public static HttpResponse sendRequest(String namedCredentialApiName, String apiVersion, String apexScript) {
        HttpResponse response = new HttpResponse();
        try {
            // Build the HTTP request
            HttpRequest request = new HttpRequest();
            Map<String,String> mapEndpointAndAuthHeader = buildEndpointAndAuthHeader(namedCredentialApiName, apiVersion, apexScript);
            request.setEndpoint(mapEndpointAndAuthHeader.get(ENDPOINT_KEY)); 
            request.setHeader(AUTHORIZATION, mapEndpointAndAuthHeader.get(AUTH_HEADER_KEY));
            request.setMethod(GET_METHOD);
            request.setTimeout(REQUEST_TIMEOUT_MS);
            
            // Send the request and get the response
            Http http = new Http();
            response = http.send(request);
        } catch(Exception e) {
            // If an exception occurs, throw a custom exception
            throwException(e.getMessage());
        }
        return response;
    }

    // Build the endpoint URL and authorization header based on the presence of a named credential
    private static Map<String,String> buildEndpointAndAuthHeader(String namedCredentialApiName, String apiVersion, String apexScript) {
        Map<String,String> mapEndpointAndAuthHeader = new Map<String,String>();
        if (!String.isBlank(namedCredentialApiName)) {
            List<String> params = new List<String>{namedCredentialApiName, apiVersion, EncodingUtil.urlEncode(apexScript, UTF8_ENCODING)};
            mapEndpointAndAuthHeader.put(ENDPOINT_KEY, String.format(NAMED_CREDENTIAL_ENDPOINT, params));
            mapEndpointAndAuthHeader.put(AUTH_HEADER_KEY, OAUTH_TOKEN);
        } else {
            List<String> params = new List<String>{apiVersion, EncodingUtil.urlEncode(apexScript, UTF8_ENCODING)};
            mapEndpointAndAuthHeader.put(ENDPOINT_KEY, String.format(NON_NAMED_CREDENTIAL_ENDPOINT, params));
            mapEndpointAndAuthHeader.put(AUTH_HEADER_KEY, BEARER + UserInfo.getSessionId());
        }
        return mapEndpointAndAuthHeader;
    }

    // Helper method to throw a custom exception
    private static void throwException(String message) {
        throw new InvocableExecuteApexScriptException(message);
    }
}