#import "TahoeFinderSync.h"

#import <AppKit/AppKit.h>

#import "TahoeConstants.h"
#import "TahoeFileWriter.h"
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

    BOOL startedAccess = [scopedRootURL startAccessingSecurityScopedResource];
    TahoeFileWriter *writer = [[TahoeFileWriter alloc] initWithTemplateBundle:[NSBundle bundleForClass:self.class]];
    NSDictionary<NSString *, id> *result = [writer createDocumentAtDirectoryPath:directoryPath kindName:kindName];
    if (startedAccess) {
        [scopedRootURL stopAccessingSecurityScopedResource];
    }

    if ([result[@"success"] boolValue]) {
        NSString *createdPath = result[@"createdPath"];
        if (createdPath.length > 0) {
            [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:createdPath]]];
        }
    } else {
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

@end
