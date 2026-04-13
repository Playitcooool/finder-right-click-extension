#import "TahoeManagedRootsStore.h"

#import "TahoeConstants.h"

static NSString * const TahoeManagedRootPathKey = @"path";
static NSString * const TahoeManagedRootBookmarkKey = @"bookmark";

@implementation TahoeManagedRootsStore

+ (NSURL *)storageFileURL {
    NSURL *baseDirectory = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:TahoeAppGroupIdentifier];
    if (baseDirectory == nil) {
        return [self legacyStorageFileURL];
    }

    NSURL *directory = [baseDirectory URLByAppendingPathComponent:@"TahoeNewFile" isDirectory:YES];
    NSError *directoryError = nil;
    [NSFileManager.defaultManager createDirectoryAtURL:directory
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:&directoryError];
    if (directoryError != nil) {
        NSLog(@"[TahoeManagedRootsStore] Failed to create app group storage directory %@: %@", directory.path, directoryError);
    }
    return [directory URLByAppendingPathComponent:TahoeManagedRootsFilename];
}

+ (NSURL *)legacyStorageFileURL {
    NSURL *baseDirectory = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                                                inDomains:NSUserDomainMask].firstObject;
    NSURL *directory = [baseDirectory URLByAppendingPathComponent:@"TahoeNewFile" isDirectory:YES];
    return [directory URLByAppendingPathComponent:TahoeManagedRootsFilename];
}

+ (NSUserDefaults *)sharedDefaults {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:TahoeAppGroupIdentifier];
    if (defaults == nil) {
        NSLog(@"[TahoeManagedRootsStore] Falling back to standard user defaults for %@", TahoeAppGroupIdentifier);
        defaults = NSUserDefaults.standardUserDefaults;
    }
    return defaults;
}

+ (NSArray<NSDictionary<NSString *, id> *> *)storedItems {
    id rawItems = [[self sharedDefaults] arrayForKey:TahoeManagedRootsFilename];
    NSArray<NSDictionary<NSString *, id> *> *items = [rawItems isKindOfClass:NSArray.class] ? rawItems : nil;
    if ((items == nil || items.count == 0) && [NSArray arrayWithContentsOfURL:[self storageFileURL]].count > 0) {
        items = [NSArray arrayWithContentsOfURL:[self storageFileURL]];
    }
    if ((items == nil || items.count == 0) && [NSFileManager.defaultManager fileExistsAtPath:[self legacyStorageFileURL].path]) {
        NSArray<NSDictionary<NSString *, id> *> *legacyItems = [NSArray arrayWithContentsOfURL:[self legacyStorageFileURL]];
        if ([legacyItems isKindOfClass:NSArray.class] && legacyItems.count > 0) {
            NSLog(@"[TahoeManagedRootsStore] Migrating %lu legacy managed root item(s) from %@", (unsigned long)legacyItems.count, [self legacyStorageFileURL].path);
            [self saveItems:legacyItems];
            items = legacyItems;
        }
    }
    if (![items isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *validItems = [NSMutableArray array];
    for (id item in items) {
        if (![item isKindOfClass:NSDictionary.class]) {
            continue;
        }

        NSString *path = item[TahoeManagedRootPathKey];
        if (![path isKindOfClass:NSString.class] || path.length == 0) {
            continue;
        }

        NSMutableDictionary<NSString *, id> *normalizedItem = [NSMutableDictionary dictionary];
        normalizedItem[TahoeManagedRootPathKey] = path;

        NSData *bookmarkData = item[TahoeManagedRootBookmarkKey];
        if ([bookmarkData isKindOfClass:NSData.class]) {
            normalizedItem[TahoeManagedRootBookmarkKey] = bookmarkData;
        }

        [validItems addObject:normalizedItem.copy];
    }
    return validItems.copy;
}

+ (void)saveItems:(NSArray<NSDictionary<NSString *, id> *> *)items {
    NSUserDefaults *defaults = [self sharedDefaults];
    [defaults setObject:items forKey:TahoeManagedRootsFilename];
    BOOL success = [defaults synchronize];
    NSLog(@"[TahoeManagedRootsStore] Saving %lu managed root item(s) to defaults suite %@ -> %@", (unsigned long)items.count, TahoeAppGroupIdentifier, success ? @"success" : @"failure");
    [items writeToURL:[self storageFileURL] atomically:YES];
}

+ (nullable NSURL *)resolvedURLForItem:(NSDictionary<NSString *, id> *)item {
    NSData *bookmarkData = item[TahoeManagedRootBookmarkKey];
    if ([bookmarkData isKindOfClass:NSData.class] && bookmarkData.length > 0) {
        BOOL stale = NO;
        NSError *error = nil;
        NSURL *resolvedURL = [NSURL URLByResolvingBookmarkData:bookmarkData
                                                       options:NSURLBookmarkResolutionWithSecurityScope | NSURLBookmarkResolutionWithoutUI
                                                 relativeToURL:nil
                                           bookmarkDataIsStale:&stale
                                                         error:&error];
        if (resolvedURL != nil) {
            return resolvedURL.URLByStandardizingPath;
        }
    }

    NSString *path = item[TahoeManagedRootPathKey];
    if ([path isKindOfClass:NSString.class] && path.length > 0) {
        return [NSURL fileURLWithPath:path isDirectory:YES].URLByStandardizingPath;
    }
    return nil;
}

+ (NSArray<NSURL *> *)managedDirectoryURLs {
    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *item in [self storedItems]) {
        NSURL *resolvedURL = [self resolvedURLForItem:item];
        if (resolvedURL != nil) {
            [urls addObject:resolvedURL];
        }
    }
    return urls.copy;
}

+ (NSArray<NSString *> *)managedDirectoryPaths {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *item in [self storedItems]) {
        NSString *path = item[TahoeManagedRootPathKey];
        if ([path isKindOfClass:NSString.class] && path.length > 0) {
            [paths addObject:path];
        }
    }
    return paths.copy;
}

+ (BOOL)addManagedDirectoryURL:(NSURL *)url error:(NSError **)error {
    NSURL *normalizedURL = url.URLByStandardizingPath;
    NSLog(@"[TahoeManagedRootsStore] Attempting to add managed directory %@", normalizedURL.path);
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:normalizedURL.path isDirectory:&isDirectory] || !isDirectory) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:NSFileNoSuchFileError
                                     userInfo:@{NSLocalizedDescriptionKey: @"请选择一个存在的目录。"}];
        }
        return NO;
    }

    NSArray<NSString *> *existingPaths = [self managedDirectoryPaths];
    if ([existingPaths containsObject:normalizedURL.path]) {
        return YES;
    }

    BOOL startedAccess = [normalizedURL startAccessingSecurityScopedResource];
    NSError *bookmarkError = nil;
    NSData *bookmarkData = [normalizedURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                                   includingResourceValuesForKeys:nil
                                                    relativeToURL:nil
                                                            error:&bookmarkError];
    if (startedAccess) {
        [normalizedURL stopAccessingSecurityScopedResource];
    }

    if (bookmarkData == nil) {
        NSLog(@"[TahoeManagedRootsStore] Failed to create bookmark for %@: %@", normalizedURL.path, bookmarkError);
        if (error != NULL) {
            *error = bookmarkError ?: [NSError errorWithDomain:NSCocoaErrorDomain
                                                          code:NSUserCancelledError
                                                      userInfo:@{NSLocalizedDescriptionKey: @"无法为该目录创建安全访问凭据。"}];
        }
        return NO;
    }
    NSLog(@"[TahoeManagedRootsStore] Created bookmark for %@ (%lu bytes)", normalizedURL.path, (unsigned long)bookmarkData.length);

    NSMutableArray<NSDictionary<NSString *, id> *> *updated = [[self storedItems] mutableCopy];
    [updated addObject:@{
        TahoeManagedRootPathKey: normalizedURL.path,
        TahoeManagedRootBookmarkKey: bookmarkData
    }];
    [self saveItems:updated.copy];
    [self postManagedRootsDidChangeNotification];
    return YES;
}

+ (nullable NSURL *)bestMatchingManagedRootURLForDirectoryPath:(NSString *)directoryPath
                                                         error:(NSError **)error {
    NSLog(@"[TahoeManagedRootsStore] Resolving managed root for %@", directoryPath);
    NSURL *bestURL = nil;
    NSUInteger bestLength = 0;

    for (NSURL *candidateURL in [self managedDirectoryURLs]) {
        NSString *rootPath = candidateURL.path ?: @"";
        BOOL exactMatch = [directoryPath isEqualToString:rootPath];
        BOOL descendantMatch = [directoryPath hasPrefix:[rootPath stringByAppendingString:@"/"]];
        if ((exactMatch || descendantMatch) && rootPath.length > bestLength) {
            bestURL = candidateURL;
            bestLength = rootPath.length;
        }
    }

    if (bestURL == nil && error != NULL) {
        NSLog(@"[TahoeManagedRootsStore] No managed root found for %@", directoryPath);
        *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                     code:NSUserCancelledError
                                 userInfo:@{NSLocalizedDescriptionKey: @"请先在宿主 App 中添加受控目录。"}];
    } else if (bestURL != nil) {
        NSLog(@"[TahoeManagedRootsStore] Matched managed root %@ for %@", bestURL.path, directoryPath);
    }
    return bestURL;
}

+ (void)removeManagedDirectoryAtPath:(NSString *)path {
    NSMutableArray<NSDictionary<NSString *, id> *> *remaining = [[self storedItems] mutableCopy];
    NSIndexSet *indexes = [remaining indexesOfObjectsPassingTest:^BOOL(NSDictionary<NSString *, id> * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        return [item[TahoeManagedRootPathKey] isEqualToString:path];
    }];
    [remaining removeObjectsAtIndexes:indexes];
    [self saveItems:remaining.copy];
    [self postManagedRootsDidChangeNotification];
}

+ (void)removeAllManagedDirectories {
    NSUserDefaults *defaults = [self sharedDefaults];
    [defaults removeObjectForKey:TahoeManagedRootsFilename];
    [defaults synchronize];
    [[NSFileManager defaultManager] removeItemAtURL:[self storageFileURL] error:nil];
    [self postManagedRootsDidChangeNotification];
}

+ (void)postManagedRootsDidChangeNotification {
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:TahoeManagedRootsDidChangeNotification
                                                                   object:nil
                                                                 userInfo:nil
                                                       deliverImmediately:YES];
}

@end
