public virtual class RestClient {
    protected String namedCredential;
    
    public enum HttpVerb { XGET, XPOST, XPUT, XPATCH, XDELETE }
    
    public RestClient(String namedCredential) {
        this.namedCredential = namedCredential;
    }
    
    protected virtual HttpResponse makeApiCall(
        HttpVerb method,
        String path,
        String body
    ) {
        return makeApiCall(method, path, body, new Map<String, String>());
    }
    
    protected virtual HttpResponse makeApiCall(
        HttpVerb method,
        String path,
        String body,
        Map<String, String> headers
    ) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setMethod(String.valueOf(method).mid(1));
        request.setEndpoint('callout:' + this.namedCredential + path);
        request.setTimeout(120000);
        
        for (String key : headers.keySet()) {
            request.setHeader(key, headers.get(key));
        }
        
        if (String.isNotBlank(body)) {
            request.setHeader('Content-Type', 'application/json');
            request.setBody(body);
        }
        
        HttpResponse response = http.send(request);
        return response;
    }
    
    public virtual HttpResponse get(String path) {
        return this.makeApiCall(HttpVerb.XGET, path, '');
    }
    
    public virtual HttpResponse post(String path, String body) {
        return this.makeApiCall(HttpVerb.XPOST, path, body);
    }
    
    public virtual HttpResponse put(String path, String body) {
        return this.makeApiCall(HttpVerb.XPUT, path, body);
    }
    
    public virtual HttpResponse patch(String path, String body) {
        return this.makeApiCall(HttpVerb.XPATCH, path, body);
    }
}
