// Copyright 2022 KURZ Digital Solutions GmbH
//
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>
#import "ZXIFormat.h"
#import "ZXIPosition.h"
#import "ZXIGTIN.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_SENDABLE
@interface ZXIResult : NSObject
@property(nonatomic, strong) NSString *text;
@property(nonatomic, strong) NSData *bytes;
@property(nonatomic, strong) ZXIPosition *position;
@property(nonatomic) ZXIFormat format;
@property(nonatomic) NSInteger orientation;
@property(nonatomic, strong) NSString *ecLevel;
@property(nonatomic, strong) NSString *symbologyIdentifier;
@property(nonatomic) NSInteger sequenceSize;
@property(nonatomic) NSInteger sequenceIndex;
@property(nonatomic, strong) NSString *sequenceId;
@property(nonatomic) BOOL readerInit;
@property(nonatomic) NSInteger lineCount;
/// GTIN metadata for EAN/UPC barcodes; nil for all other formats.
@property(nonatomic, nullable, strong) ZXIGTIN *gtin;
/// Indicates whether the position data returned by zxing-cpp is valid.
@property(nonatomic) BOOL hasValidPosition;

- (instancetype)init:(NSString *)text
              format:(ZXIFormat)format
               bytes:(NSData *)bytes
            position:(ZXIPosition *)position
         orientation:(NSInteger)orientation
             ecLevel:(NSString *)ecLevel
 symbologyIdentifier:(NSString *)symbologyIdentifier
        sequenceSize:(NSInteger)sequenceSize
       sequenceIndex:(NSInteger)sequenceIndex
          sequenceId:(NSString *)sequenceId
          readerInit:(BOOL)readerInit
           lineCount:(NSInteger)lineCount
                gtin:(nullable ZXIGTIN *)gtin
    hasValidPosition:(BOOL)hasValidPosition;
@end

NS_ASSUME_NONNULL_END
