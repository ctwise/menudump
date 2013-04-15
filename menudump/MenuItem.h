//
//  MenuItem.h
//  menudump
//
//  Created by Charles Wise on 4/12/13.
//

#import <Foundation/Foundation.h>

@interface MenuItem : NSObject

@property (retain) NSString *name;
@property (retain) NSArray *children;
@property (retain) NSString *shortcut;

@end
