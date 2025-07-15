//
//  GamePotWebView.h
//  GamePot
//
//  Created by Lee Chungwon on 29/09/2018.
//  Copyright © 2018 itsB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "GamePotChannelType.h"
#import "GamePotChannel.h"

@interface GamePotChannelLoginOption:NSObject

@property (nonatomic) NSArray* order;
@property (assign) BOOL showLogo;
//@property (nonatomic) UIImage* titleImage;

- (instancetype) init:(NSArray*)_order;

@end


@interface GamePotChannelLoginView : UIView


- (instancetype)init:(GamePotChannelLoginOption *)_option
             success:(GamePotChannelManagerSuccess)_success
              update:(GamePotChannelAppStatus)_update
         maintenance:(GamePotChannelAppStatus)_maintenance
                exit:(GamePotChannelManagerExit)_exit;

- (void)show:(UIViewController*)_viewController;
- (void)close;

@end

