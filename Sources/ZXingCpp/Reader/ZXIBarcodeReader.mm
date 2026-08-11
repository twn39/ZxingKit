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

// Issue #6: Use Latin-1 fallback for non-UTF-8 content (binary payloads, legacy EAN encodings).
// Returning nil from NSString initWithBytes would crash the Swift bridge (non-optional String).
NSString *stringToNSString(const std::string &text) {
    if (text.empty()) { return @""; }
    NSString *s = [[NSString alloc] initWithBytes:text.data()
                                           length:text.size()
                                         encoding:NSUTF8StringEncoding];
    if (!s) {
        s = [[NSString alloc] initWithBytes:text.data()
                                     length:text.size()
                                   encoding:NSISOLatin1StringEncoding];
    }
    return s ?: @"";
}

ZXIGTIN *getGTIN(const ZXing::Barcode &barcode) {
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

// Issue #8: Shared ROI pixel resolution — eliminates duplicated normalised/pixel coordinate logic.
struct ZXIPixelROI { int left, top, width, height; };

static ZXIPixelROI resolvePixelROI(CGRect cropRect, int fullWidth, int fullHeight) {
    ZXIPixelROI roi = {0, 0, fullWidth, fullHeight};
    if (CGRectIsEmpty(cropRect) || cropRect.size.width <= 0 || cropRect.size.height <= 0) {
        return roi;
    }
    // Detect normalised coordinates (all values in [0,1])
    if (cropRect.origin.x >= 0 && cropRect.origin.x <= 1.0 &&
        cropRect.origin.y >= 0 && cropRect.origin.y <= 1.0 &&
        cropRect.size.width <= 1.0 && cropRect.size.height <= 1.0) {
        roi.left   = static_cast<int>(cropRect.origin.x   * fullWidth);
        roi.top    = static_cast<int>(cropRect.origin.y   * fullHeight);
        roi.width  = static_cast<int>(cropRect.size.width  * fullWidth);
        roi.height = static_cast<int>(cropRect.size.height * fullHeight);
    } else {
        roi.left   = static_cast<int>(cropRect.origin.x);
        roi.top    = static_cast<int>(cropRect.origin.y);
        roi.width  = static_cast<int>(cropRect.size.width);
        roi.height = static_cast<int>(cropRect.size.height);
    }
    roi.left  = std::min(roi.left,  fullWidth  - 1);
    roi.top   = std::min(roi.top,   fullHeight - 1);
    roi.width = std::min(roi.width,  fullWidth  - roi.left);
    roi.height= std::min(roi.height, fullHeight - roi.top);
    return roi;
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
    if (!pixelBuffer) {
        SetNSError(error, ZXIReaderError, "Invalid CVPixelBuffer (NULL)");
        return @[];
    }

    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);

    switch (pixelFormat) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: {
            NSInteger cols = CVPixelBufferGetWidth(pixelBuffer);
            NSInteger rows = CVPixelBufferGetHeight(pixelBuffer);
            if (cols <= 0 || rows <= 0) {
                return @[];
            }
            NSInteger bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            const uint8_t * bytes = static_cast<const uint8_t *>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
            if (!bytes) {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
                SetNSError(error, ZXIReaderError, "Failed to get base address of CVPixelBuffer");
                return @[];
            }
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
            if (cols <= 0 || rows <= 0) {
                return @[];
            }
            NSInteger bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            const uint8_t * bytes = static_cast<const uint8_t *>(CVPixelBufferGetBaseAddress(pixelBuffer));
            if (!bytes) {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
                SetNSError(error, ZXIReaderError, "Failed to get base address of CVPixelBuffer");
                return @[];
            }
            ImageView imageView = ImageView(
                                            static_cast<const uint8_t *>(bytes),
                                            static_cast<int>(cols),
                                            static_cast<int>(rows),
                                            ImageFormat::BGRA,
                                            static_cast<int>(bytesPerRow),
                                            0);
            NSArray* results = [self readImageView:imageView cropRect:cropRect error:error];
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            return results;
        }
        case kCVPixelFormatType_32ARGB: {
            NSInteger cols = CVPixelBufferGetWidth(pixelBuffer);
            NSInteger rows = CVPixelBufferGetHeight(pixelBuffer);
            if (cols <= 0 || rows <= 0) {
                return @[];
            }
            NSInteger bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            const uint8_t * bytes = static_cast<const uint8_t *>(CVPixelBufferGetBaseAddress(pixelBuffer));
            if (!bytes) {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
                SetNSError(error, ZXIReaderError, "Failed to get base address of CVPixelBuffer");
                return @[];
            }
            ImageView imageView = ImageView(
                                            static_cast<const uint8_t *>(bytes),
                                            static_cast<int>(cols),
                                            static_cast<int>(rows),
                                            ImageFormat::ARGB,
                                            static_cast<int>(bytesPerRow),
                                            0);
            NSArray* results = [self readImageView:imageView cropRect:cropRect error:error];
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            return results;
        }
        case kCVPixelFormatType_32RGBA: {
            NSInteger cols = CVPixelBufferGetWidth(pixelBuffer);
            NSInteger rows = CVPixelBufferGetHeight(pixelBuffer);
            if (cols <= 0 || rows <= 0) {
                return @[];
            }
            NSInteger bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            const uint8_t * bytes = static_cast<const uint8_t *>(CVPixelBufferGetBaseAddress(pixelBuffer));
            if (!bytes) {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
                SetNSError(error, ZXIReaderError, "Failed to get base address of CVPixelBuffer");
                return @[];
            }
            ImageView imageView = ImageView(
                                            static_cast<const uint8_t *>(bytes),
                                            static_cast<int>(cols),
                                            static_cast<int>(rows),
                                            ImageFormat::RGBA,
                                            static_cast<int>(bytesPerRow),
                                            0);
            NSArray* results = [self readImageView:imageView cropRect:cropRect error:error];
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            return results;
        }
    }

    CIImage *ciImg = [[CIImage alloc] initWithCVImageBuffer:pixelBuffer];
    if (!ciImg) {
        SetNSError(error, ZXIReaderError, "Failed to convert CVPixelBuffer to CIImage");
        return @[];
    }
    return [self readCIImage:ciImg cropRect:cropRect error:error];
}

- (NSArray<ZXIResult *> *)readCMSampleBuffer:(nonnull CMSampleBufferRef)sampleBuffer
                                       error:(NSError *__autoreleasing _Nullable *)error {
    return [self readCMSampleBuffer:sampleBuffer cropRect:CGRectZero error:error];
}

- (NSArray<ZXIResult *> *)readCMSampleBuffer:(nonnull CMSampleBufferRef)sampleBuffer
                                     cropRect:(CGRect)cropRect
                                        error:(NSError *__autoreleasing _Nullable *)error {
    if (!sampleBuffer) {
        SetNSError(error, ZXIReaderError, "Invalid CMSampleBuffer (NULL)");
        return @[];
    }
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
    if (!image) {
        SetNSError(error, ZXIReaderError, "Invalid CIImage (nil)");
        return @[];
    }
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
    if (!image) {
        SetNSError(error, ZXIReaderError, "Invalid CGImageRef (NULL)");
        return @[];
    }
    size_t fullCols = CGImageGetWidth(image);
    size_t fullRows = CGImageGetHeight(image);
    if (fullCols == 0 || fullRows == 0) {
        return @[];
    }

    // Issue #8: Use shared resolvePixelROI — eliminates the second copy of the normalised/pixel logic.
    ZXIPixelROI roi = resolvePixelROI(cropRect, static_cast<int>(fullCols), static_cast<int>(fullRows));
    size_t left = static_cast<size_t>(roi.left);
    size_t top = static_cast<size_t>(roi.top);
    size_t targetWidth = static_cast<size_t>(roi.width);
    size_t targetHeight = static_cast<size_t>(roi.height);
    BOOL isCropped = (targetWidth < fullCols || targetHeight < fullRows);

    std::vector<uint8_t> data(targetWidth * targetHeight);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
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
            // Issue #8: Use shared resolvePixelROI to avoid duplicated coordinate logic.
            ZXIPixelROI roi = resolvePixelROI(cropRect, imageView.width(), imageView.height());
            targetView = imageView.cropped(roi.left, roi.top, roi.width, roi.height);
        }
        Barcodes results = ReadBarcodes(targetView, self.options.cppOpts);
        NSMutableArray* zxiResults = [NSMutableArray array];
        for (auto result: results) {
            // Issue #2: ZXing::Position (QuadrilateralI) has no isValid().
            // For any real detection, at least one corner will be non-zero.
            // Only generated/synthesized results with no detection may yield all-zero coordinates.
            auto& pos = result.position();
            BOOL hasValidPos = pos.topLeft().x != 0 || pos.topLeft().y != 0 ||
                               pos.topRight().x != 0 || pos.topRight().y != 0 ||
                               pos.bottomRight().x != 0 || pos.bottomRight().y != 0 ||
                               pos.bottomLeft().x != 0 || pos.bottomLeft().y != 0;
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
                                gtin:getGTIN(result)
                    hasValidPosition:hasValidPos]
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
