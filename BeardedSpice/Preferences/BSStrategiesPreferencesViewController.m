//
//  BSStrategiesPreferencesViewController.m
//  BeardedSpice
//
//  Created by Roman Sokolov on 22.05.17.
//  Copyright (c) 2017 GPL v3 http://www.gnu.org/licenses/gpl.html
//

#import "BSStrategiesPreferencesViewController.h"
#import "MediaStrategyRegistry.h"
#import "NativeAppTabsRegistry.h"
#import "MediaControllerObject.h"
#import "BSMediaStrategyEnableButton.h"
#import "BSMediaStrategy.h"
#import "BSStrategyCache.h"
#import "BSStrategyVersionManager.h"
#import "EHVerticalCenteredTextField.h"
#import "BSCustomStrategyManager.h"
#import "AppDelegate.h"


NSString *const BSStrategiesPreferencesNativeAppChangedNoticiation = @"BSStrategiesPreferencesNativeAppChangedNoticiation";
NSString *const BeardedSpiceActiveControllers = @"BeardedSpiceActiveControllers";
NSString *const BeardedSpiceActiveNativeAppControllers = @"BeardedSpiceActiveNativeAppControllers";
NSString *const BeardedSpiceImportExportLastDirectory = @"BeardedSpiceImportExportLastDirectory";

@interface BSStrategiesPreferencesViewController ()

@property BOOL selectedRowAllowExport;
@property BOOL selectedRowAllowRemove;
@property BOOL importExportPanelOpened;

@end

@implementation BSStrategiesPreferencesViewController

- (id)init{
    
    self = [super initWithNibName:@"BSStrategiesPreferencesViewController" bundle:nil];
    if (self) {
        
        _toolTipForCustomStrategy = BSLocalizedString(
                                                      @"This strategy is user custom defined.",
                                                      @"(GeneralPreferencesViewController) In preferences, strategies "
                                                      @"list. ToolTip for row, which meens that this strategy is user "
                                                      @"defined.");
        
        self.importExportPanelOpened = self.selectedRowAllowExport = self.selectedRowAllowRemove = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(strategyChangedNotify:) name: BSVMStrategyChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(strategyChangedNotify:) name: BSCStrategyChangedNotification object:nil];
        [self loadMediaControllerObjects];
    }
    return self;
}

- (void)dealloc{
    
}

- (NSString *)viewIdentifier
{
    return @"BSStrategiesPreferencesViewController";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:NSImageNameAdvanced];
}

- (NSString *)toolbarItemLabel
{
    return BSLocalizedString(@"Controllers", @"Toolbar item name for the Media Controllers preference pane");
}

- (NSView *)initialKeyView{
    
    return self.firstResponderView;
}

/////////////////////////////////////////////////////////////////////////
#pragma mark Actions
/////////////////////////////////////////////////////////////////////////

- (IBAction)clickExport:(id)sender {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        @autoreleasepool {
            
            BSMediaStrategy *strategy = [self strategyFromTableSelection];
            if (strategy) {
                
                self.importExportPanelOpened = YES;
                
                NSOpenPanel *openPanel = [NSOpenPanel openPanel];
                
                openPanel.directoryURL =
                [self importExportDirectoryForCustomStrategy];
                openPanel.allowedFileTypes = nil;
                openPanel.allowsOtherFileTypes = NO;
                openPanel.canChooseFiles = NO;
                openPanel.canChooseDirectories = YES;
                openPanel.canCreateDirectories = YES;
                openPanel.allowsMultipleSelection = NO;
                openPanel.title = BSLocalizedString(
                                                    @"BeardedSpice - Choose a folder for exporting",
                                                    @"(GeneralPreferencesViewController) In "
                                                    @"preferences, strategies list. Title of the "
                                                    @"panel for choosing of the export folder.");
                openPanel.prompt = BSLocalizedString(
                                                     @"Export", @"(GeneralPreferencesViewController) In "
                                                     @"preferences, strategies list. 'Choose folder for "
                                                     @"exporting' panel. Export button title.");
                
                [openPanel beginWithCompletionHandler:^(NSInteger result) {
                    
                    if (result == NSModalResponseOK) {
                        
                        // export to file
                        NSURL *fileURL = openPanel.URL;
                        [[NSUserDefaults standardUserDefaults]
                         setObject:[fileURL path]
                         forKey:BeardedSpiceImportExportLastDirectory];
                        
                        [[BSCustomStrategyManager singleton] exportStrategy:strategy
                                                                   toFolder:fileURL];
                    }
                    
                    self.importExportPanelOpened = NO;
                }];
            }
        }
    });
}

- (IBAction)clickImport:(id)sender {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        @autoreleasepool {
            
            self.importExportPanelOpened = YES;
            NSOpenPanel *openPanel = [NSOpenPanel openPanel];
            
            openPanel.directoryURL =
            [self importExportDirectoryForCustomStrategy];
            openPanel.allowedFileTypes = @[ @"js", BS_STRATEGY_EXTENSION ];
            openPanel.allowsOtherFileTypes = NO;
            openPanel.canChooseFiles = YES;
            openPanel.canChooseDirectories = NO;
            openPanel.canCreateDirectories = NO;
            openPanel.allowsMultipleSelection = NO;
            openPanel.title =
            BSLocalizedString(@"BeardedSpice - Choose a file for importing",
                              @"(GeneralPreferencesViewController) In "
                              @"preferences, strategies list. Title of the "
                              @"panel for choosing of the importing file.");
            openPanel.prompt = BSLocalizedString(
                                                 @"Import", @"(GeneralPreferencesViewController) In "
                                                 @"preferences, strategies list. 'Choose folder for "
                                                 @"importing' panel. Import button title.");
            
            [openPanel  beginWithCompletionHandler:^(NSInteger result) {
                
                if (result == NSModalResponseOK) {
                    
                    NSURL *fileURL = openPanel.URL;
                    [[NSUserDefaults standardUserDefaults]
                     setObject:[openPanel.directoryURL path]
                     forKey:BeardedSpiceImportExportLastDirectory];
                    
                    [[BSCustomStrategyManager singleton] importFromUrl:fileURL];
                    
                }
                self.importExportPanelOpened = NO;
            }];
        }
    });
}

- (IBAction)clickRemove:(id)sender {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        @autoreleasepool {
            
            BSMediaStrategy *strategy = [self strategyFromTableSelection];
            if (strategy) {
                
                NSAlert *alert = [NSAlert new];
                alert.alertStyle = NSAlertStyleInformational;
                alert.informativeText = strategy.description;
                alert.messageText = [NSString
                                     stringWithFormat:
                                     BSLocalizedString(
                                                       @"Are you realy want remove \"%@\" strategy?",
                                                       @"(GeneralPreferencesViewController) In preferences, "
                                                       @"strategies list."
                                                       @"Title of the question about remove."),
                                     strategy.displayName];
                [alert addButtonWithTitle:BSLocalizedString(@"Cancel",
                                                            @"Cancel button")];
                [alert addButtonWithTitle:BSLocalizedString(@"Remove",
                                                            @"Remove button")];
                
                [APPDELEGATE windowWillBeVisible:alert];
                
                if ([alert runModal] == NSAlertSecondButtonReturn) {
                    [[BSCustomStrategyManager singleton] removeStrategy:strategy];
                };
                
                [APPDELEGATE removeWindow:alert];
            }
        }
    });
}

/////////////////////////////////////////////////////////////////////////
#pragma mark Private Methods
/////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return mediaControllerObjects.count;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row{
    
    return [mediaControllerObjects[row] isGroup];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)row{
    
    return ![mediaControllerObjects[row] isGroup];
    
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row{
    
    return ([mediaControllerObjects[row] isGroup] ? 18.0 : 25.0);
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    
    MediaControllerObject *obj = mediaControllerObjects[row];
    
    // Create group
    if (obj.isGroup) {
        
        NSTextField *result = [tableView makeViewWithIdentifier:@"GroupView" owner:self];
        
        // there is no existing cell to reuse so create a new one
        if (result == nil) {
            result = [NSTextField new];
            
            // this allows the cell to be reused.
            result.identifier = @"GroupView";
            result.alignment = NSTextAlignmentCenter;
            result.selectable = NO;
            result.editable = NO;
            result.bordered = NO;
            result.bezeled = NO;
            result.refusesFirstResponder = YES;
            result.backgroundColor = [NSColor colorWithCalibratedWhite:1 alpha:0.4];
            result.textColor = [NSColor headerColor];
            result.font = [NSFont boldSystemFontOfSize:12];
        }
        
        [result setStringValue:obj.name];
        return result;
    }
    
    //
    NSString *ident = [tableColumn identifier];
    if ([ident isEqualToString:@"check"]) {
        
        return [self tableView:tableView checkViewForObject:obj];
    }
    else if ([ident isEqualToString:@"name"]){
        
        return [self tableView:tableView nameViewForObject:obj];
    }
    else if ([ident isEqualToString:@"smartIndicator"]){
        
        return [self tableView:tableView indicatorViewForObject:obj];
    }
    
    return nil;
}

- (NSView *)tableView:(NSTableView *)tableView checkViewForObject:(MediaControllerObject *)obj{
    
    BSMediaStrategyEnableButton* result = [[BSMediaStrategyEnableButton alloc] initWithTableView:tableView];
    
    // make it a checkbox
    [result setButtonType:NSButtonTypeSwitch];
    //        result.refusesFirstResponder = YES;
    
    // check the user defaults
    
    NSNumber *enabled;
    if ([obj.representationObject isKindOfClass:[BSMediaStrategy class]]) {
        enabled = userStrategies[obj.name];
    }
    else{
        enabled = userNativeApps[obj.name];
    }
    if (!enabled || [enabled boolValue]) {
        [result setState:NSControlStateValueOn];
    } else {
        [result setState:NSControlStateValueOff];
    }
    
    //    [result setTitle:@""];
    [result setTarget:self];
    [result setAction:@selector(updateMediaStrategyRegistry:)];
    return result;
}

- (NSView *)tableView:(NSTableView *)tableView nameViewForObject:(MediaControllerObject *)obj{
    
    EHVerticalCenteredTextField *result = [EHVerticalCenteredTextField new];
    result.selectable = result.editable = result.drawsBackground = result.bordered = NO;
    
    NSMutableAttributedString *name = [[NSMutableAttributedString alloc]
                                       initWithString:obj.name
                                       attributes:@{
                                                    NSFontAttributeName :
                                                        [NSFont systemFontOfSize:[NSFont systemFontSize]]
                                                    }];
    if (![NSString isNullOrEmpty:obj.version]) {
        NSString *vString = [NSString
                             stringWithFormat:BSLocalizedString(@"  v.%@",
                                                                @"(GeneralPreferencesViewController) In preferences, strategies list."
                                                                @" Output format for name column "
                                                                @"of the strategy list."),
                             obj.version];
        NSAttributedString *version = [[NSAttributedString alloc]
                                       initWithString:vString
                                       attributes:@{
                                                    NSFontAttributeName :
                                                        [NSFont systemFontOfSize:[NSFont labelFontSize]],
                                                    NSForegroundColorAttributeName : [NSColor grayColor]
                                                    }];
        [name appendAttributedString:version];
    }
    result.attributedStringValue = name;
    
    if (obj.isCustom) {
        result.toolTip = _toolTipForCustomStrategy;
    }
    
    return result;
}

- (NSView *)tableView:(NSTableView *)tableView indicatorViewForObject:(MediaControllerObject *)obj{
    
    NSImageView* result = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 20, 20)];
    
    result.imageScaling = NSImageScaleNone;
    
    if (obj.isCustom){
        result.image = [NSImage imageNamed:@"custom"];
        result.toolTip = _toolTipForCustomStrategy;
    }
    
    return result;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification{
    
    NSTableView *tableView = notification.object;
    
    if (tableView) {
        
        self.selectedRowAllowExport = self.selectedRowAllowRemove = NO;
        
        NSInteger index = [tableView selectedRow];
        if (index < 0) {
            return;
        }
        
        MediaControllerObject *obj = mediaControllerObjects[index];
        if ([obj.representationObject isKindOfClass:[BSMediaStrategy class]]) {
            
            self.selectedRowAllowExport = YES;
            if (obj.isCustom) {
                self.selectedRowAllowRemove = YES;
            }
        }
        
        [self.view.window recalculateKeyViewLoop];
    }
}

- (void)updateMediaStrategyRegistry:(id)sender {
    
    NSInteger index = [self.strategiesView rowForView:sender];
    if (index < 0) {
        return;
    }
    
    MediaControllerObject *obj = mediaControllerObjects[index];
    if (!obj || obj.isGroup) {
        return;
    }
    
    BOOL enabled;
    if ([sender state] == NSControlStateValueOn) {
        enabled = YES;
    } else {
        enabled = NO;
    }
    
    if ([obj.representationObject isKindOfClass:[BSMediaStrategy class]]) {
        // Strategy
        if (enabled) {
            [[MediaStrategyRegistry singleton] addAvailableMediaStrategy:obj.representationObject];
        } else {
            [[MediaStrategyRegistry singleton] removeAvailableMediaStrategy:obj.representationObject];
        }
        // save user strategies
        [userStrategies setObject:@(enabled) forKey:obj.name];
        [[NSUserDefaults standardUserDefaults]
         setObject:userStrategies
         forKey:BeardedSpiceActiveControllers];
    } else {
        // Native
        if (enabled) {
            [[NativeAppTabsRegistry singleton] enableNativeAppClass:obj.representationObject];
        } else {
            [[NativeAppTabsRegistry singleton] disableNativeAppClass:obj.representationObject];
        }
        // save user strategies
        [userNativeApps setObject:@(enabled) forKey:obj.name];
        [[NSUserDefaults standardUserDefaults]
         setObject:userNativeApps
         forKey:BeardedSpiceActiveNativeAppControllers];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
             postNotificationName:BSStrategiesPreferencesNativeAppChangedNoticiation
             object:self];
        });
    }
}

- (void)loadMediaControllerObjects{
    
    NSMutableArray *mediaControllers = [NSMutableArray array];
    
    NSArray *theArray = [NativeAppTabsRegistry defaultNativeAppClasses];
    if (theArray.count) {
        
        MediaControllerObject *obj = [MediaControllerObject new];
        obj.isGroup = YES;
        obj.name = BSLocalizedString(@"Native", @"General preferences - controllers table");
        [mediaControllers addObject:obj];
        for (Class theClass in theArray) {
            [mediaControllers addObject:[[MediaControllerObject alloc] initWithObject:theClass]];
        }
        
        userNativeApps = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:BeardedSpiceActiveNativeAppControllers]];
    }
    
    BSStrategyCache *cache = [[MediaStrategyRegistry singleton] strategyCache];
    theArray = [[cache allStrategies] sortedArrayUsingSelector:@selector(compare:)];
    if (theArray.count) {
        MediaControllerObject *obj = [MediaControllerObject new];
        obj.isGroup = YES;
        obj.name = BSLocalizedString(@"Web", @"General preferences - controllers table");
        [mediaControllers addObject:obj];
        for (BSMediaStrategy *strategy in theArray) {
            [mediaControllers addObject:[[MediaControllerObject alloc] initWithObject:strategy]];
        }
        userStrategies = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:BeardedSpiceActiveControllers]];
    }
    mediaControllerObjects = [mediaControllers copy];
}

- (void)strategyChangedNotify:(NSNotification*) notification{
    
    [self loadMediaControllerObjects];
    [self.strategiesView reloadData];
}

- (NSURL *)importExportDirectoryForCustomStrategy {
    
    NSURL *directoryURL;
    NSString *path = [[NSUserDefaults standardUserDefaults]
                      stringForKey:BeardedSpiceImportExportLastDirectory];
    if (path) {
        
        directoryURL = [NSURL URLWithString:path];
    } else {
        
        directoryURL =
        [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                               inDomain:NSLocalDomainMask
                                      appropriateForURL:nil
                                                 create:NO
                                                  error:nil];
        [[NSUserDefaults standardUserDefaults]
         setObject:[directoryURL path]
         forKey:BeardedSpiceImportExportLastDirectory];
    }
    
    return directoryURL;
}

- (BSMediaStrategy *)strategyFromTableSelection{
    
    NSInteger index = [self.strategiesView selectedRow];
    if (index < 0 || mediaControllerObjects.count <= index) {
        return nil;
    }
    
    MediaControllerObject *obj = mediaControllerObjects[index];
    if ([obj.representationObject isKindOfClass:[BSMediaStrategy class]]) {
        
        return obj.representationObject;
    }
    
    return nil;
}

@end
