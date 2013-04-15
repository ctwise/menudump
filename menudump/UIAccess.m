//
//  UIAccess.m
//  menudump
//
//  Created by Charles Wise on 3/3/13.
//

#import "UIAccess.h"
#import "MenuItem.h"

@implementation UIAccess

id getAttribute(AXUIElementRef element, CFStringRef attribute) {
    CFTypeRef value = nil;
    if (AXUIElementCopyAttributeValue(element, attribute, &value) != kAXErrorSuccess) return nil;
    if (AXValueGetType((AXValueRef) value) == kAXValueAXErrorType) return nil;
    return value;
}

long getLongAttribute(AXUIElementRef element, CFStringRef attribute) {
    CFNumberRef valueRef = (CFNumberRef) getAttribute(element, attribute);
    long result = 0;
    if (valueRef) {
        CFNumberGetValue(valueRef, kCFNumberLongType, &result);
    }
    return result;
}

NSString *decodeKeyMask(long cmdModifiers) {
    NSString *result = @"";
    if (cmdModifiers == 0x18) {
        result = @"fn fn";
    } else {
        if (cmdModifiers & 0x04) {
            result = [result stringByAppendingString:@"⌃"];
        }
        if (cmdModifiers & 0x02) {
            result = [result stringByAppendingString:@"⌥"];
        }
        if (cmdModifiers & 0x01) {
            result = [result stringByAppendingString:@"⇧"];
        }
        if (!(cmdModifiers & 0x08)) {
            result = [result stringByAppendingString:@"⌘"];
        }
    }
    return result;
}

NSString *getMenuItemShortcut(AXUIElementRef element, NSDictionary *virtualKeys) {
    NSString *result = nil;

    NSString *cmdChar = getAttribute(element, kAXMenuItemCmdCharAttribute);
    NSString *base = cmdChar;
    long cmdModifiers = getLongAttribute(element, kAXMenuItemCmdModifiersAttribute);
    long cmdVirtualKey = getLongAttribute(element, kAXMenuItemCmdVirtualKeyAttribute);

    if (base) {
        if ([base characterAtIndex:0] == 0x7f) {
            base = @"⌦";
        }
    } else if (cmdVirtualKey > 0) {
        NSString *virtualLookup = [virtualKeys objectForKey:[NSNumber numberWithLong:cmdVirtualKey]];
        if (virtualLookup) {
            base = virtualLookup;
        }
    }
//    NSString *cmdGlyph = (NSString *) getAttribute(element, kAXMenuItemCmdGlyphAttribute);
//    NSString *cmdMark = (NSString *) getAttribute(element, kAXMenuItemMarkCharAttribute);
    NSString *modifiers = decodeKeyMask(cmdModifiers);
    if (base) {
        result = [modifiers stringByAppendingString:base];
    }
    return result;
}

bool __unused isEnabled(AXUIElementRef element) {
    CFTypeRef enabled = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXEnabledAttribute, &enabled) != kAXErrorSuccess) return false;
    return CFBooleanGetValue(enabled);
}

bool shouldSkip(NSString * bundleIdentifier, NSInteger depth, NSString * name) {
    // Skip the top-level Apple menu
    if (depth == 0 && [name isEqualToString:@"Apple"]) {
        return true;
    }

    // Skip the Services menu
    if (depth == 2 && [name isEqualToString:@"Services"]) {
        return true;
    }

    if (depth == 0 && [bundleIdentifier isEqualToString:@"com.apple.Safari"]) {
        // These two menus are time-sucks in Safari
        if ([name isEqualToString:@"History"] || [name isEqualToString:@"Bookmarks"]) {
            return true;
        }
    }

    return false;
}

NSArray *menuItemsForElement(NSString *bundleIdentifier, AXUIElementRef element, NSInteger depth, NSInteger maxDepth, NSDictionary *virtualKeys) {
    NSArray *children = nil;
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute, (CFTypeRef *) &children);

    NSMutableArray *menuItems = [NSMutableArray array];
    for (id child in children) {
        // We don't have focus, so we can't use this.
        // if (!isEnabled((AXUIElementRef) child)) continue;

        NSString *name = getAttribute((AXUIElementRef) child, kAXTitleAttribute);

        if (shouldSkip(bundleIdentifier, depth, name)) {
            continue;
        }

        NSArray *mChildren = nil;
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute, (CFTypeRef *) &mChildren);
        NSUInteger mChildrenCount = [mChildren count];

        MenuItem *menuItem = [[[MenuItem alloc] init] autorelease];
        menuItem.name = name;

        // Don't recurse further if a menu entry has too many children or we've hit max depth
        if (mChildrenCount > 0 || mChildrenCount < 40 || depth < maxDepth) {
            menuItem.children = menuItemsForElement(bundleIdentifier, (AXUIElementRef) child, depth + 1, maxDepth, virtualKeys);
        }

        if (name && [name length] > 0) {
            menuItem.shortcut = getMenuItemShortcut((AXUIElementRef) child, virtualKeys);

            [menuItems addObject:menuItem];
        } else {
            // This isn't a menu item, skip below it and get its children
            [menuItems addObjectsFromArray:menuItem.children];
        }
    }

    return menuItems;
}

NSString *escape(NSString *text) {
    NSString *result = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    result = [result stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    return result;
}

NSString *padding(int length) {
    NSMutableString *padding = [NSMutableString stringWithString:@""];
    for (int i = 0; i < length; i++) {
        [padding appendString:@" "];
    }
    return padding;
}

NSString *buildLocator(MenuItem *item, NSArray *parents) {
    bool needLocator = parents && [parents count] > 0;
    NSArray *children = item.children;
    needLocator = needLocator && (!children || [children count] == 0);
    if (needLocator) {
        NSString *name = item.name;
        NSString *menuItem = [NSString stringWithFormat:@"menu item \"%@\"", name];
        NSMutableString *buffer = [NSMutableString stringWithString:menuItem];

        unsigned long pathCount = [parents count];
        for (NSString *parent in [parents reverseObjectEnumerator]) {
            NSString *menuType = @"menu bar item";
            if (pathCount > 1) {
                menuType = @"menu item";
            }
            NSString *menu = [NSString stringWithFormat:@" of menu \"%@\" of %@ \"%@\"", parent, menuType, parent];
            [buffer appendString:menu];
            pathCount--;
        }

        [buffer appendString:@" of menu bar 1"];

        return buffer;
    } else {
        return [NSMutableString stringWithString:@""];
    }
}

NSString *buildMenuPath(NSArray *parents) {
    if (!parents || [parents count] == 0) {
        return [NSMutableString stringWithString:@""];
    } else {
        NSMutableString *buffer = [NSMutableString stringWithString:@""];

        for (NSString *parent in parents) {
            if ([buffer length] > 0) {
                [buffer appendString:@" > "];
            }
            [buffer appendString:parent];
        }

        return buffer;
    }
}

NSString *menuToJSON(NSArray *menu, int depth, NSArray *parents) {
    NSMutableString *buffer = [NSMutableString stringWithString:@""];
    NSString *offset = padding(depth * 2);
    NSString *offset2 = padding((depth + 1) * 2);
    NSString *offset3 = padding((depth + 2) * 2);
    if (depth > 0) {
        [buffer appendString:@" "];
    }
    [buffer appendString:@"[\n"];
    for (MenuItem *item in menu) {
        [buffer appendString:offset2];
        [buffer appendString:@"{\n"];

        NSString *shortcut = item.shortcut;
        if (!shortcut) {
            shortcut = @"";
        }
        [buffer appendString:offset3];
        [buffer appendString:[NSString stringWithFormat:@"\"name\": \"%@\",\n", escape(item.name)]];
        [buffer appendString:offset3];
        [buffer appendString:[NSString stringWithFormat:@"\"shortcut\": \"%@\",\n", escape(shortcut)]];

        NSString *children = @"[]";
        if (item.children && ([item.children count] > 0)) {
            NSArray *childParents = [NSArray arrayWithArray:parents];
            childParents = [childParents arrayByAddingObject:item.name];
            children = menuToJSON(item.children, depth + 2, childParents);
        }

        [buffer appendString:offset3];
        [buffer appendString:[NSString stringWithFormat:@"\"locator\": \"%@\",\n", escape(buildLocator(item, parents))]];
        [buffer appendString:offset3];
        [buffer appendString:[NSString stringWithFormat:@"\"menuPath\": \"%@\",\n", escape(buildMenuPath(parents))]];
        [buffer appendString:offset3];
        [buffer appendString:[NSString stringWithFormat:@"\"children\": %@\n", children]];

        [buffer appendString:offset2];
        [buffer appendString:@"},\n"];
    }
    [buffer appendString:offset];
    [buffer appendString:@"]\n"];

    return buffer;
}

NSString *menuToYAML(NSArray *menu, int startingOffset, NSArray *parents) {
    NSMutableString *buffer = [NSMutableString stringWithString:@""];
    NSString *offset = padding(startingOffset + 4);
    NSString *offset2 = padding(startingOffset + 6);
    for (MenuItem *item in menu) {
        [buffer appendString:offset];
        [buffer appendString:@"- "];
        NSString *shortcut = item.shortcut;
        if (!shortcut) {
            shortcut = @"";
        }
        [buffer appendString:[NSString stringWithFormat:@"name: \"%@\"\n", escape(item.name)]];
        [buffer appendString:offset2];
        [buffer appendString:[NSString stringWithFormat:@"shortcut: \"%@\"\n", escape(shortcut)]];

        NSString *children = @"";
        if (item.children && ([item.children count] > 0)) {
            NSArray *childParents = [NSArray arrayWithArray:parents];
            childParents = [childParents arrayByAddingObject:item.name];
            children = menuToYAML(item.children, startingOffset + 6, childParents);
        }

        [buffer appendString:offset2];
        [buffer appendString:[NSString stringWithFormat:@"locator: \"%@\"\n", escape(buildLocator(item, parents))]];
        [buffer appendString:offset2];
        [buffer appendString:[NSString stringWithFormat:@"menuPath: \"%@\"\n", escape(buildMenuPath(parents))]];
        if ([children length] > 0) {
            [buffer appendString:offset2];
            [buffer appendString:[NSString stringWithFormat:@"children:\n%@", children]];
        }
    }

    return buffer;
}

NSMutableDictionary * buildVirtualKeyDictionary() {
    NSMutableDictionary *virtualKeys = [NSMutableDictionary dictionary];

    [virtualKeys setObject:@"↩" forKey:[NSNumber numberWithLong:0x24]]; // kVK_Return
    [virtualKeys setObject:@"⌤" forKey:[NSNumber numberWithLong:0x4C]]; // kVK_ANSI_KeypadEnter
    [virtualKeys setObject:@"⌧" forKey:[NSNumber numberWithLong:0x47]]; // kVK_ANSI_KeypadClear
    [virtualKeys setObject:@"⇥" forKey:[NSNumber numberWithLong:0x30]]; // kVK_Tab
    [virtualKeys setObject:@"␣" forKey:[NSNumber numberWithLong:0x31]]; // kVK_Space
    [virtualKeys setObject:@"⌫" forKey:[NSNumber numberWithLong:0x33]]; // kVK_Delete
    [virtualKeys setObject:@"⎋" forKey:[NSNumber numberWithLong:0x35]]; // kVK_Escape
    [virtualKeys setObject:@"⇪" forKey:[NSNumber numberWithLong:0x39]]; // kVK_CapsLock
    [virtualKeys setObject:@"fn" forKey:[NSNumber numberWithLong:0x3F]]; // kVK_Function
    [virtualKeys setObject:@"F1" forKey:[NSNumber numberWithLong:0x7A]]; // kVK_F1
    [virtualKeys setObject:@"F2" forKey:[NSNumber numberWithLong:0x78]]; // kVK_F2
    [virtualKeys setObject:@"F3" forKey:[NSNumber numberWithLong:0x63]]; // kVK_F3
    [virtualKeys setObject:@"F4" forKey:[NSNumber numberWithLong:0x76]]; // kVK_F4
    [virtualKeys setObject:@"F5" forKey:[NSNumber numberWithLong:0x60]]; // kVK_F5
    [virtualKeys setObject:@"F6" forKey:[NSNumber numberWithLong:0x61]]; // kVK_F6
    [virtualKeys setObject:@"F7" forKey:[NSNumber numberWithLong:0x62]]; // kVK_F7
    [virtualKeys setObject:@"F8" forKey:[NSNumber numberWithLong:0x64]]; // kVK_F8
    [virtualKeys setObject:@"F9" forKey:[NSNumber numberWithLong:0x65]]; // kVK_F9
    [virtualKeys setObject:@"F10" forKey:[NSNumber numberWithLong:0x6D]]; // kVK_F10
    [virtualKeys setObject:@"F11" forKey:[NSNumber numberWithLong:0x67]]; // kVK_F11
    [virtualKeys setObject:@"F12" forKey:[NSNumber numberWithLong:0x6F]]; // kVK_F12
    [virtualKeys setObject:@"F13" forKey:[NSNumber numberWithLong:0x69]]; // kVK_F13
    [virtualKeys setObject:@"F14" forKey:[NSNumber numberWithLong:0x6B]]; // kVK_F14
    [virtualKeys setObject:@"F15" forKey:[NSNumber numberWithLong:0x71]]; // kVK_F15
    [virtualKeys setObject:@"F16" forKey:[NSNumber numberWithLong:0x6A]]; // kVK_F16
    [virtualKeys setObject:@"F17" forKey:[NSNumber numberWithLong:0x40]]; // kVK_F17
    [virtualKeys setObject:@"F18" forKey:[NSNumber numberWithLong:0x4F]]; // kVK_F18
    [virtualKeys setObject:@"F19" forKey:[NSNumber numberWithLong:0x50]]; // kVK_F19
    [virtualKeys setObject:@"F20" forKey:[NSNumber numberWithLong:0x5A]]; // kVK_F20
    [virtualKeys setObject:@"↖" forKey:[NSNumber numberWithLong:0x73]]; // kVK_Home
    [virtualKeys setObject:@"⇞" forKey:[NSNumber numberWithLong:0x74]]; // kVK_PageUp
    [virtualKeys setObject:@"⌦" forKey:[NSNumber numberWithLong:0x75]]; // kVK_ForwardDelete
    [virtualKeys setObject:@"↘" forKey:[NSNumber numberWithLong:0x77]]; // kVK_End
    [virtualKeys setObject:@"⇟" forKey:[NSNumber numberWithLong:0x79]]; // kVK_PageDown
    [virtualKeys setObject:@"←" forKey:[NSNumber numberWithLong:0x7B]]; // kVK_LeftArrow
    [virtualKeys setObject:@"→" forKey:[NSNumber numberWithLong:0x7C]]; // kVK_RightArrow
    [virtualKeys setObject:@"↓" forKey:[NSNumber numberWithLong:0x7D]]; // kVK_DownArrow
    [virtualKeys setObject:@"↑" forKey:[NSNumber numberWithLong:0x7E]]; // kVK_UpArrow

    return virtualKeys;
}

- (NSArray *)getAppMenu:(NSRunningApplication *)menuApp {
    AXUIElementRef app = AXUIElementCreateApplication(menuApp.processIdentifier);
    AXUIElementRef menuBar;
    AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute, (CFTypeRef *) &menuBar);

    return menuItemsForElement(menuApp.bundleIdentifier, menuBar, 0, 5, buildVirtualKeyDictionary());
}

- (NSString *)convertMenuToJSON:(NSArray *)menu app:(NSRunningApplication *)menuApp {
    NSMutableString *buffer = [NSMutableString stringWithString:@"{\n"];
    [buffer appendString:@"  \"name\": \""];
    [buffer appendString:menuApp.localizedName];
    [buffer appendString:@"\"\n"];
    [buffer appendString:@"  \"bundleIdentifier\": \""];
    [buffer appendString:menuApp.bundleIdentifier];
    [buffer appendString:@"\"\n"];
    [buffer appendString:@"  \"bundlePath\": \""];
    [buffer appendString:menuApp.bundleURL.path];
    [buffer appendString:@"\"\n"];
    [buffer appendString:@"  \"executablePath\": \""];
    [buffer appendString:menuApp.executableURL.path];
    [buffer appendString:@"\"\n"];
    [buffer appendString:@"  \"menus\":"];
    [buffer appendString:menuToJSON(menu, 2, [[[NSArray alloc] init] autorelease])];
    [buffer appendString:@"}"];
    return buffer;
}

- (NSString *)convertMenuToYAML:(NSArray *)menu app:(NSRunningApplication *)menuApp {
    NSMutableString *buffer = [NSMutableString stringWithString:@"application:\n"];
    [buffer appendString:@"    name: \""];
    [buffer appendString:menuApp.localizedName];
    [buffer appendString:@"\"\n"];
    [buffer appendString:@"    bundleIdentifier: \""];
    [buffer appendString:menuApp.bundleIdentifier];
    [buffer appendString:@"\"\n"];
    [buffer appendString:@"    bundlePath: \""];
    [buffer appendString:menuApp.bundleURL.path];
    [buffer appendString:@"\"\n"];
    [buffer appendString:@"    executablePath: \""];
    [buffer appendString:menuApp.executableURL.path];
    [buffer appendString:@"\"\n"];
    [buffer appendString:@"menus:\n"];
    [buffer appendString:menuToYAML(menu, 0, [[[NSArray alloc] init] autorelease])];
    return buffer;
}
@end
