#import "TahoeFileWriter.h"

#import "TahoeConstants.h"

@interface TahoeFileWriter ()
@property (nonatomic, strong) NSBundle *templateBundle;
@end

@implementation TahoeFileWriter

- (instancetype)initWithTemplateBundle:(NSBundle *)templateBundle {
    self = [super init];
    if (self != nil) {
        _templateBundle = templateBundle;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)createDocumentAtDirectoryPath:(NSString *)directoryPath
                                                       kindName:(NSString *)kindName {
    BOOL isDirectory = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:directoryPath isDirectory:&isDirectory] || !isDirectory) {
        return @{
            @"success": @NO,
            @"errorDescription": @"目标目录不存在或不是目录。"
        };
    }

    NSString *baseName = TahoeDefaultBaseFilenameForKind(kindName);
    NSString *extension = TahoeFileExtensionForKind(kindName);
    NSString *targetPath = [self uniquePathInDirectory:directoryPath
                                              baseName:baseName
                                             extension:extension];

    NSError *error = nil;
    if ([kindName isEqualToString:TahoeDocumentKindText]) {
        [@"" writeToFile:targetPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    } else {
        NSString *templateStem = [TahoeTemplateFilenameForKind(kindName) stringByDeletingPathExtension];
        NSString *templateExtension = [TahoeTemplateFilenameForKind(kindName) pathExtension];
        NSString *templatePath = [self.templateBundle pathForResource:templateStem ofType:templateExtension];
        if (templatePath.length == 0 || ![fileManager fileExistsAtPath:templatePath]) {
            return @{
                @"success": @NO,
                @"errorDescription": @"未找到内置模板，请重新构建扩展。"
            };
        }
        [fileManager copyItemAtPath:templatePath toPath:targetPath error:&error];
    }

    if (error != nil) {
        return @{
            @"success": @NO,
            @"errorDescription": error.localizedDescription ?: @"文件创建失败。"
        };
    }

    return @{
        @"success": @YES,
        @"createdPath": targetPath
    };
}

- (NSString *)uniquePathInDirectory:(NSString *)directoryPath
                           baseName:(NSString *)baseName
                          extension:(NSString *)extension {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSInteger suffix = 1;

    while (YES) {
        NSString *filename = suffix == 1
            ? [NSString stringWithFormat:@"%@.%@", baseName, extension]
            : [NSString stringWithFormat:@"%@ %ld.%@", baseName, (long)suffix, extension];
        NSString *candidate = [directoryPath stringByAppendingPathComponent:filename];
        if (![fileManager fileExistsAtPath:candidate]) {
            return candidate;
        }
        suffix += 1;
    }
}

@end
