#import "TahoeFinderSync.h"

#import <AppKit/AppKit.h>

#import "TahoeConstants.h"
#import "TahoeManagedRootsStore.h"

@interface TahoeFinderSync ()
@property (nonatomic, copy, nullable) NSString *lastTargetDirectoryPath;
@end

@implementation TahoeFinderSync

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        [self reloadMonitoredDirectories];
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                            selector:@selector(managedRootsDidChange:)
                                                                name:TahoeManagedRootsDidChangeNotification
                                                              object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (void)managedRootsDidChange:(NSNotification *)notification {
    [self reloadMonitoredDirectories];
}

- (void)reloadMonitoredDirectories {
    NSSet<NSURL *> *roots = [NSSet setWithArray:[TahoeManagedRootsStore managedDirectoryURLs]];
    NSLog(@"[TahoeFinderSync] Reloading monitored directories: %@", roots);
    [FIFinderSyncController defaultController].directoryURLs = roots;
}

- (nullable NSMenu *)menuForMenuKind:(FIMenuKind)menuKind {
    NSLog(@"[TahoeFinderSync] menuForMenuKind=%ld", (long)menuKind);
    if (menuKind != FIMenuKindContextualMenuForContainer) {
        return nil;
    }

    NSURL *targetURL = [[FIFinderSyncController defaultController] targetedURL];
    NSLog(@"[TahoeFinderSync] targetedURL=%@", targetURL.path);
    if (targetURL == nil || !targetURL.isFileURL) {
        NSLog(@"[TahoeFinderSync] No valid target URL for container contextual menu.");
        return nil;
    }
    self.lastTargetDirectoryPath = targetURL.path;

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Tahoe New File"];
    NSError *managedRootError = nil;
    NSURL *managedRootURL = [TahoeManagedRootsStore bestMatchingManagedRootURLForDirectoryPath:targetURL.path
                                                                                         error:&managedRootError];
    BOOL enabled = (managedRootURL != nil);
    NSLog(@"[TahoeFinderSync] Directory %@ managed=%@", targetURL.path, enabled ? @"YES" : @"NO");
    if (!enabled) {
        NSLog(@"[TahoeFinderSync] Menu disabled for %@ because it is outside managed roots: %@", targetURL.path, managedRootError);
    }
    NSArray<NSString *> *documentKinds = TahoeAllDocumentKinds();
    for (NSUInteger index = 0; index < documentKinds.count; index += 1) {
        NSString *kindName = documentKinds[index];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:TahoeLocalizedMenuTitleForKind(kindName)
                                                      action:@selector(handleCreateDocument:)
                                               keyEquivalent:@""];
        item.target = self;
        item.tag = (NSInteger)index;
        item.enabled = enabled;
        [menu addItem:item];
    }
    return menu;
}

- (void)handleCreateDocument:(NSMenuItem *)sender {
    NSString *directoryPath = [self currentTargetDirectoryPath];
    NSString *kindName = [self documentKindForMenuItemTag:sender.tag];
    NSLog(@"[TahoeFinderSync] handleCreateDocument kind=%@ directory=%@", kindName, directoryPath);
    if (directoryPath.length == 0 || kindName.length == 0) {
        [self presentError:@"无法确定当前目录。"];
        return;
    }

    NSError *scopeError = nil;
    NSURL *scopedRootURL = [TahoeManagedRootsStore bestMatchingManagedRootURLForDirectoryPath:directoryPath
                                                                                         error:&scopeError];
    if (scopedRootURL == nil) {
        [self presentError:scopeError.localizedDescription ?: @"当前目录不在受控范围内。"];
        return;
    }

    NSDictionary<NSString *, id> *result = [self requestHostCreateDocumentAtDirectoryPath:directoryPath kindName:kindName];

    if ([result[@"success"] boolValue]) {
        NSString *createdPath = result[@"createdPath"];
        if (createdPath.length > 0) {
            [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:createdPath]]];
        }
    } else {
        NSLog(@"[TahoeFinderSync] Create failed for %@ in %@: %@", kindName, directoryPath, result[@"errorDescription"]);
        [self presentError:result[@"errorDescription"] ?: @"文件创建失败。"];
    }
}

- (nullable NSString *)currentTargetDirectoryPath {
    FIFinderSyncController *controller = [FIFinderSyncController defaultController];
    NSURL *targetURL = controller.targetedURL;
    if (targetURL.isFileURL && targetURL.path.length > 0) {
        return targetURL.path;
    }

    for (NSURL *selectedURL in controller.selectedItemURLs) {
        if (!selectedURL.isFileURL || selectedURL.path.length == 0) {
            continue;
        }

        NSNumber *isDirectory = nil;
        NSError *resourceError = nil;
        BOOL loaded = [selectedURL getResourceValue:&isDirectory
                                             forKey:NSURLIsDirectoryKey
                                              error:&resourceError];
        if (!loaded) {
            NSLog(@"[TahoeFinderSync] Failed to inspect selected URL %@: %@", selectedURL.path, resourceError);
            continue;
        }
        if (isDirectory.boolValue) {
            return selectedURL.path;
        }
    }

    return self.lastTargetDirectoryPath;
}

- (nullable NSString *)documentKindForMenuItemTag:(NSInteger)tag {
    NSArray<NSString *> *documentKinds = TahoeAllDocumentKinds();
    if (tag < 0 || tag >= (NSInteger)documentKinds.count) {
        return nil;
    }
    return documentKinds[(NSUInteger)tag];
}

- (void)presentError:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Tahoe New File";
        alert.informativeText = message;
        [alert addButtonWithTitle:@"好"];
        [alert runModal];
    });
}

- (NSDictionary<NSString *, id> *)requestHostCreateDocumentAtDirectoryPath:(NSString *)directoryPath
                                                                  kindName:(NSString *)kindName {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:TahoeAppGroupIdentifier];
    if (defaults == nil) {
        return @{
            @"success": @NO,
            @"errorDescription": @"无法访问共享容器。"
        };
    }

    [self ensureHostApplicationRunning];

    NSString *requestID = NSUUID.UUID.UUIDString;
    NSString *requestKey = [TahoeCreateRequestDefaultsKeyPrefix stringByAppendingString:requestID];
    NSString *responseKey = [TahoeCreateResponseDefaultsKeyPrefix stringByAppendingString:requestID];
    NSDictionary<NSString *, id> *payload = @{
        TahoeRequestIdentifierKey: requestID,
        TahoeRequestDirectoryPathKey: directoryPath,
        TahoeRequestKindKey: kindName
    };

    [defaults removeObjectForKey:responseKey];
    [defaults setObject:payload forKey:requestKey];
    [defaults synchronize];

    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:TahoeCreateRequestNotification
                                                                   object:nil
                                                                 userInfo:@{ TahoeRequestIdentifierKey: requestID }
                                                       deliverImmediately:YES];

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:8.0];
    NSDictionary<NSString *, id> *response = nil;
    while ([deadline timeIntervalSinceNow] > 0) {
        response = [defaults dictionaryForKey:responseKey];
        if ([response isKindOfClass:NSDictionary.class]) {
            break;
        }
        [NSThread sleepForTimeInterval:0.1];
    }

    [defaults removeObjectForKey:requestKey];
    [defaults removeObjectForKey:responseKey];
    [defaults synchronize];

    if ([response isKindOfClass:NSDictionary.class]) {
        return response;
    }

    NSLog(@"[TahoeFinderSync] Timed out waiting for host response requestID=%@", requestID);
    return @{
        @"success": @NO,
        @"errorDescription": @"宿主服务未响应，请打开 Tahoe New File Host 后重试。"
    };
}

- (void)ensureHostApplicationRunning {
    if ([NSRunningApplication runningApplicationsWithBundleIdentifier:TahoeHostBundleIdentifier].count > 0) {
        return;
    }

    NSURL *hostURL = [self hostApplicationURL];
    if (hostURL == nil) {
        NSLog(@"[TahoeFinderSync] Failed to locate host application bundle.");
        return;
    }

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
    configuration.activates = NO;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:hostURL
                                        configuration:configuration
                                    completionHandler:^(__unused NSRunningApplication * _Nullable app, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"[TahoeFinderSync] Failed to launch host app: %@", error);
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)));
}

- (nullable NSURL *)hostApplicationURL {
    NSURL *bundleURL = [NSBundle bundleForClass:self.class].bundleURL;
    if (bundleURL == nil) {
        return nil;
    }

    NSURL *appURL = bundleURL;
    for (NSUInteger index = 0; index < 3; index += 1) {
        appURL = [appURL URLByDeletingLastPathComponent];
    }
    return appURL;
}

@end
