//
//  Facebook.mm
//
//  Created by DrMoriarty on 11.02.19.
//
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "./Facebook.hpp"
@import FBSDKCoreKit;
@import FBSDKLoginKit;
@import FBSDKShareKit;
#import <AdSupport/ASIdentifierManager.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach/processor_info.h>
#include <mach/mach_host.h>
#import <sys/utsname.h>

using namespace godot;

FBSDKLoginManager* loginManager = NULL;
Object* FacebookPlugin::fbCallbackObj = NULL;


#define FB_ARRAY_COUNT(x) sizeof(x) / sizeof(x[0])

uint _readSysCtlUInt(int ctl, int type) {
  int mib[2] = {ctl, type};
  uint value;
  size_t size = sizeof value;
  if (0 != sysctl(mib, FB_ARRAY_COUNT(mib), &value, &size, NULL, 0)) {
    return 0;
  }
  return value;
}

uint _coreCount() {
    return _readSysCtlUInt(CTL_HW, HW_AVAILCPU);
}

static const u_int FB_GIGABYTE = 1024 * 1024 * 1024;  // bytes

NSNumber * _getTotalDiskSpace() {
    NSDictionary *attrs = [[[NSFileManager alloc] init] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    return [attrs objectForKey:NSFileSystemSize];
}

NSNumber * _getRemainingDiskSpace() {
    NSDictionary *attrs = [[[NSFileManager alloc] init] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    return [attrs objectForKey:NSFileSystemFreeSize];
}

Variant convertToVariant(id val)
{
    if([val isKindOfClass:NSDictionary.class]) {
        NSDictionary *nsd = (NSDictionary*)val;
        Dictionary dict;
        for(NSString *key in nsd.allKeys) {
            String k(key.UTF8String);
            dict[k] = convertToVariant(nsd[key]);
        }
        return Variant(dict);
    } else if([val isKindOfClass:NSArray.class]) {
        Array vec;
        for(id el in (NSArray*)val) {
            vec.push_back(convertToVariant(el));
        }
        return Variant(vec);
    } else if([val isKindOfClass:NSNumber.class]) {
        NSNumber *n = (NSNumber*)val;
        float f = n.floatValue;
        return Variant(f);
    } else if([val isKindOfClass:NSString.class]) {
        NSString *s = (NSString*)val;
        String str(s.UTF8String);
        return Variant(str);
    } else {
        // error
        NSString *err = [NSString stringWithFormat:@"Unknown conversion method for type: %@", [val description]];
        ERR_PRINT(err.UTF8String);
    }
    return Variant(false);
}

NSDictionary *convertFromDictionary(const Dictionary& dict)
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    for(int i=0; i<dict.size(); i++) {
        Variant key = dict.keys()[i];
        Variant val = dict.values()[i];
        if(key.get_type() == Variant::STRING) {
            String skey = key;
            NSString *strKey = [NSString stringWithUTF8String:skey.utf8().get_data()];
            if(val.get_type() == Variant::INT) {
                int i = (int)val;
                result[strKey] = @(i);
            } else if(val.get_type() == Variant::REAL) {
                double d = (double)val;
                result[strKey] = @(d);
            } else if(val.get_type() == Variant::STRING) {
                String sval = val;
                NSString *s = [NSString stringWithUTF8String:sval.utf8().get_data()];
                result[strKey] = s;
            } else if(val.get_type() == Variant::BOOL) {
                BOOL b = (bool)val;
                result[strKey] = @(b);
            } else {
                ERR_PRINT("Unexpected type as dictionary value");
            }
        } else {
            ERR_PRINT("Non string key in Dictionary");
        }
    }
    return result;
}

@interface MyGameRequestDialogDelegate : NSObject <FBSDKGameRequestDialogDelegate>
@property (nonatomic, assign) Object *callbackOb;
@end

@implementation MyGameRequestDialogDelegate

- (void)gameRequestDialog:(FBSDKGameRequestDialog *)gameRequestDialog didCompleteWithResults:(NSDictionary *)results
{
    ERR_FAIL_COND(!_callbackOb);
    _callbackOb->call_deferred("request_success", convertToVariant(results));
}

- (void)gameRequestDialog:(FBSDKGameRequestDialog *)gameRequestDialog didFailWithError:(NSError *)error
{
    ERR_FAIL_COND(!_callbackOb);
    _callbackOb->call_deferred("request_failed", String(error.description.UTF8String));
}

- (void)gameRequestDialogDidCancel:(FBSDKGameRequestDialog *)gameRequestDialog
{
    ERR_FAIL_COND(!_callbackOb);
    _callbackOb->call_deferred("request_cancelled");
}

@end

FacebookPlugin::FacebookPlugin()
{
}

FacebookPlugin::~FacebookPlugin()
{
}

void FacebookPlugin::_init()
{
}

void FacebookPlugin::init(const String& key) {
    [[FBSDKApplicationDelegate sharedInstance] application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil];
    loginManager = [[FBSDKLoginManager alloc] init];
    [FBSDKSettings setAppID:[NSString stringWithUTF8String:key.utf8().get_data()]];
}

void FacebookPlugin::setFacebookCallbackId(Object* facebookcallback) {
    fbCallbackObj = facebookcallback;
}

void FacebookPlugin::gameRequest(const String& message, const String& recipient, const String& objectId) {
    
    FBSDKGameRequestDialog *dialog = [[FBSDKGameRequestDialog alloc] init];
    MyGameRequestDialogDelegate *delegate = [[MyGameRequestDialogDelegate alloc] init];
    delegate.callbackOb = fbCallbackObj;
    dialog.delegate = delegate;
    if (![dialog canShow]) {
        ERR_FAIL_COND(!fbCallbackObj);
        fbCallbackObj->call_deferred("request_failed", String("Cannot show dialog"));
        return;
    }
        
    FBSDKGameRequestContent *content = [[FBSDKGameRequestContent alloc] init];
        
    //content.filters = FBSDKGameRequestFilterNone;
    //content.filters = FBSDKGameRequestFilterAppUsers;
    //content.filters = FBSDKGameRequestFilterAppNonUsers;
        
    //content.data = params[@"data"];
    content.message = [NSString stringWithUTF8String:message.utf8().get_data()];
    content.objectID = [NSString stringWithUTF8String:objectId.utf8().get_data()];
    content.recipients = @[ [NSString stringWithUTF8String:recipient.utf8().get_data()] ];
    //content.title = params[@"title"];
        
    dialog.content = content;
    [dialog show];
}

void FacebookPlugin::login(const Array permissions) {
    if (![FBSDKAccessToken currentAccessToken]) {
        UIViewController *vc = [UIApplication.sharedApplication.keyWindow rootViewController];
        NSMutableArray *perms = [NSMutableArray new];
        for(int i=0; i<permissions.size(); i++) {
            Variant p = permissions[i];
            if(p.get_type() == Variant::STRING) {
                String sp = p;
                [perms addObject:[NSString stringWithUTF8String:sp.utf8().get_data()]];
            }
        }
        [loginManager logInWithPermissions:perms fromViewController:vc handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                        ERR_FAIL_COND(!fbCallbackObj);
                        if (result.isCancelled) {
                            fbCallbackObj->call_deferred("login_cancelled");
                        } else if(error) {
                            String errString(error.description.UTF8String);
                            fbCallbackObj->call_deferred("login_failed", errString);
                        } else {
                            String token(result.token.tokenString.UTF8String);
                            fbCallbackObj->call_deferred("login_success", token);
                        }
                    });
            }];
    } else {
        ERR_FAIL_COND(!fbCallbackObj);
        String token(FBSDKAccessToken.currentAccessToken.tokenString.UTF8String);
        fbCallbackObj->call_deferred("login_success", token);
    }
}

void FacebookPlugin::logout() {
    [loginManager logOut];
}

bool FacebookPlugin::isLoggedIn() {
    if ([FBSDKAccessToken currentAccessToken]) {
        return true;
    } else {
        return false;
    }
}

void FacebookPlugin::userProfile(Object *callbackOb, const String& callbackMethod) {
    NSString *cbMethod = [NSString stringWithUTF8String:callbackMethod.utf8().get_data()];
    FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:@"/me" parameters:nil];
    [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                    ERR_FAIL_COND(!callbackOb);
                    String strCbMethod(cbMethod.UTF8String);
                    if(error) {
                        NSLog(@"FB userProfile error: %@", error);
                        callbackOb->call_deferred(strCbMethod, String(error.description.UTF8String));
                    } else {
                        NSLog(@"FB userProfile result: %@", result);
                        Dictionary map;
                        if([result isKindOfClass:NSDictionary.class]) {
                            callbackOb->call_deferred(strCbMethod, convertToVariant(result));
                        } else {
                            callbackOb->call_deferred(strCbMethod, Variant(false));
                        }
                    }
                });
        }];
}

void FacebookPlugin::callApi(const String& path, const Dictionary properties, Object *callbackOb, const String& callbackMethod) {

    NSString *cbMethod = [NSString stringWithUTF8String:callbackMethod.utf8().get_data()];
    NSDictionary *paramsDict = convertFromDictionary(properties);
    FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:[NSString stringWithUTF8String:path.utf8().get_data()] parameters:paramsDict];
    [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
            //dispatch_async(dispatch_get_main_queue(), ^{
                    ERR_FAIL_COND(!callbackOb);
                    String strCbMethod(cbMethod.UTF8String);
                    if(error) {
                        NSLog(@"FB callApi error: %@", error);
                        callbackOb->call_deferred(strCbMethod, String(error.description.UTF8String));
                    } else {
                        NSLog(@"FB callApi result: %@", result);
                        if([result isKindOfClass:NSDictionary.class]) {
                            callbackOb->call_deferred(strCbMethod, convertToVariant(result));
                        } else {
                            callbackOb->call_deferred(strCbMethod, Variant(false));
                        }
                    }
                //});
        }];
}

void FacebookPlugin::pushToken(const String& token) {
    NSData *data = [NSData dataWithBytes:token.utf8().get_data() length:token.utf8().length()];
    [FBSDKAppEvents setPushNotificationsDeviceToken:data];
}

void FacebookPlugin::logEvent(const String& event) {
    NSString *event_name = [NSString stringWithUTF8String:event.utf8().get_data()];
    [FBSDKAppEvents logEvent:event_name];
}

void FacebookPlugin::logEventValue(const String& event, double value) {
    NSString *event_name = [NSString stringWithUTF8String:event.utf8().get_data()];
    [FBSDKAppEvents logEvent:event_name valueToSum:value];
}

void FacebookPlugin::logEventParams(const String& event, const Dictionary params) {
    NSString *event_name = [NSString stringWithUTF8String:event.utf8().get_data()];
    NSDictionary *paramsDict = convertFromDictionary(params);
    [FBSDKAppEvents logEvent:event_name parameters:paramsDict];
}

void FacebookPlugin::logEventValueParams(const String& event, double value, const Dictionary params) {
    NSString *event_name = [NSString stringWithUTF8String:event.utf8().get_data()];
    NSDictionary *paramsDict = convertFromDictionary(params);
    [FBSDKAppEvents logEvent:event_name valueToSum:value parameters:paramsDict];
}

String FacebookPlugin::advertisingID() {
    NSString *userId = [[[ASIdentifierManager sharedManager]
   advertisingIdentifier] UUIDString];
    String str(userId.UTF8String);
    return str;
}

Array FacebookPlugin::extinfo() {
    Array res;
    
    //NSMutableString *ei = [NSMutableString new];
    //[ei appendString:@"i2"];
    res.append(Variant(String("i2")));

    NSBundle *mainBundle = NSBundle.mainBundle;
    //[ei appendFormat:@",%@", mainBundle.bundleIdentifier];
    res.append(Variant(String(mainBundle.bundleIdentifier.UTF8String)));

    //[ei appendFormat:@",%@", [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]];
    res.append(Variant(String([[mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] UTF8String])));

    //[ei appendFormat:@",%@", [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    res.append(Variant(String([[mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] UTF8String])));

    UIDevice *device = [UIDevice currentDevice];
    //[ei appendFormat:@",%@", device.systemVersion];
    res.append(Variant(String(device.systemVersion.UTF8String)));

    struct utsname systemInfo;
    uname(&systemInfo);
    //[ei appendFormat:@",%@", @(systemInfo.machine)];
    res.append(Variant(String([NSString stringWithFormat:@"%@", @(systemInfo.machine)].UTF8String)));

    //[ei appendFormat:@",%@", [[NSLocale currentLocale] localeIdentifier]];
    res.append(Variant(String(NSLocale.currentLocale.localeIdentifier.UTF8String)));

    NSTimeZone *timeZone = [NSTimeZone systemTimeZone];
    //[ei appendFormat:@",%@", timeZone.abbreviation];
    res.append(Variant(String(timeZone.abbreviation.UTF8String)));

    CTTelephonyNetworkInfo *networkInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [networkInfo subscriberCellularProvider];
    //[ei appendFormat:@",%@", [carrier carrierName] ?: @"NoCarrier"];
    res.append(Variant(String(([carrier carrierName] ?: @"NoCarrier").UTF8String)));

    UIScreen *sc = [UIScreen mainScreen];
    CGRect sr = sc.bounds;
    unsigned long _width = (unsigned long)sr.size.width;
    unsigned long _height = (unsigned long)sr.size.height;
    NSString *densityString = sc.scale ? [NSString stringWithFormat:@"%.02f", sc.scale] : @"";

    //[ei appendFormat:@",%ld,%ld,%@", _width, _height, densityString];
    res.append(Variant((unsigned int)_width));
    res.append(Variant((unsigned int)_height));
    res.append(Variant(String(densityString.UTF8String)));

    //[ei appendFormat:@",%d", _coreCount()];
    res.append(Variant(_coreCount()));

    // Total disk space
    float totalDiskSpace = [_getTotalDiskSpace() floatValue];
    unsigned long long _totalDiskSpaceGB = (unsigned long long)round(totalDiskSpace / FB_GIGABYTE);

    // Remaining disk space
    float remainingDiskSpace = [_getRemainingDiskSpace() floatValue];
    unsigned long long _remainingDiskSpaceGB = (unsigned long long)round(remainingDiskSpace / FB_GIGABYTE);
    
    //[ei appendFormat:@",%ld,%ld", (long)_totalDiskSpaceGB, (long)_remainingDiskSpaceGB];
    res.append(Variant(_totalDiskSpaceGB));
    res.append(Variant(_remainingDiskSpaceGB));

    //[ei appendFormat:@",%@", timeZone.name];
    res.append(Variant(String(timeZone.name.UTF8String)));

    //String str(ei.UTF8String);
    return res;
}

void FacebookPlugin::_register_methods()
{
    register_method("_init", &FacebookPlugin::_init);
    register_method("init", &FacebookPlugin::init);
    register_method("setFacebookCallbackId", &FacebookPlugin::setFacebookCallbackId);
    register_method("gameRequest", &FacebookPlugin::gameRequest);
    register_method("login", &FacebookPlugin::login);
    register_method("logout", &FacebookPlugin::logout);
    register_method("isLoggedIn", &FacebookPlugin::isLoggedIn);
    register_method("userProfile", &FacebookPlugin::userProfile);
    register_method("callApi", &FacebookPlugin::callApi);
    register_method("set_push_token", &FacebookPlugin::pushToken);
    register_method("log_event", &FacebookPlugin::logEvent);
    register_method("log_event_value", &FacebookPlugin::logEventValue);
    register_method("log_event_params", &FacebookPlugin::logEventParams);
    register_method("log_event_value_params", &FacebookPlugin::logEventValueParams);
    register_method("advertising_id", &FacebookPlugin::advertisingID);
    register_method("extinfo", &FacebookPlugin::extinfo);
}
