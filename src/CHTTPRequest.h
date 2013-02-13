#import <Foundation/Foundation.h>

@interface CHTTPRequest : NSObject

@property (retain) NSURL* url;
@property (copy) NSString* requestMethod;
@property (assign) NSUInteger timeout;
@property (copy) NSString* clientCertificate;
@property (copy) NSString* clientCertificateKey;
@property (assign) BOOL validatesSecureCertificate;
@property (copy) NSString* caInfo;

@property (retain) NSMutableArray* postValue;
@property (retain) NSData* postBody;

@property (copy) NSString* error;
@property (retain) NSMutableData* rawResponseData;
@property (copy) NSString* responseString;

+(CHTTPRequest*)requestWithURL:(NSURL*)url;
-(id)initWithURL:(NSURL*)url;

+(NSString*)defaultUserAgentString;
+(void)setDefaultUserAgentString:(NSString*)agent;

-(void)setCompletionBlock:(void (^)(CHTTPRequest* req))callback;
-(void)setFailedBlock:(void (^)(CHTTPRequest* req))callback;

-(void)addPostValue:(NSString*)value forKey:(NSString*)key;

-(void)startAsynchronous;

@end
