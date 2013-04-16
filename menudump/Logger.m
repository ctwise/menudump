//
// Created by Charles Wise on 4/16/13.
//

#import "Logger.h"

@implementation Logger

@synthesize logThreshold, async;

+(Logger *) singleton {
    static dispatch_once_t pred;
    static Logger *shared = nil;
    dispatch_once(&pred, ^{
        shared = [[Logger alloc] init];
        shared.logThreshold = (LoggerLevel) kSilent;
        shared.async = FALSE;
    });
    return shared;
}

-(void) debugWithLevel:(LoggerLevel)level
                  line:(int)line
              funcName:(const char *)funcName
               message:(NSString *)msg, ... {

    const char* const levelName[6] = { "TRACE", "DEBUG", " INFO", " WARN", "ERROR", "SILENT" };

    va_list ap;
    va_start (ap, msg);
    msg = [[NSString alloc] initWithFormat:msg arguments:ap];
    va_end (ap);

    if (level>=logThreshold){
        msg = [NSString stringWithFormat:@"%5s %50s:%3d - %@", levelName[level], funcName, line, msg];

        if ([self isAsync]){
            // change the queues if you like
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(msg);
//                    fprintf(stdout,"%s\n", [msg UTF8String]);
                });
            });
        } else {
            NSLog(msg);
//            fprintf(stdout,"%s\n", [msg UTF8String]);
        }

    }
}

@end