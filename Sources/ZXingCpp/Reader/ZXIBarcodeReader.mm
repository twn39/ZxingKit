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

using namespace ZXing;

NSString *stringToNSString(const std::string &text) {
    return [[NSString alloc]initWithBytes:text.data() length:text.size() encoding:NSUTF8StringEncoding];
}

ZXIGTIN *getGTIN(const Barcode &barcode) {
    try {
        auto country = GTIN::LookupCountryIdentifier(barcode.text(TextMode::Plain), barcode.format());
        auto addOn = GTIN::EanAddOn(barcode);
        return country.empty()
            ? nullptr
            : [[ZXIGTIN alloc]initWithCountry:stringToNSString(country)
                                        addOn:stringToNSString(addOn)
                                        price:stringToNSString(GTIN::Price(addOn))
                                  issueNumber:stringToNSString(GTIN::IssueNr(addOn))];
    } catch (std::exception e) {
        // Because invalid GTIN data can lead to exceptions, in which case
        // we don't want to discard the whole result.
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

- (instancetype)initWithOptions:(ZXIReaderOptions*)options{
    self = [super init];
    self.ciContext = [[CIContext alloc] initWithOptions:@{kCIContextWorkingColorSpace: [NSNull new]}];
    self.options = options;
    return self;
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
    CGFloat cols = CGImageGetWidth(image);
    CGFloat rows = CGImageGetHeight(image);
    std::vector<uint8_t> data(cols * rows);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
    CGContextRef contextRef = CGBitmapContextCreate(data.data(),
                                                    cols,
                                                    rows,
                                                    8,
                                                    cols,
                                                    colorSpace,
                                                    kCGBitmapByteOrderDefault);
    CGColorSpaceRelease(colorSpace);
    if (contextRef) {
        CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image);
        CGContextRelease(contextRef);
    }

    ImageView imageView = ImageView(
              static_cast<const uint8_t *>(data.data()),
              static_cast<int>(cols),
              static_cast<int>(rows),
              ImageFormat::Lum);
    return [self readImageView:imageView cropRect:cropRect error:error];
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
