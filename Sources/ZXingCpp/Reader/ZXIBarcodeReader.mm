// Copyright 2022 KURZ Digital Solutions GmbH
//
// SPDX-License-Identifier: Apache-2.0

#import "ZXIBarcodeReader.h"
#import "ReadBarcode.h"
#import "ImageView.h"
#import "Barcode.h"
#import "GTIN.h"
#import "ZXIFormatHelper.h"
#import "ZXIPosition+Helper.h"
#import "ZXIErrors.h"
#import <algorithm>

using namespace ZXing;

NSString *stringToNSString(const std::string &text) {
    return [[NSString alloc]initWithBytes:text.data() length:text.size() encoding:NSUTF8StringEncoding];
}

ZXIGTIN *getGTIN(const Barcode &barcode) {
    // Only attempt GTIN parsing for EAN/UPC barcode formats to avoid C++ exception overhead
    auto f = barcode.format();
    if (f != BarcodeFormat::EAN13 && f != BarcodeFormat::EAN8 &&
        f != BarcodeFormat::UPCA && f != BarcodeFormat::UPCE) {
        return nullptr;
    }
    try {
        auto country = GTIN::LookupCountryIdentifier(barcode.text(TextMode::Plain), barcode.format());
        auto addOn = GTIN::EanAddOn(barcode);
        return country.empty()
            ? nullptr
            : [[ZXIGTIN alloc]initWithCountry:stringToNSString(country)
                                        addOn:stringToNSString(addOn)
                                        price:stringToNSString(GTIN::Price(addOn))
                                  issueNumber:stringToNSString(GTIN::IssueNr(addOn))];
    } catch (...) {
        return nullptr;
    }
}

@interface ZXIReaderOptions()
@property(nonatomic) ZXing::ReaderOptions cppOpts;
@end

@interface ZXIBarcodeReader()
@property (nonatomic, strong) CIContext* ciContext;
@end

@implementation ZXIBarcodeReader

- (instancetype)init {
    return [self initWithOptions: [[ZXIReaderOptions alloc] init]];
}

- (instancetype)initWithOptions:(ZXIReaderOptions*)options {
    self = [super init];
    self.options = options;
    return self;
}

- (CIContext *)ciContext {
    if (!_ciContext) {
        _ciContext = [[CIContext alloc] initWithOptions:@{kCIContextWorkingColorSpace: [NSNull new]}];
    }
    return _ciContext;
}

- (NSArray<ZXIResult *> *)readCVPixelBuffer:(nonnull CVPixelBufferRef)pixelBuffer
                                      error:(NSError *__autoreleasing _Nullable *)error {
    return [self readCVPixelBuffer:pixelBuffer cropRect:CGRectZero error:error];
}

- (NSArray<ZXIResult *> *)readCVPixelBuffer:(nonnull CVPixelBufferRef)pixelBuffer
                                    cropRect:(CGRect)cropRect
                                       error:(NSError *__autoreleasing _Nullable *)error {
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);

    switch (pixelFormat) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: {
            NSInteger cols = CVPixelBufferGetWidth(pixelBuffer);
            NSInteger rows = CVPixelBufferGetHeight(pixelBuffer);
            NSInteger bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            const uint8_t * bytes = static_cast<const uint8_t *>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
            ImageView imageView = ImageView(
                                            static_cast<const uint8_t *>(bytes),
                                            static_cast<int>(cols),
                                            static_cast<int>(rows),
                                            ImageFormat::Lum,
                                            static_cast<int>(bytesPerRow),
                                            0);
            NSArray* results = [self readImageView:imageView cropRect:cropRect error:error];
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            return results;
        }
        case kCVPixelFormatType_32BGRA: {
            NSInteger cols = CVPixelBufferGetWidth(pixelBuffer);
            NSInteger rows = CVPixelBufferGetHeight(pixelBuffer);
            NSInteger bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            const uint8_t * bytes = static_cast<const uint8_t *>(CVPixelBufferGetBaseAddress(pixelBuffer));
            ImageView imageView = ImageView(
                                            static_cast<const uint8_t *>(bytes),
                                            static_cast<int>(cols),
                                            static_cast<int>(rows),
                                            ImageFormat::BGRX,
                                            static_cast<int>(bytesPerRow),
                                            0);
            NSArray* results = [self readImageView:imageView cropRect:cropRect error:error];
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            return results;
        }
        case kCVPixelFormatType_32ARGB: {
            NSInteger cols = CVPixelBufferGetWidth(pixelBuffer);
            NSInteger rows = CVPixelBufferGetHeight(pixelBuffer);
            NSInteger bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            const uint8_t * bytes = static_cast<const uint8_t *>(CVPixelBufferGetBaseAddress(pixelBuffer));
            ImageView imageView = ImageView(
                                            static_cast<const uint8_t *>(bytes),
                                            static_cast<int>(cols),
                                            static_cast<int>(rows),
                                            ImageFormat::XRGB,
                                            static_cast<int>(bytesPerRow),
                                            0);
            NSArray* results = [self readImageView:imageView cropRect:cropRect error:error];
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            return results;
        }
        case kCVPixelFormatType_32RGBA: {
            NSInteger cols = CVPixelBufferGetWidth(pixelBuffer);
            NSInteger rows = CVPixelBufferGetHeight(pixelBuffer);
            NSInteger bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            const uint8_t * bytes = static_cast<const uint8_t *>(CVPixelBufferGetBaseAddress(pixelBuffer));
            ImageView imageView = ImageView(
                                            static_cast<const uint8_t *>(bytes),
                                            static_cast<int>(cols),
                                            static_cast<int>(rows),
                                            ImageFormat::RGBX,
                                            static_cast<int>(bytesPerRow),
                                            0);
            NSArray* results = [self readImageView:imageView cropRect:cropRect error:error];
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            return results;
        }
    }

    return [self readCIImage:[[CIImage alloc] initWithCVImageBuffer:pixelBuffer] cropRect:cropRect error:error];
}

- (NSArray<ZXIResult *> *)readCMSampleBuffer:(nonnull CMSampleBufferRef)sampleBuffer
                                       error:(NSError *__autoreleasing _Nullable *)error {
    return [self readCMSampleBuffer:sampleBuffer cropRect:CGRectZero error:error];
}

- (NSArray<ZXIResult *> *)readCMSampleBuffer:(nonnull CMSampleBufferRef)sampleBuffer
                                     cropRect:(CGRect)cropRect
                                        error:(NSError *__autoreleasing _Nullable *)error {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) {
        SetNSError(error, ZXIReaderError, "CMSampleBuffer does not contain a valid CVPixelBuffer");
        return @[];
    }
    return [self readCVPixelBuffer:pixelBuffer cropRect:cropRect error:error];
}

- (NSArray<ZXIResult *> *)readCIImage:(nonnull CIImage *)image
                                error:(NSError *__autoreleasing _Nullable *)error {
    return [self readCIImage:image cropRect:CGRectZero error:error];
}

- (NSArray<ZXIResult *> *)readCIImage:(nonnull CIImage *)image
                              cropRect:(CGRect)cropRect
                                 error:(NSError *__autoreleasing _Nullable *)error {
    CGImageRef cgImage = [self.ciContext createCGImage:image fromRect:image.extent];
    if (!cgImage) {
        SetNSError(error, ZXIReaderError, "Failed to create CGImage from CIImage");
        return @[];
    }
    auto results = [self readCGImage:cgImage cropRect:cropRect error:error];
    CGImageRelease(cgImage);
    return results;
}

- (NSArray<ZXIResult *> *)readCGImage:(nonnull CGImageRef)image
                                error:(NSError *__autoreleasing _Nullable *)error {
    return [self readCGImage:image cropRect:CGRectZero error:error];
}

- (NSArray<ZXIResult *> *)readCGImage:(nonnull CGImageRef)image
                              cropRect:(CGRect)cropRect
                                 error:(NSError *__autoreleasing _Nullable *)error {
    size_t fullCols = CGImageGetWidth(image);
    size_t fullRows = CGImageGetHeight(image);
    if (fullCols == 0 || fullRows == 0) {
        return @[];
    }

    size_t left = 0, top = 0, targetWidth = fullCols, targetHeight = fullRows;
    BOOL isCropped = NO;

    if (!CGRectIsEmpty(cropRect) && cropRect.size.width > 0 && cropRect.size.height > 0) {
        if (cropRect.origin.x >= 0 && cropRect.origin.x <= 1.0 &&
            cropRect.origin.y >= 0 && cropRect.origin.y <= 1.0 &&
            cropRect.size.width <= 1.0 && cropRect.size.height <= 1.0) {
            left = static_cast<size_t>(cropRect.origin.x * fullCols);
            top = static_cast<size_t>(cropRect.origin.y * fullRows);
            targetWidth = static_cast<size_t>(cropRect.size.width * fullCols);
            targetHeight = static_cast<size_t>(cropRect.size.height * fullRows);
        } else {
            left = static_cast<size_t>(cropRect.origin.x);
            top = static_cast<size_t>(cropRect.origin.y);
            targetWidth = static_cast<size_t>(cropRect.size.width);
            targetHeight = static_cast<size_t>(cropRect.size.height);
        }
        left = std::min(left, fullCols - 1);
        top = std::min(top, fullRows - 1);
        targetWidth = std::min(targetWidth, fullCols - left);
        targetHeight = std::min(targetHeight, fullRows - top);
        if (targetWidth < fullCols || targetHeight < fullRows) {
            isCropped = YES;
        }
    }

    std::vector<uint8_t> data(targetWidth * targetHeight);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
    CGContextRef contextRef = CGBitmapContextCreate(data.data(),
                                                    targetWidth,
                                                    targetHeight,
                                                    8,
                                                    targetWidth,
                                                    colorSpace,
                                                    kCGBitmapByteOrderDefault);
    CGColorSpaceRelease(colorSpace);
    if (contextRef) {
        if (isCropped) {
            CGFloat drawY = -static_cast<CGFloat>(fullRows - top - targetHeight);
            CGContextDrawImage(contextRef, CGRectMake(-static_cast<CGFloat>(left), drawY, static_cast<CGFloat>(fullCols), static_cast<CGFloat>(fullRows)), image);
        } else {
            CGContextDrawImage(contextRef, CGRectMake(0, 0, static_cast<CGFloat>(fullCols), static_cast<CGFloat>(fullRows)), image);
        }
        CGContextRelease(contextRef);
    }

    ImageView imageView = ImageView(
              static_cast<const uint8_t *>(data.data()),
              static_cast<int>(targetWidth),
              static_cast<int>(targetHeight),
              ImageFormat::Lum);
    return [self readImageView:imageView cropRect:CGRectZero error:error];
}

- (NSArray<ZXIResult*> *)readImageView:(ImageView)imageView
                              cropRect:(CGRect)cropRect
                                 error:(NSError *__autoreleasing _Nullable *)error {
    try {
        ImageView targetView = imageView;
        if (!CGRectIsEmpty(cropRect) && cropRect.size.width > 0 && cropRect.size.height > 0) {
            int left = 0, top = 0, width = imageView.width(), height = imageView.height();
            if (cropRect.origin.x >= 0 && cropRect.origin.x <= 1.0 &&
                cropRect.origin.y >= 0 && cropRect.origin.y <= 1.0 &&
                cropRect.size.width <= 1.0 && cropRect.size.height <= 1.0) {
                left = static_cast<int>(cropRect.origin.x * imageView.width());
                top = static_cast<int>(cropRect.origin.y * imageView.height());
                width = static_cast<int>(cropRect.size.width * imageView.width());
                height = static_cast<int>(cropRect.size.height * imageView.height());
            } else {
                left = static_cast<int>(cropRect.origin.x);
                top = static_cast<int>(cropRect.origin.y);
                width = static_cast<int>(cropRect.size.width);
                height = static_cast<int>(cropRect.size.height);
            }
            targetView = imageView.cropped(left, top, width, height);
        }
        Barcodes results = ReadBarcodes(targetView, self.options.cppOpts);
        NSMutableArray* zxiResults = [NSMutableArray array];
        for (auto result: results) {
            [zxiResults addObject:
             [[ZXIResult alloc] init:stringToNSString(result.text())
                              format:ZXIFormatFromBarcodeFormat(result.format())
                              bytes:[[NSData alloc] initWithBytes:result.bytes().data() length:result.bytes().size()]
                            position:[[ZXIPosition alloc]initWithPosition: result.position()]
                         orientation:result.orientation()
                             ecLevel:stringToNSString(result.ecLevel())
                 symbologyIdentifier:stringToNSString(result.symbologyIdentifier())
                        sequenceSize:result.sequenceSize()
                       sequenceIndex:result.sequenceIndex()
                          sequenceId:stringToNSString(result.sequenceId())
                          readerInit:result.readerInit()
                           lineCount:result.lineCount()
                                gtin:getGTIN(result)]
             ];
        }
        return zxiResults;
    } catch(std::exception &e) {
        SetNSError(error, ZXIReaderError, e.what());
        return nil;
    } catch (...) {
        SetNSError(error, ZXIReaderError, "An unknown error occurred");
        return nil;
    }
}

@end
