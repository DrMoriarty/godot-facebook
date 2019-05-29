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

FBSDKLoginManager* loginManager = NULL;
int GodotFacebook::fbCallbackId = 0;

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
        ERR_EXPLAIN("Unknown conversion method for type");
        ERR_PRINT([val description].UTF8String);
        return Variant(false);
    }
}

NSDictionary *convertFromDictionary(const Dictionary& dict)
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    for(int i=0; i<dict.size(); i++) {
        Variant key = dict.get_key_at_index(i);
        Variant val = dict.get_value_at_index(i);
        if(key.get_type() == Variant::STRING) {
            NSString *strKey = [NSString stringWithUTF8String:((String)key).utf8().ptr()];
            if(val.get_type() == Variant::INT) {
                int i = (int)val;
                result[strKey] = @(i);
            } else if(val.get_type() == Variant::REAL) {
                double d = (double)val;
                result[strKey] = @(d);
            } else if(val.get_type() == Variant::STRING) {
                NSString *s = [NSString stringWithUTF8String:((String)val).utf8().ptr()];
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
    [FBSDKSettings setAppID:[NSString stringWithUTF8String:key.utf8().ptr()]];
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
    content.message = [NSString stringWithUTF8String:message.utf8().ptr()];
    content.objectID = [NSString stringWithUTF8String:objectId.utf8().ptr()];
    content.recipients = @[ [NSString stringWithUTF8String:recipient.utf8().ptr()] ];
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
                [perms addObject:[NSString stringWithUTF8String:((String)p).utf8().ptr()]];
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
    NSString *cbMethod = [NSString stringWithUTF8String:callbackMethod.utf8().ptr()];
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

    NSString *cbMethod = [NSString stringWithUTF8String:callbackMethod.utf8().ptr()];
    NSDictionary *paramsDict = convertFromDictionary(properties);
    FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:[NSString stringWithUTF8String:path.utf8().ptr()] parameters:paramsDict];
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
}
