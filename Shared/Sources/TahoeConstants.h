#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const TahoeFinderBundleIdentifier;
FOUNDATION_EXPORT NSString * const TahoeHostBundleIdentifier;
FOUNDATION_EXPORT NSString * const TahoeAppGroupIdentifier;
FOUNDATION_EXPORT NSString * const TahoeMenuItemMarker;
FOUNDATION_EXPORT NSString * const TahoeManagedRootsFilename;
FOUNDATION_EXPORT NSString * const TahoeManagedRootsDidChangeNotification;
FOUNDATION_EXPORT NSString * const TahoeCreateRequestNotification;
FOUNDATION_EXPORT NSString * const TahoeCreateRequestDefaultsKeyPrefix;
FOUNDATION_EXPORT NSString * const TahoeCreateResponseDefaultsKeyPrefix;
FOUNDATION_EXPORT NSString * const TahoeRequestIdentifierKey;
FOUNDATION_EXPORT NSString * const TahoeRequestDirectoryPathKey;
FOUNDATION_EXPORT NSString * const TahoeRequestKindKey;
FOUNDATION_EXPORT NSString * const TahoeDocumentKindText;
FOUNDATION_EXPORT NSString * const TahoeDocumentKindWord;
FOUNDATION_EXPORT NSString * const TahoeDocumentKindExcel;
FOUNDATION_EXPORT NSString * const TahoeDocumentKindPowerPoint;

FOUNDATION_EXPORT NSArray<NSString *> *TahoeAllDocumentKinds(void);
FOUNDATION_EXPORT NSString *TahoeLocalizedMenuTitleForKind(NSString *kindName);
FOUNDATION_EXPORT NSString *TahoeDefaultBaseFilenameForKind(NSString *kindName);
FOUNDATION_EXPORT NSString *TahoeFileExtensionForKind(NSString *kindName);
FOUNDATION_EXPORT NSString *TahoeTemplateFilenameForKind(NSString *kindName);

NS_ASSUME_NONNULL_END
