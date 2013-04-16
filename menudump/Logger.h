//
// Created by Charles Wise on 4/16/13.
//

#import <Foundation/Foundation.h>

#define trace(args...) [[Logger singleton] debugWithLevel:kTrace line:__LINE__ funcName:__PRETTY_FUNCTION__ message:args];
#define debug(args...) [[Logger singleton] debugWithLevel:kDebug line:__LINE__ funcName:__PRETTY_FUNCTION__ message:args];
#define info(args...) [[Logger singleton] debugWithLevel:kInfo line:__LINE__ funcName:__PRETTY_FUNCTION__ message:args];
#define warn(args...) [[Logger singleton] debugWithLevel:kWarn line:__LINE__ funcName:__PRETTY_FUNCTION__ message:args];
#define error(args...) [[Logger singleton] debugWithLevel:kError line:__LINE__ funcName:__PRETTY_FUNCTION__ message:args];

typedef enum {
    kTrace=0, kDebug=1, kInfo=2, kWarn=3, kError=4, kSilent=5
} LoggerLevel;

@interface Logger : NSObject

@property (nonatomic, assign) LoggerLevel logThreshold;
@property (nonatomic, assign, getter=isAsync) BOOL async;

+(Logger *) singleton;

-(void) debugWithLevel:(LoggerLevel)level
                  line:(int)line
              funcName:(const char *)funcName
               message:(NSString *)msg, ...;

@end