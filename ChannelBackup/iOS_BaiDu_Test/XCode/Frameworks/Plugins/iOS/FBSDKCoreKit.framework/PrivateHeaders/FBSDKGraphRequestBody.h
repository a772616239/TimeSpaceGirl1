// Copyright (c) 2014-present, Facebook, Inc. All rights reserved.
//
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Facebook.
//
// As with any software that integrates with the Facebook platform, your use of
// this software is subject to the Facebook Developer Principles and Policies
// [http://developers.facebook.com/policy/]. This copyright notice shall be
// included in all copies or substantial portions of the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import <Foundation/Foundation.h>
#import <UIKit/UIImage.h>

@class FBSDKGraphRequestDataAttachment;
@class FBSDKLogger;

NS_SWIFT_NAME(GraphRequestBody)
@interface FBSDKGraphRequestBody : NSObject

@property (nonatomic, retain, readonly) NSData *data;

/**
  Determines whether to use multipart/form-data or application/json as the Content-Type.
  If binary attachments are added, this will default to YES.
 */
@property (nonatomic, assign) BOOL requiresMultipartDataFormat;

- (void)appendWithKey:(NSString *)key
            formValue:(NSString *)value
               logger:(FBSDKLogger *)logger;

- (void)appendWithKey:(NSString *)key
           imageValue:(UIImage *)image
               logger:(FBSDKLogger *)logger;

- (void)appendWithKey:(NSString *)key
            dataValue:(NSData *)data
               logger:(FBSDKLogger *)logger;

- (void)appendWithKey:(NSString *)key
  dataAttachmentValue:(FBSDKGraphRequestDataAttachment *)dataAttachment
               logger:(FBSDKLogger *)logger;

- (NSString *)mimeContentType;

- (NSData *)compressedData;

@end
