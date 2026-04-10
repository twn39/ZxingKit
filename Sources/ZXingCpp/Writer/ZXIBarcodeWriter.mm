// Copyright 2022 KURZ Digital Solutions GmbH
//
// SPDX-License-Identifier: Apache-2.0

#import <CoreGraphics/CoreGraphics.h>
#import "ZXIBarcodeWriter.h"
#import "ZXIWriterOptions.h"
#import "CreateBarcode.h"
#import "WriteBarcode.h"
#import "ZXIFormatHelper.h"
#import "ZXIErrors.h"
#import <iostream>

using namespace ZXing;

std::string NSStringToStringUTF8(NSString* str) {
    if (!str) return "";
    const char* utf8 = [str UTF8String];
    return utf8 ? std::string(utf8) : "";
}

std::string NSDataToString(NSData *data) {
    if (!data) return "";
    return std::string((const char*)[data bytes], [data length]);
}

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
    try {
        std::string optionsStr = "";
        if (self.options.ecLevel >= 0) {
            optionsStr = "{\"ecLevel\":\"" + std::to_string(self.options.ecLevel) + "\"}";
        }
        CreatorOptions cOpts(BarcodeFormatFromZXIFormat(self.options.format), optionsStr);
        
        Barcode barcode = CreateBarcodeFromBytes([data bytes], (int)[data length], cOpts);
        return [self generateCGImage:barcode error:error];
    } catch(std::exception &e) {
        SetNSError(error, ZXIWriterError, e.what());
        return nil;
    }
}

-(CGImageRef)writeString:(NSString *)contents
                   error:(NSError *__autoreleasing  _Nullable *)error {
    try {
        std::string optionsStr = "";
        if (self.options.ecLevel >= 0) {
            optionsStr = "{\"ecLevel\":\"" + std::to_string(self.options.ecLevel) + "\"}";
        }
        CreatorOptions cOpts(BarcodeFormatFromZXIFormat(self.options.format), optionsStr);
        
        std::string utf8Content = NSStringToStringUTF8(contents);
        Barcode barcode = CreateBarcodeFromText(utf8Content, cOpts);
        
        return [self generateCGImage:barcode error:error];
    } catch(std::exception &e) {
        SetNSError(error, ZXIWriterError, e.what());
        return nil;
    }
}

-(CGImageRef)generateCGImage:(const Barcode&)barcode error:(NSError *__autoreleasing  _Nullable *)error CF_RETURNS_RETAINED {
    int scale = 1;
    // If a target width is provided, we can use it as a negative scale hint
    if (self.options.width > 0) {
        scale = -self.options.width;
    }
    
    WriterOptions wOpts;
    wOpts.scale(scale);
    wOpts.addQuietZones(self.options.margin > 0);
    
    Image image = WriteBarcodeToImage(barcode, wOpts);
    
    int realWidth = image.width();
    int realHeight = image.height();
    
    NSMutableData *resultAsNSData = [[NSMutableData alloc] initWithLength:realWidth * realHeight];
    uint8_t *bytes = (uint8_t*)resultAsNSData.mutableBytes;
    
    const uint8_t* imageData = image.data();
    for (int i = 0; i < realWidth * realHeight; ++i) {
        // The Image returned by WriteBarcodeToImage has Lum format (0 for black, 255 for white)
        bytes[i] = imageData[i];
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);

    return CGImageCreate(realWidth,
                         realHeight,
                         8,
                         8,
                         realWidth,
                         colorSpace,
                         kCGBitmapByteOrderDefault,
                         CGDataProviderCreateWithCFData((CFDataRef)resultAsNSData),
                         NULL,
                         YES,
                         kCGRenderingIntentDefault);
}

@end
