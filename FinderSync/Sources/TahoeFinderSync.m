#import "TahoeFinderSync.h"

#import <AppKit/AppKit.h>

#import "TahoeConstants.h"
#import "TahoeFileWriter.h"
#import "TahoeManagedRootsStore.h"

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

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Tahoe New File"];
    NSError *managedRootError = nil;
    NSURL *managedRootURL = [TahoeManagedRootsStore bestMatchingManagedRootURLForDirectoryPath:targetURL.path
                                                                                         error:&managedRootError];
    BOOL enabled = (managedRootURL != nil);
    NSLog(@"[TahoeFinderSync] Directory %@ managed=%@", targetURL.path, enabled ? @"YES" : @"NO");
    if (!enabled) {
        NSLog(@"[TahoeFinderSync] Menu disabled for %@ because it is outside managed roots: %@", targetURL.path, managedRootError);
    }
    for (NSString *kindName in TahoeAllDocumentKinds()) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:TahoeLocalizedMenuTitleForKind(kindName)
                                                      action:@selector(handleCreateDocument:)
                                               keyEquivalent:@""];
        item.target = self;
        item.enabled = enabled;
        item.representedObject = @{
            @"marker": TahoeMenuItemMarker,
            @"kindName": kindName,
            @"directoryPath": targetURL.path ?: @""
        };
        [menu addItem:item];
    }
    return menu;
}

- (void)handleCreateDocument:(NSMenuItem *)sender {
    NSDictionary *payload = sender.representedObject;
    NSString *directoryPath = payload[@"directoryPath"];
    NSString *kindName = payload[@"kindName"];
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
