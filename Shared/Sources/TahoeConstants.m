#import "TahoeConstants.h"

NSString * const TahoeFinderBundleIdentifier = @"com.apple.finder";
NSString * const TahoeAppGroupIdentifier = @"group.com.weiciruan.tahoe.newfile";
NSString * const TahoeMenuItemMarker = @"com.weiciruan.tahoe.new-file";
NSString * const TahoeManagedRootsFilename = @"managed-roots.plist";
NSString * const TahoeManagedRootsDidChangeNotification = @"com.weiciruan.tahoe.ManagedRootsDidChange";
NSString * const TahoeDocumentKindText = @"txt";
NSString * const TahoeDocumentKindWord = @"docx";
NSString * const TahoeDocumentKindExcel = @"xlsx";
NSString * const TahoeDocumentKindPowerPoint = @"pptx";

NSArray<NSString *> *TahoeAllDocumentKinds(void) {
    static NSArray<NSString *> *kinds = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kinds = @[
            TahoeDocumentKindText,
            TahoeDocumentKindWord,
            TahoeDocumentKindExcel,
            TahoeDocumentKindPowerPoint
        ];
    });
    return kinds;
}

NSString *TahoeLocalizedMenuTitleForKind(NSString *kindName) {
    if ([kindName isEqualToString:TahoeDocumentKindText]) {
        return @"新建文本文件";
    }
    if ([kindName isEqualToString:TahoeDocumentKindWord]) {
        return @"新建 Word";
    }
    if ([kindName isEqualToString:TahoeDocumentKindExcel]) {
        return @"新建 Excel";
    }
    if ([kindName isEqualToString:TahoeDocumentKindPowerPoint]) {
        return @"新建 PPT";
    }
    return @"新建文件";
}

NSString *TahoeDefaultBaseFilenameForKind(NSString *kindName) {
    if ([kindName isEqualToString:TahoeDocumentKindText]) {
        return @"新建文本文档";
    }
    if ([kindName isEqualToString:TahoeDocumentKindWord]) {
        return @"新建 Word 文档";
    }
    if ([kindName isEqualToString:TahoeDocumentKindExcel]) {
        return @"新建 Excel 工作簿";
    }
    if ([kindName isEqualToString:TahoeDocumentKindPowerPoint]) {
        return @"新建 PPT 演示文稿";
    }
    return @"新建文件";
}

NSString *TahoeFileExtensionForKind(NSString *kindName) {
    if ([TahoeAllDocumentKinds() containsObject:kindName]) {
        return kindName;
    }
    return @"dat";
}

NSString *TahoeTemplateFilenameForKind(NSString *kindName) {
    if ([kindName isEqualToString:TahoeDocumentKindWord]) {
        return @"Blank.docx";
    }
    if ([kindName isEqualToString:TahoeDocumentKindExcel]) {
        return @"Blank.xlsx";
    }
    if ([kindName isEqualToString:TahoeDocumentKindPowerPoint]) {
        return @"Blank.pptx";
    }
    return @"";
}
