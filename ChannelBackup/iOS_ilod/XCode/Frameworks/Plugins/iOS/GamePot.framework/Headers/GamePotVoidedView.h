//
//  GamePotWebView.h
//  GamePot
//
//  Created by Lee Chungwon on 29/09/2018.
//  Copyright © 2018 itsB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@protocol GamePotVoidedPurchaseDelegate<NSObject>
@required
- (void) GamePotVoidedPurchaseSuccess:(id)_info;
- (void) GamePotVoidedPurchaseFail:(NSError*)_error;
- (void) GamePotVoidedPurchaseCancel;
@end

@interface GamePotVoidedOption:NSObject

typedef NS_ENUM(NSInteger, VOIDED_THEME) {
    VOIDED_MATERIAL_RED = 0,
    VOIDED_MATERIAL_BLUE = 1,
    VOIDED_MATERIAL_ORANGE = 2,
    VOIDED_MATERIAL_PURPLE = 3,
    VOIDED_MATERIAL_YELLOW = 4,
    VOIDED_MATERIAL_GRAPE = 5,
    VOIDED_MATERIAL_GREEN = 6,
    VOIDED_MATERIAL_PEACH = 7,
    VOIDED_MATERIAL_CYAN = 8,
    VOIDED_MATERIAL_DARKBULE = 9,
    VOIDED_MATERIAL_GRAY = 10,
};

@property(nonatomic) NSArray<NSNumber*>* headerBackGradient;
@property(nonatomic) int headerTitleColor;

@property(nonatomic) NSArray<NSNumber*>* contentBackGradient;
@property(nonatomic) NSArray<NSNumber*>* listHeaderBackGradient;
@property(nonatomic) int listHeaderTitleColor;
@property(nonatomic) NSArray<NSNumber*>* listContentBackGradient;
@property(nonatomic) int listContentTitleColor;

@property(nonatomic) NSArray<NSNumber*>* footerBackGradient;
@property(nonatomic) NSArray<NSNumber*>* footerButtonGradient;
@property(nonatomic) int footerTitleColor;

@property(nonatomic) NSString* headerTitle;

@property(nonatomic) NSString* descHTML;
@property(nonatomic) int descColor;

@property(nonatomic) NSString* listHeaderTitle;
@property(nonatomic) NSString* footerTitle;

- (instancetype) init;
- (instancetype) init:(VOIDED_THEME)_theme;
- (NSString*) toString;

+ (NSString*) ThemeTypeToString:(VOIDED_THEME)_type;
+ (VOIDED_THEME) ThemeTypeEnumFromString:(NSString*)_type;
@end

@interface GamePotVoidedData:NSObject
@property(nonatomic) NSString* voidedId;
@property(nonatomic) NSString* name;
@property(nonatomic) NSString* productid;
@property(nonatomic) NSString* currency;
@property(nonatomic) NSString* price;
@end


@interface GamePotVoidedView : UIView
@property(nonatomic) id delegate;
- (instancetype)init:(GamePotVoidedOption*)_option graphql:(id)_graphql data:(NSArray*)_data billingManager:(id)_manager handler:(id)_handler;
- (void)show:(UIViewController*)_viewController;
- (void)close;

@end


