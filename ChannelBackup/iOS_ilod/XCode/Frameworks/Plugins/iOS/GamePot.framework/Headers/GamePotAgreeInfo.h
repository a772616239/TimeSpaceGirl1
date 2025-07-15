//
//  GamePotAgreeInfo.h
//  GamePot
//
//  Created by Lee Chungwon on 11/01/2019.
//  Copyright © 2019 itsB. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GamePotAgreeInfo : NSObject
@property (nonatomic) BOOL agree; // 이용약관, 개인정보 약관 결과
@property (nonatomic) BOOL agreePush; // 푸쉬 약관
@property (nonatomic) BOOL agreeNight; // 야간 푸쉬 약관


@property (nonatomic) NSString* agreeGDPR;
// -1 : GDPR 아님
// 3 : 16세 이하
// 4 : 16세 이상
@property (nonatomic) int agreeGDPRStatus;

// 20210824 : Email 추가
@property (nonatomic) NSString* emailVerified;

- (NSDictionary*) toDictionary;
- (NSString* ) toJsonString;


@end
