// Copyright 2022 KURZ Digital Solutions GmbH
//
// SPDX-License-Identifier: Apache-2.0

#import <CoreGraphics/CoreGraphics.h>
#import "ZXIBarcodeWriter.h"
#import "ZXIWriterOptions.h"
#import "CreateBarcode.h"
#import "WriteBarcode.h"
#import "ImageView.h"
#import "ZXIFormatHelper.h"
#import "ZXIErrors.h"
#import <iostream>

using namespace ZXing;

@implementation ZXIBarcodeWriter

- (instancetype)init {
    return [self initWithOptions: [[ZXIWriterOptions alloc] init]];
}

- (instancetype)initWithOptions:(ZXIWriterOptions*)options{
    self = [super init];
    self.options = options;
    return self;
}

-(CGImageRef)writeData:(NSData *)data
                 error:(NSError *__autoreleasing  _Nullable *)error {
    return [self encodeBytes:(const uint8_t *)[data bytes]
                      length:(int)[data length]
                      format:self.options.format
                       width:self.options.width
                      height:self.options.height
                      margin:self.options.margin
                     ecLevel:self.options.ecLevel
                       error:error];
}

-(CGImageRef)writeString:(NSString *)contents
                   error:(NSError *__autoreleasing  _Nullable *)error {
    return [self encodeText:[contents UTF8String] ?: ""
                     format:self.options.format
                      width:self.options.width
                     height:self.options.height
                     margin:self.options.margin
                    ecLevel:self.options.ecLevel
                      error:error];
}

-(CGImageRef)encodeText:(std::string)content
                 format:(ZXIFormat)format
                  width:(int)width
                 height:(int)height
                 margin:(int)margin
                ecLevel:(int)ecLevel
                  error:(NSError *__autoreleasing  _Nullable *)error {
    try {
        BarcodeFormat zf = BarcodeFormatFromZXIFormat(format);
        std::string optStr = "";
        if (ecLevel >= 0) {
            optStr = "ecLevel=" + std::to_string(ecLevel);
        }
        CreatorOptions opts(zf, optStr);
        Barcode barcode = CreateBarcodeFromText(content, opts);
        if (!barcode.isValid()) {
            SetNSError(error, ZXIWriterError, barcode.error().msg().c_str());
            return nil;
        }

        WriterOptions wOpts;
        if (margin >= 0) {
            wOpts.addQuietZones(margin > 0);
        }
        if (width > 0 && barcode.symbol().width() > 0) {
            int totalSymModules = barcode.symbol().width() + (margin != 0 ? 8 : 0);
            int scale = std::max(1, width / totalSymModules);
            wOpts.scale(scale);
        }

        Image img = WriteBarcodeToImage(barcode, wOpts);
        return [self imageToCGImage:img];
    } catch(std::exception &e) {
        SetNSError(error, ZXIWriterError, e.what());
        return nil;
    }
}

-(CGImageRef)encodeBytes:(const uint8_t*)data
                  length:(int)length
                  format:(ZXIFormat)format
                   width:(int)width
                  height:(int)height
                  margin:(int)margin
                 ecLevel:(int)ecLevel
                   error:(NSError *__autoreleasing  _Nullable *)error {
    try {
        BarcodeFormat zf = BarcodeFormatFromZXIFormat(format);
        std::string optStr = "";
        if (ecLevel >= 0) {
            optStr = "ecLevel=" + std::to_string(ecLevel);
        }
        CreatorOptions opts(zf, optStr);
        Barcode barcode = CreateBarcodeFromBytes(data, length, opts);
        if (!barcode.isValid()) {
            SetNSError(error, ZXIWriterError, barcode.error().msg().c_str());
            return nil;
        }

        WriterOptions wOpts;
        if (margin >= 0) {
            wOpts.addQuietZones(margin > 0);
        }
        if (width > 0 && barcode.symbol().width() > 0) {
            int totalSymModules = barcode.symbol().width() + (margin != 0 ? 8 : 0);
            int scale = std::max(1, width / totalSymModules);
            wOpts.scale(scale);
        }

        Image img = WriteBarcodeToImage(barcode, wOpts);
        return [self imageToCGImage:img];
    } catch(std::exception &e) {
        SetNSError(error, ZXIWriterError, e.what());
        return nil;
    }
}

-(CGImageRef)imageToCGImage:(const Image&)img {
    int realWidth = img.width();
    int realHeight = img.height();

    NSData *resultAsNSData = [NSData dataWithBytes:img.data() length:img.rowStride() * realHeight];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);

    CGImageRef cgImg = CGImageCreate(realWidth,
                                     realHeight,
                                     8,
                                     8,
                                     img.rowStride(),
                                     colorSpace,
                                     kCGBitmapByteOrderDefault,
                                     CGDataProviderCreateWithCFData((CFDataRef)resultAsNSData),
                                     NULL,
                                     YES,
                                     kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    return cgImg;
}

@end
