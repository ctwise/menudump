//
//  main.m
//  menudump
//
//  Created by Charles Wise on 2/17/13.
//

#include "UIAccess.h"

NSRunningApplication *getAppByPid(pid_t pid) {
    NSArray *appNames = [[NSWorkspace sharedWorkspace] runningApplications];
    for (NSRunningApplication *app in appNames) {
        if (app.processIdentifier == pid) {
            return app;
        }
    }
    return nil;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        pid_t pid = -1;
        bool showHelp = false;
        bool outputJson = true;

        int offset = 1;
        while (offset < argc) {
            char const *value = argv[offset];
            if (strncasecmp(value, "--help", 6) == 0) {
                showHelp = true;
                offset++;
            } else if (strncasecmp(value, "--yaml", 6) == 0) {
                outputJson = false;
                offset++;
            } else if (strncasecmp(value, "--pid", 5) == 0) {
                if (argc >= (offset + 1)) {
                    pid = atol(argv[offset + 1]);
                    offset = offset + 2;
                }
            } else {
                offset++;
            }
        }

        if (showHelp) {
            printf("Usage: menudump [--pid <pid>] [--yaml] [--help]\n");
            printf("  Dumps the menu contents of a given application in JSON format. Defaults to the front-most application.\n");
            printf("  --pid <pid> to target a specific application.\n");
            printf("  --yaml to output in YAML format instead.\n");
            printf("  --help print this message\n");
            exit(1);
        }

        NSRunningApplication *menuApp = nil;
        if (pid == -1) {
            menuApp = [[NSWorkspace sharedWorkspace] menuBarOwningApplication];
        } else {
            menuApp = getAppByPid(pid);
        }

        if (menuApp) {
            UIAccess *ui = [[UIAccess new] autorelease];
            NSArray *menu = [ui getAppMenu:menuApp];
            NSString *contents;
            if (outputJson) {
                contents = [ui convertMenuToJSON:menu app:menuApp];
            } else {
                contents = [ui convertMenuToYAML:menu app:menuApp];
            }
            printf("%s", [contents UTF8String]);
        } else {
            printf("Unable to find app that matches the pid");
            exit(1);
        }
    }

    return 0;
}

