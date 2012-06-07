#import "CHTTPRequest.h"

#include <assert.h>

#include <curl/curl.h>

@implementation CHTTPRequest {
    CURL* _curl;

    void (^_completionBlock)(CHTTPRequest* req);
    void (^_failedBlock)(CHTTPRequest* req);
}

@synthesize url = url_;
@synthesize requestMethod = requestMethod_;
@synthesize timeout = timeout_;
@synthesize clientCertificate = clientCertificate_,
    clientCertificateKey = clientCertificateKey_;
@synthesize validatesSecureCertificate = validatesSecureCertificate_;
@synthesize postValue = postValue_;

@synthesize error = error_;
@synthesize rawResponseData = rawResponseData_;
@synthesize responseString = responseString_;

static NSString* _defaultUserAgentString = nil;

static size_t curl_read_handler(void* ptr, size_t size, size_t nmemb, void* stream) {
    CHTTPRequest* self = (CHTTPRequest*)stream;
    [self.rawResponseData appendBytes:ptr length:size*nmemb];
    return size*nmemb;
}

-(id)init {
    self = [super init];
    if (self) {
        self->_curl = curl_easy_init();
        assert(self->_curl);

        self.requestMethod = @"GET";
        self.timeout = 10;
        self.validatesSecureCertificate = YES;

        self.postValue = [NSMutableArray array];

        self.rawResponseData = [NSMutableData data];
    }
    return self;
}

-(id)initWithURL:(NSURL*)url {
    self = [self init];
    if (self) {
        self.url = url;
    }
    return self;
}

-(void)dealloc {
#ifdef DEBUG
    NSLog(@"%s", __PRETTY_FUNCTION__);
#endif

    curl_easy_cleanup(self->_curl);
    self.url = nil;
    self.requestMethod = nil;
    self.rawResponseData = nil;
    self.postValue = nil;

    self.clientCertificate = nil;
    self.clientCertificateKey = nil;

    if (_completionBlock) [_completionBlock release];
    if (_failedBlock) [_failedBlock release];

    self.error = nil;
    self.rawResponseData = nil;
    self.responseString = nil;

    [super dealloc];
}

+(CHTTPRequest*)requestWithURL:(NSURL*)url {
    return [[[CHTTPRequest alloc] initWithURL:url] autorelease];
}

+(NSString*)defaultUserAgentString {
    return _defaultUserAgentString;
}

+(void)setDefaultUserAgentString:(NSString*)agent {
    if (_defaultUserAgentString) {
        [_defaultUserAgentString release];
        _defaultUserAgentString = nil;
    }

    _defaultUserAgentString = [agent copy];
}

-(void)setCompletionBlock:(void (^)(CHTTPRequest* req))callback {
    if (_completionBlock) {
        [_completionBlock release];
        _completionBlock = nil;
    }

    _completionBlock = [callback copy];
}

-(void)setFailedBlock:(void (^)(CHTTPRequest* req))callback {
    if (_failedBlock) {
        [_failedBlock release];
        _failedBlock = nil;
    }

    _failedBlock = [callback copy];
}

-(void)startAsynchronous {
    // set UA
    if (nil == _defaultUserAgentString) {
        NSDictionary* info = [[NSBundle mainBundle] infoDictionary];
        if (info) {
            NSString* ver = [info objectForKey:@"CFBundleVersion"];
            NSString* product = [info objectForKey:@"CFBundleName"];
            NSString* ua = [NSString stringWithFormat:@"%@/%@", product, ver];
            [CHTTPRequest setDefaultUserAgentString:ua];
        }
    }

    if (_defaultUserAgentString) {
        curl_easy_setopt(self->_curl, CURLOPT_USERAGENT, [_defaultUserAgentString UTF8String]);
    }

    __block void (^runner)(void) = [^{
        CURLcode r;
        CURL* curl = self->_curl;

        r = curl_easy_setopt(curl, CURLOPT_URL, [[self.url absoluteString] UTF8String]);
        assert(0 == r);

        r = curl_easy_setopt(curl, CURLOPT_TIMEOUT, self.timeout);
        assert(0 == r);

        struct curl_slist* slist = NULL;
        slist = curl_slist_append(slist, "Expect:");
        r = curl_easy_setopt(curl, CURLOPT_HTTPHEADER, slist);
        assert(0 == r);

        r = curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_read_handler);
        assert(0 == r);
        r = curl_easy_setopt(curl, CURLOPT_FILE, self);
        assert(0 == r);

        if (self.clientCertificate) {
            r = curl_easy_setopt(curl, CURLOPT_SSLCERT, [self.clientCertificate UTF8String]);
            assert(0 == r);
        }
        if (self.clientCertificateKey) {
            r = curl_easy_setopt(curl, CURLOPT_SSLKEY, [self.clientCertificateKey UTF8String]);
            assert(0 == r);
        }
        if (NO == self.validatesSecureCertificate) {
            r = curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0);
            assert(0 == r);
        }

        if ([self.postValue count]) {
            NSString* postFields = [self.postValue componentsJoinedByString:@"&"];
            r = curl_easy_setopt(curl, CURLOPT_POSTFIELDS, [postFields UTF8String]);
            assert(0 == r);

            r = curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, [postFields lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
            assert(0 == r);
        }

        r = curl_easy_perform(curl);
        if (r) {
            self.error = [NSString stringWithUTF8String:curl_easy_strerror(r)];
            if (_failedBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{ _failedBlock(self); });
            }
        }
        else {
            NSString* responseString = [[NSString alloc] initWithData:self.rawResponseData encoding:NSUTF8StringEncoding];
            self.responseString = responseString;
            [responseString release];

            if (_completionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{ _completionBlock(self); });
            }
        }

        curl_slist_free_all(slist);

        [runner release];
    } copy];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), runner);
}

-(void)addPostValue:(NSString*)value forKey:(NSString*)key {
    char* encoded_key   = curl_easy_escape(self->_curl, [key UTF8String], [key lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    char* encoded_value = curl_easy_escape(self->_curl, [value UTF8String], [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);

    NSString* query = [NSString stringWithFormat:@"%s=%s", encoded_key, encoded_value];
    curl_free(encoded_key);
    curl_free(encoded_value);

    [self.postValue addObject:query];
}

@end
