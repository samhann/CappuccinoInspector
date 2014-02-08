/*
 * AppController.j
 * NewApplication
 *
 * Created by You on November 28, 2013.
 * Copyright 2013, Your Company All rights reserved.
 */

@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>
@import "Inspector.j"

@implementation AppController : CPObject
{
    CPWindow theWindow @accessors;
}

- (void)applicationDidFinishLaunching:(CPNotification)aNotification
{

    self.theWindow = [[CPWindow alloc] initWithContentRect:CGRectMakeZero() styleMask:CPBorderlessBridgeWindowMask],
        contentView = [self.theWindow contentView];

    var label = [[CPTextField alloc] initWithFrame:CGRectMakeZero()];

    [label setStringValue:@"Hello World!"];
    [label setFont:[CPFont boldSystemFontOfSize:24.0]];

    [label sizeToFit];

    [label setAutoresizingMask:CPViewMinXMargin | CPViewMaxXMargin | CPViewMinYMargin | CPViewMaxYMargin];
    [label setCenter:[contentView center]];

  //  [contentView addSubview:label];

    [self.theWindow orderFront:self];
    [self.theWindow makeKeyAndOrderFront:self];
    // Uncomment the following line to turn on the standard menu bar.
    //[CPMenu setMenuBarVisible:YES];
    [Inspector createInspectorWindowForAppController:self];

}

@end
