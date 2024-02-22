#import <Foundation/Foundation.h>
#import <PSHeader/Misc.h>
#import <version.h>

@interface NSLocale (Translation)
- (NSString *)_ltLocaleIdentifier;
@end

#define AssetVersion "6"
#define AssetID "com.apple.MobileAsset.SpeechTranslationAssets"

typedef struct __SecTask *SecTaskRef;

extern CFTypeRef SecTaskCopyValueForEntitlement(SecTaskRef task, CFStringRef entitlement, CFErrorRef *error);

@interface MAAssetQuery : NSObject
@property (readonly, nonatomic) NSString *assetType;
@property (readonly, nonatomic) NSInteger returnTypes;
@end

typedef void (^Completion)(NSInteger result);

%group translationd

%hook MAAsset

// Redirect the asset download to the latest one
+ (void)startCatalogDownload:(NSString *)assetType options:(id)options then:(Completion)completionBlock {
    if ([assetType hasPrefix:@(AssetID)])
        %orig(@(AssetID AssetVersion), options, completionBlock);
    else
        %orig;
}

%end

%hook MAAssetQuery

// Redirect the asset to the latest one except when the asset is to be removed(?)
- (void)returnTypes:(int64_t)types {
    if (types != 2 && [self.assetType hasPrefix:@(AssetID)])
        [self setValue:@(AssetID AssetVersion) forKey:@"assetType"];
    %orig;
}

%end

%hook _LTSpeechTranslationAssetInfo

// Asset v6 changes the data structure, now each language pair contains an array configuration dictionaries
// For simplicity sake, we use the first dictionary (RequiredCapabilityIdentifier = 0, Apple Neutral Engine related)
- (id)initWithInstalledAssets:(id)arg1 catalogAssets:(id)arg2 localePair:(id)arg3 configInfo:(id)configInfo assetManager:(id)arg5 {
    NSArray <NSDictionary *> *modernConfigInfo = configInfo[0];
    return %orig(arg1, arg2, arg3, modernConfigInfo, arg5);
}

%end

%end

%group translationd_voiceType

// Apple's iOS 16 voice type overriding code ported to older iOS versions
// Otherwise, the translation server will simply reject the translation request
NSInteger (*_LTVoiceTypeLocaleOverride)(NSInteger, NSLocale *);
%hookf(NSInteger, _LTVoiceTypeLocaleOverride, NSInteger value, NSLocale *locale) {
    if ([@[@"id_ID", @"pl_PL", @"th_TH", @"uk_UA", @"vi_VN"] containsObject:[locale _ltLocaleIdentifier]])
        return 2;
    return %orig;
}

%end

%group mobileassetd

// Ensure translationd is entitled to download the speech translation assets
%hookf(CFTypeRef, SecTaskCopyValueForEntitlement, SecTaskRef task, CFStringRef entitlement, CFErrorRef *error) {
    if (CFStringEqual(entitlement, CFSTR(AssetID AssetVersion)))
        return kCFBooleanTrue;
    return %orig(task, entitlement, error);
}

%end

FOUNDATION_EXPORT char ***_NSGetArgv();

%ctor {
    char *executablePathC = **_NSGetArgv();
    NSString *executablePath = [NSString stringWithUTF8String:executablePathC];
    NSString *processName = [executablePath lastPathComponent];
    if ([processName isEqualToString:@"translationd"]) {
        if (!IS_IOS_OR_NEWER(iOS_16_0)) {
            MSImageRef ref = MSGetImageByName("/System/Library/PrivateFrameworks/Translation.framework/Translation");
            _LTVoiceTypeLocaleOverride = (NSInteger (*)(NSInteger, NSLocale *))MSFindSymbol(ref, "__LTVoiceTypeLocaleOverride");
            %init(translationd_voiceType);
        }
        %init(translationd);
    } else {
        %init(mobileassetd);
    }
}