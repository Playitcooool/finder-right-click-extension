#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TahoeFileWriter : NSObject
- (instancetype)initWithTemplateBundle:(NSBundle *)templateBundle;
- (NSDictionary<NSString *, id> *)createDocumentAtDirectoryPath:(NSString *)directoryPath
                                                       kindName:(NSString *)kindName;
@end

NS_ASSUME_NONNULL_END
