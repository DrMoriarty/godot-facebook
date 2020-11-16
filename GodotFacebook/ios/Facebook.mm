//
//  Facebook.mm
//
//  Created by Vasiliy on 11.02.19.
//
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import <FBSDKShareKit/FBSDKShareKit.h>
#import "./Facebook.h"
#import <AdSupport/ASIdentifierManager.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach/processor_info.h>
#include <mach/mach_host.h>
#import <sys/utsname.h>

FBSDKLoginManager* loginManager = NULL;
int GodotFacebook::fbCallbackId = 0;


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
        Vector<Variant> vec;
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
        ERR_PRINT([val description].UTF8String);
        ERR_FAIL_V_MSG(Variant(false), "Unknown conversion method for type");
    }
    return Variant(false);
}

NSDictionary *convertFromDictionary(const Dictionary& dict)
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    for(int i=0; i<dict.size(); i++) {
        Variant key = dict.get_key_at_index(i);
        Variant val = dict.get_value_at_index(i);
        if(key.get_type() == Variant::STRING) {
            NSString *strKey = [NSString stringWithUTF8String:((String)key).utf8().get_data()];
            if(val.get_type() == Variant::INT) {
                int i = (int)val;
                result[strKey] = @(i);
            } else if(val.get_type() == Variant::REAL) {
                double d = (double)val;
                result[strKey] = @(d);
            } else if(val.get_type() == Variant::STRING) {
                NSString *s = [NSString stringWithUTF8String:((String)val).utf8().get_data()];
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
@property (nonatomic, assign) int callbackId;
@end

@implementation MyGameRequestDialogDelegate

- (void)gameRequestDialog:(FBSDKGameRequestDialog *)gameRequestDialog didCompleteWithResults:(NSDictionary *)results
{
    Object *obj = ObjectDB::get_instance(_callbackId);
    ERR_FAIL_COND(!obj);
    obj->call_deferred("request_success", convertToVariant(results));
}

- (void)gameRequestDialog:(FBSDKGameRequestDialog *)gameRequestDialog didFailWithError:(NSError *)error
{
    Object *obj = ObjectDB::get_instance(_callbackId);
    ERR_FAIL_COND(!obj);
    obj->call_deferred("request_failed", String(error.description.UTF8String));
}

- (void)gameRequestDialogDidCancel:(FBSDKGameRequestDialog *)gameRequestDialog
{
    Object *obj = ObjectDB::get_instance(_callbackId);
    ERR_FAIL_COND(!obj);
    obj->call_deferred("request_cancelled");
}

@end

GodotFacebook::GodotFacebook()
{
}

GodotFacebook::~GodotFacebook()
{
}

void GodotFacebook::init(const String& key) {
    [[FBSDKApplicationDelegate sharedInstance] application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:nil];
    loginManager = [[FBSDKLoginManager alloc] init];
    [FBSDKSettings setAppID:[NSString stringWithUTF8String:key.utf8().get_data()]];
}

void GodotFacebook::setFacebookCallbackId(int facebookcallbackId) {
    fbCallbackId = facebookcallbackId;
}

int GodotFacebook::getFacebookCallbackId() {
    return fbCallbackId;
}

void GodotFacebook::gameRequest(const String& message, const String& recipient, const String& objectId) {
    
    FBSDKGameRequestDialog *dialog = [[FBSDKGameRequestDialog alloc] init];
    MyGameRequestDialogDelegate *delegate = [[MyGameRequestDialogDelegate alloc] init];
    delegate.callbackId = fbCallbackId;
    dialog.delegate = delegate;
    if (![dialog canShow]) {
        Object *obj = ObjectDB::get_instance(fbCallbackId);
        ERR_FAIL_COND(!obj);
        obj->call_deferred("request_failed", String("Cannot show dialog"));
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

void GodotFacebook::login(const Array& permissions) {
    if (![FBSDKAccessToken currentAccessToken]) {
        UIViewController *vc = [UIApplication.sharedApplication.keyWindow rootViewController];
        NSMutableArray *perms = [NSMutableArray new];
        for(int i=0; i<permissions.size(); i++) {
            Variant p = permissions[i];
            if(p.get_type() == Variant::STRING) {
                [perms addObject:[NSString stringWithUTF8String:((String)p).utf8().get_data()]];
            }
        }
        [loginManager logInWithPermissions:perms fromViewController:vc handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                        Object *obj = ObjectDB::get_instance(fbCallbackId);
                        ERR_FAIL_COND(!obj);
                        if (result.isCancelled) {
                            obj->call_deferred("login_cancelled");
                        } else if(error) {
                            String errString(error.description.UTF8String);
                            obj->call_deferred("login_failed", errString);
                        } else {
                            String token(result.token.tokenString.UTF8String);
                            obj->call_deferred("login_success", token);
                        }
                    });
            }];
    } else {
        Object *obj = ObjectDB::get_instance(fbCallbackId);
        ERR_FAIL_COND(!obj);
        String token(FBSDKAccessToken.currentAccessToken.tokenString.UTF8String);
        obj->call_deferred("login_success", token);
    }
}

void GodotFacebook::logout() {
    [loginManager logOut];
}

bool GodotFacebook::isLoggedIn() {
    if ([FBSDKAccessToken currentAccessToken]) {
        return true;
    } else {
        return false;
    }
}

void GodotFacebook::userProfile(int callbackObject, const String& callbackMethod) {
    NSString *cbMethod = [NSString stringWithUTF8String:callbackMethod.utf8().get_data()];
    FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:@"/me" parameters:nil];
    [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                    Object *obj = ObjectDB::get_instance(callbackObject);
                    ERR_FAIL_COND(!obj);
                    String strCbMethod(cbMethod.UTF8String);
                    if(error) {
                        NSLog(@"FB userProfile error: %@", error);
                        obj->call_deferred(strCbMethod, String(error.description.UTF8String));
                    } else {
                        NSLog(@"FB userProfile result: %@", result);
                        Dictionary map;
                        if([result isKindOfClass:NSDictionary.class]) {
                            obj->call_deferred(strCbMethod, convertToVariant(result));
                        } else {
                            obj->call_deferred(strCbMethod, Variant(false));
                        }
                    }
                });
        }];
}

void GodotFacebook::callApi(const String& path, const Dictionary& properties, int callbackObject, const String& callbackMethod) {

    NSString *cbMethod = [NSString stringWithUTF8String:callbackMethod.utf8().get_data()];
    NSDictionary *paramsDict = convertFromDictionary(properties);
    FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:[NSString stringWithUTF8String:path.utf8().get_data()] parameters:paramsDict];
    [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
            //dispatch_async(dispatch_get_main_queue(), ^{
                    Object *obj = ObjectDB::get_instance(callbackObject);
                    ERR_FAIL_COND(!obj);
                    String strCbMethod(cbMethod.UTF8String);
                    if(error) {
                        NSLog(@"FB callApi error: %@", error);
                        obj->call_deferred(strCbMethod, String(error.description.UTF8String));
                    } else {
                        NSLog(@"FB callApi result: %@", result);
                        if([result isKindOfClass:NSDictionary.class]) {
                            obj->call_deferred(strCbMethod, convertToVariant(result));
                        } else {
                            obj->call_deferred(strCbMethod, Variant(false));
                        }
                    }
                //});
        }];
}

void GodotFacebook::pushToken(const String& token) {
    NSData *data = [NSData dataWithBytes:token.utf8().get_data() length:token.utf8().length()];
    [FBSDKAppEvents setPushNotificationsDeviceToken:data];
}

void GodotFacebook::logEvent(const String& event) {
    NSString *event_name = [NSString stringWithUTF8String:event.utf8().get_data()];
    [FBSDKAppEvents logEvent:event_name];
}

void GodotFacebook::logEventValue(const String& event, double value) {
    NSString *event_name = [NSString stringWithUTF8String:event.utf8().get_data()];
    [FBSDKAppEvents logEvent:event_name valueToSum:value];
}

void GodotFacebook::logEventParams(const String& event, const Dictionary& params) {
    NSString *event_name = [NSString stringWithUTF8String:event.utf8().get_data()];
    NSDictionary *paramsDict = convertFromDictionary(params);
    [FBSDKAppEvents logEvent:event_name parameters:paramsDict];
}

void GodotFacebook::logEventValueParams(const String& event, double value, const Dictionary& params) {
    NSString *event_name = [NSString stringWithUTF8String:event.utf8().get_data()];
    NSDictionary *paramsDict = convertFromDictionary(params);
    [FBSDKAppEvents logEvent:event_name valueToSum:value parameters:paramsDict];
}

String GodotFacebook::advertisingID() {
    NSString *userId = [[[ASIdentifierManager sharedManager]
   advertisingIdentifier] UUIDString];
    String str(userId.UTF8String);
    return str;
}

Array GodotFacebook::extinfo() {
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

void GodotFacebook::_bind_methods()
{
    ClassDB::bind_method(D_METHOD("init"), &GodotFacebook::init);
    ClassDB::bind_method(D_METHOD("setFacebookCallbackId", "param"), &GodotFacebook::setFacebookCallbackId);
    ClassDB::bind_method(D_METHOD("getFacebookCallbackId"), &GodotFacebook::getFacebookCallbackId);
    ClassDB::bind_method(D_METHOD("gameRequest"), &GodotFacebook::gameRequest);
    ClassDB::bind_method(D_METHOD("login"), &GodotFacebook::login);
    ClassDB::bind_method(D_METHOD("logout"), &GodotFacebook::logout);
    ClassDB::bind_method(D_METHOD("isLoggedIn"), &GodotFacebook::isLoggedIn);
    ClassDB::bind_method(D_METHOD("userProfile"), &GodotFacebook::userProfile);
    ClassDB::bind_method(D_METHOD("callApi"), &GodotFacebook::callApi);
    ClassDB::bind_method(D_METHOD("set_push_token", "token"), &GodotFacebook::pushToken);
    ClassDB::bind_method(D_METHOD("log_event", "event"), &GodotFacebook::logEvent);
    ClassDB::bind_method(D_METHOD("log_event_value", "event", "value"), &GodotFacebook::logEventValue);
    ClassDB::bind_method(D_METHOD("log_event_params", "event", "params"), &GodotFacebook::logEventParams);
    ClassDB::bind_method(D_METHOD("log_event_value_params", "event", "value", "params"), &GodotFacebook::logEventValueParams);
    ClassDB::bind_method(D_METHOD("advertising_id"), &GodotFacebook::advertisingID);
    ClassDB::bind_method(D_METHOD("extinfo"), &GodotFacebook::extinfo);
}
