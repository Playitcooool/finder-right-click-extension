#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TahoeManagedRootsStore : NSObject
+ (NSArray<NSURL *> *)managedDirectoryURLs;
+ (NSArray<NSString *> *)managedDirectoryPaths;
+ (BOOL)addManagedDirectoryURL:(NSURL *)url error:(NSError **)error;
+ (nullable NSURL *)bestMatchingManagedRootURLForDirectoryPath:(NSString *)directoryPath error:(NSError **)error;
+ (void)removeManagedDirectoryAtPath:(NSString *)path;
+ (void)removeAllManagedDirectories;
+ (void)postManagedRootsDidChangeNotification;
@end

NS_ASSUME_NONNULL_END
