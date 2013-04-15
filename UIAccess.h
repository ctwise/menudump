//
//  UIAccess.h
//  menudump
//
//  Created by Charles Wise on 3/3/13.
//  Copyright (c) 2013 Charles Wise. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface UIAccess : NSObject

- (NSArray *)getAppMenu:(NSRunningApplication *) pid;
- (NSString *)convertMenuToJSON:(NSArray *)menu app:(NSRunningApplication *)menuApp;
- (NSString *)convertMenuToYAML:(NSArray *)menu app:(NSRunningApplication *)menuApp;
@end
