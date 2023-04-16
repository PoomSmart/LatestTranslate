#import <Foundation/Foundation.h>
#import <PSHeader/Misc.h>
#import <version.h>

@interface NSLocale (Translation)
- (NSString *)_ltLocaleIdentifier;
@end

#define AssetVersion "4"
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

// Bypass the config file version check
int (*checkConfigFileVersion)(int);
%hookf(int, checkConfigFileVersion, int arg) {
    return 1;
}

%end

%group translationd_voiceType

// Apple's iOS 16 overriding code ported to older iOS versions
NSInteger (*_LTVoiceTypeLocaleOverride)(NSInteger, NSLocale *);
%hookf(NSInteger, _LTVoiceTypeLocaleOverride, NSInteger value, NSLocale *locale) {
    if ([@[@"id_ID", @"pl_PL", @"th_TH", @"vi_VN"] containsObject:[locale _ltLocaleIdentifier]])
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
        MSImageRef ear = MSGetImageByName("/System/Library/PrivateFrameworks/EmbeddedAcousticRecognition.framework/EmbeddedAcousticRecognition");
        checkConfigFileVersion = (int (*)(int))MSFindSymbol(ear, "__ZN6quasar12SystemConfig22checkConfigFileVersionEv");
        %init(translationd);
    } else {
        %init(mobileassetd);
    }
}