// Copyright 2022 KURZ Digital Solutions GmbH
//
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>
#import "ZXIWriterOptions.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_SENDABLE
@interface ZXIBarcodeWriter : NSObject
@property(nonatomic, strong) ZXIWriterOptions *options;

/// Use `initWithOptions:` instead. Calling bare `init` leaves `options` unset.
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

-(instancetype)initWithOptions:(ZXIWriterOptions*)options;

-(nullable CGImageRef)writeString:(NSString *)contents
                            error:(NSError *__autoreleasing  _Nullable *)error CF_RETURNS_RETAINED;

-(nullable CGImageRef)writeData:(NSData *)data
                          error:(NSError *__autoreleasing  _Nullable *)error CF_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END
