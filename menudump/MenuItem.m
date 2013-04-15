//
//  MenuItem.m
//  menudump
//
//  Created by Charles Wise on 4/12/13.
//

#import "MenuItem.h"

@implementation MenuItem {
@private
    NSString *_name;
    NSArray *_children;
    NSString *_shortcut;
}

@synthesize name = _name;
@synthesize children = _children;
@synthesize shortcut = _shortcut;
@end
