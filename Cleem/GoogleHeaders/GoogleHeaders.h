#ifndef GoogleHeaders_h
#define GoogleHeaders_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// GIDSignIn для совместимости с GoogleSignIn
@interface GIDSignIn : NSObject
+ (instancetype)sharedInstance;
- (BOOL)handleURL:(NSURL *)url;
- (BOOL)hasPreviousSignIn;
- (void)restorePreviousSignIn:(void (^)(id _Nullable user, NSError * _Nullable error))completion;
@end

// GIDConfiguration
@interface GIDConfiguration : NSObject
- (instancetype)initWithClientID:(NSString *)clientID;
@property(nonatomic, copy, readonly) NSString *clientID;
@end

// GIDGoogleUser
@interface GIDProfileData : NSObject
@property(nonatomic, copy, nullable) NSString *name;
@property(nonatomic, copy, nullable) NSString *email;
@property(nonatomic, nullable) NSURL *imageURL;
- (NSURL *)imageURLWithDimension:(NSUInteger)dimension;
@end

@interface GIDToken : NSObject
@property(nonatomic, readonly) NSString *tokenString;
@end

@interface GIDAuthentication : NSObject
@property(nonatomic, readonly, nullable) GIDToken *idToken;
@property(nonatomic, readonly) GIDToken *accessToken;
@end

@interface GIDGoogleUser : NSObject
@property(nonatomic, copy, nullable) NSString *userID;
@property(nonatomic, nullable) GIDProfileData *profile;
@property(nonatomic, readonly) GIDAuthentication *authentication;
@end

// Объявления для App Auth и зависимостей
@interface GTMAppAuth : NSObject
@end

@interface GTMSessionFetcher : NSObject
@end

@interface GTMSessionFetcherService : NSObject
@end

@interface GTMSessionFetcherUserData : NSObject
@end

// Декларации для совместимости
@interface AppAuth : NSObject
@end

@interface GTMAppAuthFetcher : NSObject
@end

#endif /* GoogleHeaders_h */ 