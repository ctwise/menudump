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
@property(readwrite) NSString *shortcut;

@end
