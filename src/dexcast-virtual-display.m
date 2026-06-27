#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface NSObject (CGVirtualDisplayPrivate)
- (void)setQueue:(dispatch_queue_t)queue;
- (void)setName:(NSString *)name;
- (void)setSizeInMillimeters:(CGSize)size;
- (void)setMaxPixelsWide:(unsigned int)w;
- (void)setMaxPixelsHigh:(unsigned int)h;
- (id)initWithDescriptor:(id)descriptor;
- (BOOL)applySettings:(id)settings;
- (unsigned int)displayID;
- (void)setModes:(NSArray *)modes;
- (id)initWithWidth:(double)w height:(double)h refreshRate:(double)r;
@end

static id g_virtualDisplay = nil;

unsigned int create_virtual_display(void) {
    if (g_virtualDisplay != nil) {
        return (unsigned int)[g_virtualDisplay displayID];
    }
    
    Class descClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
    Class displayClass = NSClassFromString(@"CGVirtualDisplay");
    Class modeClass = NSClassFromString(@"CGVirtualDisplayMode");
    Class settingsClass = NSClassFromString(@"CGVirtualDisplaySettings");
    
    if (!descClass || !displayClass || !modeClass || !settingsClass) {
        return 0;
    }
    
    id descriptor = [[descClass alloc] init];
    [descriptor setQueue:dispatch_get_main_queue()];
    [descriptor setName:@"DexCast TV"];
    [descriptor setSizeInMillimeters:CGSizeMake(320, 200)];
    [descriptor setMaxPixelsWide:1920];
    [descriptor setMaxPixelsHigh:1080];
    
    id display = [[displayClass alloc] initWithDescriptor:descriptor];
    if (!display) {
        return 0;
    }
    
    id mode = [[modeClass alloc] initWithWidth:1920.0 height:1080.0 refreshRate:60.0];
    id settings = [[settingsClass alloc] init];
    [settings setModes:@[mode]];
    
    if (![display applySettings:settings]) {
        return 0;
    }
    
    g_virtualDisplay = display;
    return (unsigned int)[display displayID];
}

void destroy_virtual_display(void) {
    if (g_virtualDisplay != nil) {
        g_virtualDisplay = nil;
    }
}
