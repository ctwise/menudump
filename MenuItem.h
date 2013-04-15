//
//  MenuItem.h
//  menudump
//
//  Created by Charles Wise on 4/12/13.
//

#import <Foundation/Foundation.h>

@interface MenuItem : NSObject

@property(readwrite) NSString *name;
@property(readwrite) NSArray *children;
@property(readwrite) int depth;
@property(readwrite) NSString *shortcut;
@property(readwrite) NSString *locator;
@property(readwrite) NSString *path;

@end
