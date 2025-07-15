//
//  GamePotWebView.h
//  GamePot
//
//  Created by Lee Chungwon on 29/09/2018.
//  Copyright © 2018 itsB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "GamePotHandler.h"
#import "GamePotGraphQLRequest.h"

@interface GamePotAgreeOption:NSObject

typedef NS_ENUM(NSInteger, THEME) {
    BLUE = 0,
    GREEN = 1,
    
    MATERIAL_RED = 2,
    MATERIAL_BLUE = 3,
    MATERIAL_ORANGE = 4,
    MATERIAL_PURPLE = 5,
    MATERIAL_YELLOW = 6,
    MATERIAL_GRAPE = 7,
    MATERIAL_GREEN = 8,
    MATERIAL_PEACH = 9,
    MATERIAL_CYAN = 10,
    MATERIAL_DARKBULE = 11,
    MATERIAL_GRAY = 12,
    
};

@property(nonatomic) NSArray<NSNumber*>* headerBackGradient;
@property(nonatomic) int headerBottomColor;
@property(nonatomic) UIImage* headerIcon;
@property(nonatomic) NSString* headerTitle;
@property(nonatomic) int headerTitleColor;

@property(nonatomic) NSArray<NSNumber*>* contentBackGradient;
@property(nonatomic) UIImage* contentIcon;
@property(nonatomic) int contentIconColor;
@property(nonatomic) int contentCheckColor;
@property(nonatomic) int contentTitleColor;
@property(nonatomic) int contentShowColor;

@property(nonatomic) int footerTopColor;
@property(nonatomic) NSArray<NSNumber*>* footerBackGradient;
@property(nonatomic) NSArray<NSNumber*>* footerButtonGradient;
@property(nonatomic) int footerButtonOutlineColor;
@property(nonatomic) NSString* footerTitle;
@property(nonatomic) int footerTitleColor;

@property(nonatomic) BOOL showNightPush;
@property(nonatomic) BOOL showPush;

@property(nonatomic) NSString* allMessage;

@property(nonatomic) NSString* termMessage;
@property(nonatomic) NSString* termDetailURL;

@property(nonatomic) NSString* privacyMessage;
@property(nonatomic) NSString* privacyDetailURL;

@property(nonatomic) NSString* pushMessage;
@property(nonatomic) NSString* pushDetailURL;

@property(nonatomic) NSString* nightPushMessage;
@property(nonatomic) NSString* nightPushDetailURL;

@property(nonatomic) NSString* emailVerifiedMessage;
@property(nonatomic) NSString* emailVerifiedDetailURL;
@property(nonatomic) BOOL emailVerifiedRequired;

// GDPR 관련 데이터 추가 필요
@property(nonatomic) BOOL showToastPushStatus;

@property(nonatomic) NSString* GDPRDetailURL;
@property(nonatomic) NSString* adCustomDetailURL;
@property(nonatomic) NSString* adNoCustomDetailURL;

@property(nonatomic) NSString* currentCountry; // KR인 경우에 NightPush 노출

// age
@property(nonatomic) NSString* ageTitle;
@property(nonatomic) NSString* ageDescription;
@property(nonatomic) NSString* ageOverMessage;
@property(nonatomic) NSString* ageUnderMessage;
@property(nonatomic) BOOL ageCertificationShow;

// email
@property(nonatomic) NSString* emailBack;
@property(nonatomic) NSString* emailTitle;
@property(nonatomic) NSString* emailSend;
@property(nonatomic) NSString* emailConfirm;
@property(nonatomic) NSString* emailDescription;
@property(nonatomic) NSString* emailSubDescription;
@property(nonatomic) NSString* emailPlaceHolder;
@property(nonatomic) NSString* emailValidateFormatError;
@property(nonatomic) NSString* emailSendSuccess;
@property(nonatomic) NSString* emailSendFail;

@property(nonatomic) NSString* emailValidateFail;

@property(nonatomic) NSArray<NSNumber*>* footerOtherButtonGradient;
@property(nonatomic) int footerOtherButtonOutlineColor;
@property(nonatomic) int footerOtherTitleColor;

@property(nonatomic) BOOL footerButtonShadow;
@property(nonatomic) BOOL footerOtherButtonShadow;

@property(nonatomic) int checkIconColor;
@property(nonatomic) int backIconColor;

@property(nonatomic) NSString* pushToastMsg;
@property(nonatomic) NSString* nightPushToastMsg;




- (instancetype) init;
- (instancetype) initWithString:(NSString*)_strOption;
- (instancetype) init:(THEME)_theme;
- (NSString*) toString;

- (void) setEUCountry:(BOOL)_enable;
- (BOOL) isEUCountry;

+ (NSString*) ThemeTypeToString:(THEME)_type;
+ (THEME) ThemeTypeEnumFromString:(NSString*)_type;

@end



@interface GamePotAgreeView : UIView

@property (nonatomic) NSString* projectId;
@property (nonatomic) NSString* memberId;
@property (nonatomic) NSString* language;
@property (nonatomic) NSString* apiUrl;
@property (nonatomic) NSString* ncpId;
@property (nonatomic) GamePotGraphQLRequest*  graphQLRequest;

@property (nonatomic, readonly) GamePotAgreeInfo* agreeResult;


- (instancetype)init:(GamePotAgreeOption*)_option handler:(GamePotAgreeHandler)_handler;
- (void)show:(UIViewController*)_viewController;

@end

