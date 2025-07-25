//
//  AppsFlyerLib.h
//  AppsFlyerLib
//
//  AppsFlyer iOS SDK 6.2.5 (76)
//  Copyright (c) 2012-2020 AppsFlyer Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AppsFlyerCrossPromotionHelper.h"
#import "AppsFlyerShareInviteHelper.h"
#import "AppsFlyerDeepLinkResult.h"
#import "AppsFlyerDeepLink.h"

NS_ASSUME_NONNULL_BEGIN

// In app event names constants
#define AFEventLevelAchieved            @"af_level_achieved"
#define AFEventAddPaymentInfo           @"af_add_payment_info"
#define AFEventAddToCart                @"af_add_to_cart"
#define AFEventAddToWishlist            @"af_add_to_wishlist"
#define AFEventCompleteRegistration     @"af_complete_registration"
#define AFEventTutorial_completion      @"af_tutorial_completion"
#define AFEventInitiatedCheckout        @"af_initiated_checkout"
#define AFEventPurchase                 @"af_purchase"
#define AFEventRate                     @"af_rate"
#define AFEventSearch                   @"af_search"
#define AFEventSpentCredits             @"af_spent_credits"
#define AFEventAchievementUnlocked      @"af_achievement_unlocked"
#define AFEventContentView              @"af_content_view"
#define AFEventListView                 @"af_list_view"
#define AFEventTravelBooking            @"af_travel_booking"
#define AFEventShare                    @"af_share"
#define AFEventInvite                   @"af_invite"
#define AFEventLogin                    @"af_login"
#define AFEventReEngage                 @"af_re_engage"
#define AFEventUpdate                   @"af_update"
#define AFEventOpenedFromPushNotification @"af_opened_from_push_notification"
#define AFEventLocation                 @"af_location_coordinates"
#define AFEventCustomerSegment          @"af_customer_segment"

#define AFEventSubscribe                @"af_subscribe"
#define AFEventStartTrial               @"af_start_trial"
#define AFEventAdClick                  @"af_ad_click"
#define AFEventAdView                   @"af_ad_view"

// In app event parameter names
#define AFEventParamContent                @"af_content"
#define AFEventParamAchievementId          @"af_achievement_id"
#define AFEventParamLevel                  @"af_level"
#define AFEventParamScore                  @"af_score"
#define AFEventParamSuccess                @"af_success"
#define AFEventParamPrice                  @"af_price"
#define AFEventParamContentType            @"af_content_type"
#define AFEventParamContentId              @"af_content_id"
#define AFEventParamContentList            @"af_content_list"
#define AFEventParamCurrency               @"af_currency"
#define AFEventParamQuantity               @"af_quantity"
#define AFEventParamRegistrationMethod     @"af_registration_method"
#define AFEventParamPaymentInfoAvailable   @"af_payment_info_available"
#define AFEventParamMaxRatingValue         @"af_max_rating_value"
#define AFEventParamRatingValue            @"af_rating_value"
#define AFEventParamSearchString           @"af_search_string"
#define AFEventParamDateA                  @"af_date_a"
#define AFEventParamDateB                  @"af_date_b"
#define AFEventParamDestinationA           @"af_destination_a"
#define AFEventParamDestinationB           @"af_destination_b"
#define AFEventParamDescription            @"af_description"
#define AFEventParamClass                  @"af_class"
#define AFEventParamEventStart             @"af_event_start"
#define AFEventParamEventEnd               @"af_event_end"
#define AFEventParamLat                    @"af_lat"
#define AFEventParamLong                   @"af_long"
#define AFEventParamCustomerUserId         @"af_customer_user_id"
#define AFEventParamValidated              @"af_validated"
#define AFEventParamRevenue                @"af_revenue"
#define AFEventProjectedParamRevenue       @"af_projected_revenue"
#define AFEventParamReceiptId              @"af_receipt_id"
#define AFEventParamTutorialId             @"af_tutorial_id"
#define AFEventParamVirtualCurrencyName    @"af_virtual_currency_name"
#define AFEventParamDeepLink               @"af_deep_link"
#define AFEventParamOldVersion             @"af_old_version"
#define AFEventParamNewVersion             @"af_new_version"
#define AFEventParamReviewText             @"af_review_text"
#define AFEventParamCouponCode             @"af_coupon_code"
#define AFEventParamOrderId                @"af_order_id"
#define AFEventParam1                      @"af_param_1"
#define AFEventParam2                      @"af_param_2"
#define AFEventParam3                      @"af_param_3"
#define AFEventParam4                      @"af_param_4"
#define AFEventParam5                      @"af_param_5"
#define AFEventParam6                      @"af_param_6"
#define AFEventParam7                      @"af_param_7"
#define AFEventParam8                      @"af_param_8"
#define AFEventParam9                      @"af_param_9"
#define AFEventParam10                     @"af_param_10"

#define AFEventParamDepartingDepartureDate  @"af_departing_departure_date"
#define AFEventParamReturningDepartureDate  @"af_returning_departure_date"
#define AFEventParamDestinationList         @"af_destination_list"  //array of string
#define AFEventParamCity                    @"af_city"
#define AFEventParamRegion                  @"af_region"
#define AFEventParamCountry                 @"af_country"


#define AFEventParamDepartingArrivalDate    @"af_departing_arrival_date"
#define AFEventParamReturningArrivalDate    @"af_returning_arrival_date"
#define AFEventParamSuggestedDestinations   @"af_suggested_destinations" //array of string
#define AFEventParamTravelStart             @"af_travel_start"
#define AFEventParamTravelEnd               @"af_travel_end"
#define AFEventParamNumAdults               @"af_num_adults"
#define AFEventParamNumChildren             @"af_num_children"
#define AFEventParamNumInfants              @"af_num_infants"
#define AFEventParamSuggestedHotels         @"af_suggested_hotels" //array of string

#define AFEventParamUserScore               @"af_user_score"
#define AFEventParamHotelScore              @"af_hotel_score"
#define AFEventParamPurchaseCurrency        @"af_purchase_currency"

#define AFEventParamPreferredStarRatings    @"af_preferred_star_ratings"    //array of int (basically a tuple (min,max) but we'll use array of int and instruct the developer to use two values)

#define AFEventParamPreferredPriceRange     @"af_preferred_price_range"    //array of int (basically a tuple (min,max) but we'll use array of int and instruct the developer to use two values)
#define AFEventParamPreferredNeighborhoods  @"af_preferred_neighborhoods" //array of string
#define AFEventParamPreferredNumStops       @"af_preferred_num_stops"

#define AFEventParamAdRevenueAdType              @"af_adrev_ad_type"
#define AFEventParamAdRevenueNetworkName         @"af_adrev_network_name"
#define AFEventParamAdRevenuePlacementId         @"af_adrev_placement_id"
#define AFEventParamAdRevenueAdSize              @"af_adrev_ad_size"
#define AFEventParamAdRevenueMediatedNetworkName @"af_adrev_mediated_network_name"

/// Mail hashing type
typedef enum  {
    /// None
    EmailCryptTypeNone = 0,
    /// SHA1
    EmailCryptTypeSHA1 = 1,
    /// MD5
    EmailCryptTypeMD5 = 2,
    /// SHA256
    EmailCryptTypeSHA256 = 3
} EmailCryptType;

NS_SWIFT_NAME(DeepLinkDelegate)
@protocol AppsFlyerDeepLinkDelegate <NSObject>

@optional
- (void)didResolveDeepLink:(AppsFlyerDeepLinkResult *_Nonnull)result;

@end

/**
 Conform and subscribe to this protocol to allow getting data about conversion and
 install attribution
 */
@protocol AppsFlyerLibDelegate <NSObject>

/**
 `conversionInfo` contains information about install.
 Organic/non-organic, etc.
 @param conversionInfo May contain <code>null</code> values for some keys. Please handle this case.
 */
- (void)onConversionDataSuccess:(NSDictionary *)conversionInfo;

/**
 Any errors that occurred during the conversion request.
 */
- (void)onConversionDataFail:(NSError *)error;

@optional

/**
 `attributionData` contains information about OneLink, deeplink.
 */
- (void)onAppOpenAttribution:(NSDictionary *)attributionData;

/**
 Any errors that occurred during the attribution request.
 */
- (void)onAppOpenAttributionFailure:(NSError *)error;

/**
 @abstract Sets the HTTP header fields of the ESP resolving to the given
 dictionary.
 @discussion This method replaces all header fields that may have
 existed before this method ESP resolving call.
 To keep default SDK behavior - return nil;
 */
- (NSDictionary <NSString *, NSString *> * _Nullable)allHTTPHeaderFieldsForResolveDeepLinkURL:(NSURL *)URL;

@end

/**
 You can log installs, app updates, sessions and additional in-app events
 (including in-app purchases, game levels, etc.)
 to evaluate ROI and user engagement.
 The iOS SDK is compatible with all iOS/tvOS devices with iOS version 7 and above.
 
 @see [SDK Integration Validator](https://support.appsflyer.com/hc/en-us/articles/207032066-AppsFlyer-SDK-Integration-iOS)
 for more information.
 
 */
@interface AppsFlyerLib : NSObject

/**
 Gets the singleton instance of the AppsFlyerLib class, creating it if
 necessary.
 
 @return The singleton instance of AppsFlyerLib.
 */
+ (AppsFlyerLib *)shared;

/**
 In case you use your own user ID in your app, you can set this property to that ID.
 Enables you to cross-reference your own unique ID with AppsFlyer’s unique ID and the other devices’ IDs
 */
@property(nonatomic, strong, nullable) NSString * customerUserID;

/**
 In case you use custom data and you want to receive it in the raw reports.
 
 @see [Setting additional custom data](https://support.appsflyer.com/hc/en-us/articles/207032066-AppsFlyer-SDK-Integration-iOS#setting-additional-custom-data) for more information.
 */
@property(nonatomic, strong, nullable, setter = setAdditionalData:) NSDictionary * customData;

/**
 Use this property to set your AppsFlyer's dev key
 */
@property(nonatomic, strong) NSString * appsFlyerDevKey;

/**
 Use this property to set your app's Apple ID(taken from the app's page on iTunes Connect)
 */
@property(nonatomic, strong) NSString * appleAppID;

#ifndef AFSDK_NO_IDFA
/**
 AppsFlyer SDK collect Apple's `advertisingIdentifier` if the `AdSupport.framework` included in the SDK.
 You can disable this behavior by setting the following property to YES
*/
@property(nonatomic) BOOL disableAdvertisingIdentifier;

@property(nonatomic, strong, readonly) NSString *advertisingIdentifier;

/**
 Waits for request user authorization to access app-related data
 */
- (void)waitForATTUserAuthorizationWithTimeoutInterval:(NSTimeInterval)timeoutInterval
NS_SWIFT_NAME(waitForATTUserAuthorization(timeoutInterval:));

#endif

@property(nonatomic) BOOL disableSKAdNetwork;

/**
 In case of in app purchase events, you can set the currency code your user has purchased with.
 The currency code is a 3 letter code according to ISO standards
 
 Objective-C:
 
 <pre>
 [[AppsFlyerLib shared] setCurrencyCode:@"USD"];
 </pre>
 
 Swift:
 
 <pre>
 AppsFlyerLib.shared().currencyCode = "USD"
 </pre>
 */
@property(nonatomic, strong, nullable) NSString *currencyCode;

/**
 Prints SDK messages to the console log. This property should only be used in `DEBUG` mode.
 The default value is `NO`
 */
@property(nonatomic) BOOL isDebug;

/**
 Set this flag to `YES`, to collect the current device name(e.g. "My iPhone"). Default value is `NO`
 */
@property(nonatomic) BOOL shouldCollectDeviceName;

/**
 Set your `OneLink ID` from OneLink configuration. Used in User Invites to generate a OneLink.
 */
@property(nonatomic, strong, nullable, setter = setAppInviteOneLink:) NSString * appInviteOneLinkID;

/**
 Opt-out logging for specific user
 */
@property(atomic) BOOL anonymizeUser;

/**
 Opt-out for Apple Search Ads attributions
 */
@property(atomic) BOOL disableCollectASA;

@property(nonatomic) BOOL disableAppleAdsAttribution;

/**
 AppsFlyer delegate. See `AppsFlyerLibDelegate`
 */
@property(weak, nonatomic) id<AppsFlyerLibDelegate> delegate;

@property(weak, nonatomic) id<AppsFlyerDeepLinkDelegate> deepLinkDelegate;

/**
 In app purchase receipt validation Apple environment(production or sandbox). The default value is NO
 */
@property(nonatomic) BOOL useReceiptValidationSandbox;

/**
 Set this flag to test uninstall on Apple environment(production or sandbox). The default value is NO
 */
@property(nonatomic) BOOL useUninstallSandbox;

/**
 For advertisers who wrap OneLink within another Universal Link.
 An advertiser will be able to deeplink from a OneLink wrapped within another Universal Link and also log this retargeting conversion.
 
 Objective-C:
 
 <pre>
 [[AppsFlyerLib shared] setResolveDeepLinkURLs:@[@"domain.com", @"subdomain.domain.com"]];
 </pre>
 */
@property(nonatomic, nullable) NSArray<NSString *> *resolveDeepLinkURLs;

/**
 For advertisers who use vanity OneLinks.
 
 Objective-C:
 
 <pre>
 [[AppsFlyerLib shared] oneLinkCustomDomains:@[@"domain.com", @"subdomain.domain.com"]];
 </pre>
 */
@property(nonatomic, nullable) NSArray<NSString *> *oneLinkCustomDomains;

/*
 * Set phone number for each `start` event. `phoneNumber` will be sent as SHA256 string
 */
@property(nonatomic, nullable) NSString *phoneNumber;

- (NSString *)phoneNumber UNAVAILABLE_ATTRIBUTE;

/**
 To disable app's vendor identifier(IDFV), set disableIDFVCollection to true
 */
@property(nonatomic) BOOL disableIDFVCollection;

/**
 Enable the collection of Facebook Deferred AppLinks
 Requires Facebook SDK and Facebook app on target/client device.
 This API must be invoked prior to initializing the AppsFlyer SDK in order to function properly.
 
 Objective-C:
 
 <pre>
 [[AppsFlyerLib shared] enableFacebookDeferredApplinksWithClass:[FBSDKAppLinkUtility class]]
 </pre>
 
 Swift:
 
 <pre>
 AppsFlyerLib.shared().enableFacebookDeferredApplinks(with: FBSDKAppLinkUtility.self)
 </pre>
 
 @param facebookAppLinkUtilityClass requeries method call `[FBSDKAppLinkUtility class]` as param.
 */
- (void)enableFacebookDeferredApplinksWithClass:(Class _Nullable)facebookAppLinkUtilityClass;

/**
 Use this to send the user's emails
 
 @param userEmails The list of strings that hold mails
 @param type Hash algoritm
 */
- (void)setUserEmails:(NSArray<NSString *> * _Nullable)userEmails withCryptType:(EmailCryptType)type;

/**
 Start SDK session
 Add the following method at the `applicationDidBecomeActive` in AppDelegate class
 */
- (void)start;

- (void)startWithCompletionHandler:(void (^ _Nullable)(NSDictionary<NSString *, id> * _Nullable dictionary, NSError * _Nullable error))completionHandler;

/**
 Use this method to log an events with multiple values. See AppsFlyer's documentation for details.
 
 Objective-C:
 
 <pre>
 [[AppsFlyerLib shared] logEvent:AFEventPurchase
        withValues: @{AFEventParamRevenue  : @200,
                      AFEventParamCurrency : @"USD",
                      AFEventParamQuantity : @2,
                      AFEventParamContentId: @"092",
                      AFEventParamReceiptId: @"9277"}];
 </pre>
 
 Swift:
 
 <pre>
 AppsFlyerLib.shared().logEvent(AFEventPurchase,
        withValues: [AFEventParamRevenue  : "1200",
                     AFEventParamContent  : "shoes",
                     AFEventParamContentId: "123"])
 </pre>
 
 @param eventName Contains name of event that could be provided from predefined constants in `AppsFlyerLib.h`
 @param values Contains dictionary of values for handling by backend
 */
- (void)logEvent:(NSString *)eventName withValues:(NSDictionary * _Nullable)values;

- (void)logEventWithEventName:(NSString *)eventName
                  eventValues:(NSDictionary<NSString * , id> * _Nullable)eventValues
            completionHandler:(void (^ _Nullable)(NSDictionary<NSString *, id> * _Nullable dictionary, NSError * _Nullable error))completionHandler
NS_SWIFT_NAME(logEvent(name:values:completionHandler:));

/**
 To log and validate in app purchases you can call this method from the completeTransaction: method on
 your `SKPaymentTransactionObserver`.
 
 @param productIdentifier The product identifier
 @param price The product price
 @param currency The product currency
 @param transactionId The purchase transaction Id
 @param params The additional param, which you want to receive it in the raw reports
 @param successBlock The success callback
 @param failedBlock The failure callback
 */
- (void)validateAndLogInAppPurchase:(NSString * _Nullable)productIdentifier
                              price:(NSString * _Nullable)price
                           currency:(NSString * _Nullable)currency
                      transactionId:(NSString * _Nullable)transactionId
               additionalParameters:(NSDictionary * _Nullable)params
                            success:(void (^ _Nullable)(NSDictionary * response))successBlock
                            failure:(void (^ _Nullable)(NSError * _Nullable error, id _Nullable reponse))failedBlock NS_AVAILABLE(10_7, 7_0);

/**
 To log location for geo-fencing. Does the same as code below.
 
 <pre>
 AppsFlyerLib.shared().logEvent(AFEventLocation, withValues: [AFEventParamLong:longitude, AFEventParamLat:latitude])
 </pre>
 
 @param longitude The location longitude
 @param latitude The location latitude
 */
- (void)logLocation:(double)longitude latitude:(double)latitude NS_SWIFT_NAME(logLocation(longitude:latitude:));

/**
 This method returns AppsFlyer's internal id(unique for your app)
 
 @return Internal AppsFlyer Id
 */
- (NSString *)getAppsFlyerUID;

/**
 In case you want to log deep linking. Does the same as `-handleOpenURL:sourceApplication:withAnnotation`.
 
 @warning Preferred to use `-handleOpenURL:sourceApplication:withAnnotation`.
 
 @param url The URL that was passed to your AppDelegate.
 @param sourceApplication The sourceApplication that passed to your AppDelegate.
 */
- (void)handleOpenURL:(NSURL * _Nullable)url sourceApplication:(NSString * _Nullable)sourceApplication API_UNAVAILABLE(macos);

/**
 In case you want to log deep linking.
 Call this method from inside your AppDelegate `-application:openURL:sourceApplication:annotation:`
 
 @param url The URL that was passed to your AppDelegate.
 @param sourceApplication The sourceApplication that passed to your AppDelegate.
 @param annotation The annotation that passed to your app delegate.
 */
- (void)handleOpenURL:(NSURL * _Nullable)url
    sourceApplication:(NSString * _Nullable)sourceApplication
       withAnnotation:(id _Nullable)annotation API_UNAVAILABLE(macos);

/**
 Call this method from inside of your AppDelegate `-application:openURL:options:` method.
 This method is functionally the same as calling the AppsFlyer method
 `-handleOpenURL:sourceApplication:withAnnotation`.
 
 @param url The URL that was passed to your app delegate
 @param options The options dictionary that was passed to your AppDelegate.
 */
- (void)handleOpenUrl:(NSURL * _Nullable)url options:(NSDictionary * _Nullable)options API_UNAVAILABLE(macos);

/**
 Allow AppsFlyer to handle restoration from an NSUserActivity.
 Use this method to log deep links with OneLink.
 
 @param userActivity The NSUserActivity that caused the app to be opened.
 */
- (BOOL)continueUserActivity:(NSUserActivity * _Nullable)userActivity
          restorationHandler:(void (^ _Nullable)(NSArray * _Nullable))restorationHandler NS_AVAILABLE_IOS(9_0) API_UNAVAILABLE(macos);

/**
 Enable AppsFlyer to handle a push notification.
 
 @see [Learn more here](https://support.appsflyer.com/hc/en-us/articles/207364076-Measuring-Push-Notification-Re-Engagement-Campaigns)
 
 @warning To make it work - set data, related to AppsFlyer under key @"af".
 
 @param pushPayload The `userInfo` from received remote notification. One of root keys should be @"af".
 */
- (void)handlePushNotification:(NSDictionary * _Nullable)pushPayload;


/**
 Register uninstall - you should register for remote notification and provide AppsFlyer the push device token.
 
 @param deviceToken The `deviceToken` from `-application:didRegisterForRemoteNotificationsWithDeviceToken:`
 */
- (void)registerUninstall:(NSData * _Nullable)deviceToken;

/**
 Get SDK version.
 
 @return The AppsFlyer SDK version info.
 */
- (NSString *)getSDKVersion;

/**
 This is for internal use.
 */
- (void)remoteDebuggingCallWithData:(NSString *)data;

/**
 Used to force the trigger `onAppOpenAttribution` delegate.
 Notice, re-engagement, session and launch won't be counted.
 Only for OneLink/UniversalLink/Deeplink resolving.
 
 @param URL The param to resolve into -[AppsFlyerLibDelegate onAppOpenAttribution:]
 */
- (void)performOnAppAttributionWithURL:(NSURL * _Nullable)URL;

/**
 @brief This property accepts a string value representing the host name for all endpoints.
 Can be used to Zero rate your application’s data usage. Contact your CSM for more information.
 
 @warning To use `default` SDK endpoint – set value to `nil`.
 
 Objective-C:
 
 <pre>
 [[AppsFlyerLib shared] setHost:@"example.com"];
 </pre>
 
 Swift:
 
 <pre>
 AppsFlyerLib.shared().host = "example.com"
 </pre>
 */
@property(nonatomic, strong, readonly) NSString *host;

/**
 * This function set the host name and prefix host name for all the endpoints
 **/
- (void)setHost:(NSString *)host withHostPrefix:(NSString *)hostPrefix;

/**
 * This property accepts a string value representing the prefix host name for all endpoints.
 * for example "test" prefix with default host name will have the address "host.appsflyer.com"
 */
@property(nonatomic, strong, readonly) NSString *hostPrefix;

/**
 This property is responsible for timeout between sessions in seconds.
 Default value is 5 seconds.
 */
@property(atomic) NSUInteger minTimeBetweenSessions;

/**
 API to shut down all SDK activities.
 
 @warning This will disable all requests from AppsFlyer SDK.
 */
@property(atomic) BOOL isStopped;

/**
 API to set manually Facebook deferred app link
 */
@property(nonatomic, nullable) NSURL *facebookDeferredAppLink;

/**
 Block an events from being shared with ad networks and other 3rd party integrations
 Must only include letters/digits or underscore, maximum length: 45
 */
@property(nonatomic, nullable) NSArray<NSString *> *sharingFilter;

@property(nonatomic) NSUInteger deepLinkTimeout;

/**
 Block an events from being shared with any partner
 This method overwrite -[AppsFlyerLib setSharingFilter:]
 */
-(void)setSharingFilterForAllPartners;

/**
 Validate if URL contains certain string and append quiery
 parameters to deeplink URL. In case if URL does not contain user-defined string,
 parameters are not appended to the url.
 
 @param containsString string to check in URL.
 @param parameters NSDictionary, which containins parameters to append to the deeplink url after it passed validation.
 */
- (void)appendParametersToDeepLinkingURLWithString:(NSString *)containsString
                                        parameters:(NSDictionary<NSString *, NSString*> *)parameters
NS_SWIFT_NAME(appendParametersToDeeplinkURL(contains:parameters:));

/**
 Adds array of keys, which are used to compose key path
 to resolve deeplink from push notification payload `userInfo`.
 
 @param deepLinkPath an array of strings which contains keys to search for deeplink in payload.
 */
- (void)addPushNotificationDeepLinkPath:(NSArray<NSString *> *)deepLinkPath;

/**
 * Allows sending custom data for partner integration purposes.
 *
 * @param partnerId ID of the partner (usually has "_int" suffix)
 * @param partnerInfo customer data, depends on the integration nature with specific partner
 */

- (void)setPartnerDataWithPartnerId:(NSString * _Nullable)partnerId partnerInfo:(NSDictionary<NSString *, id> * _Nullable)partnerInfo
NS_SWIFT_NAME(setPartnerData(partnerId:partnerInfo:));

@end

NS_ASSUME_NONNULL_END
