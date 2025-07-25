
#import <Foundation/Foundation.h>

typedef void (^GamePotGraphQLHandler) (NSDictionary* _data, NSError* _error);

@interface GamePotGraphQLRequest : NSObject

- (instancetype) init:(NSString*)_baseURL;

- (void) initialize:(NSString*) _projectId
            storeId:(NSString*) _storeId
            handler:(GamePotGraphQLHandler)_handler;

- (void) initializeUrls:(NSString*) _projectId
                handler:(GamePotGraphQLHandler)_handler;

- (void) initializeGDPR:(NSString*) _projectId
            handler:(GamePotGraphQLHandler)_handler;

- (void) setPushStatus:(NSString*)_projectId
              setToken:(NSString*)_token
               setPush:(BOOL)_push
              setNight:(BOOL)_night
                 setAd:(BOOL)_ad
               handler:(GamePotGraphQLHandler)_handler;

- (void) setUserData:(NSString*)_projectId
         setData:(NSString*)_userData
         handler:(GamePotGraphQLHandler)_handler;

- (void) getUserData:(GamePotGraphQLHandler)_handler;
//- (void) createEndpoint:(NSString*)_projectId
//                 enable:(BOOL)_enable
//                  night:(BOOL)_night
//               userData:(NSString*)_userData
//                  token:(NSString*)_token
//                channel:(NSString*)_channel
//                handler:(GamePotGraphQLHandler)_handler;
//
//- (void) setEndpoint:(NSString*)_projectId
//              enable:(BOOL)_enable
//               night:(BOOL)_night
//             handler:(GamePotGraphQLHandler)_handler;

- (void) createMember:(NSString*)_projectId
              storeId:(NSString*)_storeId
             password:(NSString*)_password
              handler:(GamePotGraphQLHandler)_handler;

- (void) setMember:(NSString*)_projectId
              adid:(NSString*)_adid
            device:(NSString*)_device
           network:(NSString*)_network
           version:(NSString*)_version
             model:(NSString*)_model
        gdprStatus:(NSNumber*)_gdprStatus
 gdprCheckedCategory:(NSArray*)_gdprCheckedCategory
     emailVerified:(NSString*)_emailVerified
           handler:(GamePotGraphQLHandler)_handler;

// 20210824 : Email 추가
- (void) setGDPR:(NSString*)_projectId
      gdprStatus:(NSNumber*)_gdprStatus
gdprCheckedCategory:(NSArray*)_gdprCheckedCategory
   emailVerified:(NSString*)_emailVerified;

- (void) deleteMember:(NSString*)_projectId
             memberId:(NSString*)_memberId
              storeId:(NSString*)_storeId
              handler:(GamePotGraphQLHandler)_handler;

//- (void) signIn:(NSString*)_projectId
//       memberId:(NSString*)_memberId
//        storeId:(NSString*)_storeId
//        handler:(GamePotGraphQLHandler)_handler;

- (void) signInV2:(NSString*)_projectId
         memberId:(NSString*)_memberId
         password:(NSString*)_password
          storeId:(NSString*)_storeId
          handler:(GamePotGraphQLHandler)_handler;

- (void) signOut:(NSString*)_projectId
        memberId:(NSString*)_memberId
         storeId:(NSString*)_storeId
         handler:(GamePotGraphQLHandler)_handler;

- (void) createLinking:(NSString*)_projectId
              memberId:(NSString*)_memberId
              userName:(NSString*)_username
              provider:(NSString*)_provider
                 email:(NSString*)_email
               handler:(GamePotGraphQLHandler)_handler;

- (void) deleteLinking:(NSString*)_projectId
             linkingId:(NSString*)_linkingId
               handler:(GamePotGraphQLHandler)_handler;

- (void) linkings:(NSString*)_offset
          perPage:(NSString*)_perPage
          handler:(GamePotGraphQLHandler)_handler;

- (void) linkingByUser:(NSString*)_projectId
              userName:(NSString*)_userName
              provider:(NSString*)_provider
               handler:(GamePotGraphQLHandler)_handler;

- (void) checkPurchase:(NSString*)_projectId
             productId:(NSString*)_productId
               storeId:(NSString*)_storeId
             paymentId:(NSString*)_paymentId
              userData:(NSString*)_userData
               handler:(GamePotGraphQLHandler)_handler;

- (void) createPurchase:(NSString*)_storeId
              projectId:(NSString*)_projectId
                orderId:(NSString*)_orderId
              signature:(NSString*)_signature
                 itemId:(NSString*)_itemId
                receipt:(NSString*)_receipt
              paymentId:(NSString*)_paymentId
               currency:(NSString*)_currency
                country:(NSString*)_country
                  price:(NSDecimalNumber*)_price
               userData:(NSString*)_userData
                handler:(GamePotGraphQLHandler)_handler;

- (void) createVoidedPurchase:(NSString*)_voidedId
                      storeId:(NSString*)_storeId
                    projectId:(NSString*)_projectId
                      orderId:(NSString*)_orderId
                    signature:(NSString*)_signature
                       itemId:(NSString*)_itemId
                      receipt:(NSString*)_receipt
                    paymentId:(NSString*)_paymentId
                     currency:(NSString*)_currency
                      country:(NSString*)_country
                        price:(NSDecimalNumber*)_price
                     userData:(NSString*)_userData
                      handler:(GamePotGraphQLHandler)_handler;


- (void) useCoupon:(NSString*)_couponNumber
         projectId:(NSString*)_projectId
          userData:(NSString*)_userData
           handler:(GamePotGraphQLHandler)_handler;

- (void) checkAppStatus:(NSString*)_projectId
                handler:(GamePotGraphQLHandler)_handler;

- (void) checkAppStatusUpdateUrl:(NSString*)_projectId
                         handler:(GamePotGraphQLHandler)_handler;


- (void) noticeCount:(NSString*)_projectId
             storeId:(NSString*)_storeId
             handler:(GamePotGraphQLHandler)_handler;

- (void) noticeType:(NSString*)_projectId
            storeId:(NSString*)_storeId
               type:(NSString*)_type
            handler:(GamePotGraphQLHandler)_handler;


- (void) ccuEnable:(NSString*)_projectId
           storeId:(NSString*)_storeId
           handler:(GamePotGraphQLHandler)_handler;

- (void) projectInfo:(NSString*)_projectId
             handler:(GamePotGraphQLHandler)_handler;

- (void) getNcpSignature:(NSString*)_projectId
                  method:(NSString*)_method
                     url:(NSString*)_url
                 handler:(GamePotGraphQLHandler)_handler;

- (void) createMemberByThirdPartySDK:(NSString*)_projectId
                             storeId:(NSString*)_storeId
                                 uId:(NSString*)_uId
                             handler:(GamePotGraphQLHandler)_handler;

- (void) createPurchaseByThirdPartySDK:(NSString*)_projectId
                               storeId:(NSString*)_storeId
                               productId:(NSString*)_productId
                              currency:(NSString*)_currency
                                 price:(NSDecimalNumber*)_price
                         transactionId:(NSString*)_transactionId
                             paymentId:(NSString*)_paymentId
                              uniqueId:(NSString*)_uniqueId
                               handler:(GamePotGraphQLHandler)_handler;

- (void) setAgree:(NSString*)_projectId
         setTerms:(BOOL)_termsofuse
       setPrivacy:(BOOL)_privacypolicy;

- (void) voided:(NSString*)_projectId
       memberId:(NSString*)_memberId
        handler:(GamePotGraphQLHandler)_handler;

- (void) requestGDPRMail:(NSString*)_projectId
                   email:(NSString*)_email
                 handler:(GamePotGraphQLHandler)_handler;

- (void) verifyGDPRMail:(NSString*)_projectId
                  email:(NSString*)_email
                    key:(NSString*)_key
                handler:(GamePotGraphQLHandler)_handler;

- (void) updateLinking:(NSString*)_projectId
              memberId:(NSString*)_memberId
              userName:(NSString*)_userName
              provider:(NSString*)_provider
                 email:(NSString*)_email
               handler:(GamePotGraphQLHandler)_handler;


@end
