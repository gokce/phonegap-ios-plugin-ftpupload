//
//  FtpUpload.m
//  Ftp Upload Plugin
//
//  Created by Gokce Taskan on 22/8/13.
//
//

#import "FtpUpload.h"
#import <Cordova/CDV.h>

enum {
    kSendBufferSize = 32768
};

NSString*           callbackId;

@implementation FtpUpload
{
    uint8_t                     _buffer[kSendBufferSize];
}

- (void)sendFiles:(CDVInvokedUrlCommand*)command {
    //[self.commandDelegate runInBackground:^{
    
    NSDictionary *args = command.arguments[0];
    NSString *address = [args objectForKey:@"address"];
    NSString *username = [args objectForKey:@"username"];
    NSString *password = [args objectForKey:@"password"];
    NSString *file = [args objectForKey:@"file"];
    
    NSString *fileName = [file stringByDeletingPathExtension];
    NSString *fileType = [file pathExtension];
    NSString *filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:fileType];
    
    callbackId = command.callbackId;
    
    NSLog(self.isSending ? @"Is already sending!" : @"Available to send");
    
    if (! self.isSending ) {
        [self startSend:filePath toUrl:address withUsername:username andPassword:password];
    }
}


- (void)startSend:(NSString *)filePath toUrl:(NSString *)urlText withUsername:(NSString *)username andPassword:(NSString *)password
{
    BOOL                    success;
    NSURL *                 url;
    
    assert(filePath != nil);
    assert([[NSFileManager defaultManager] fileExistsAtPath:filePath]);
    assert( [filePath.pathExtension isEqual:@"png"] || [filePath.pathExtension isEqual:@"jpg"] || [filePath.pathExtension isEqual:@"txt"] );
    
    assert(self.networkStream == nil);      // don't tap send twice in a row!
    assert(self.fileStream == nil);         // ditto
    
    // First get and check the URL.
    
    url = [self smartURLForString:urlText];
    success = (url != nil);
    
    if (success) {
        // Add the last part of the file name to the end of the URL to form the final
        // URL that we're going to put to.
        
        url = CFBridgingRelease(
                                CFURLCreateCopyAppendingPathComponent(NULL, (__bridge CFURLRef) url, (__bridge CFStringRef) [filePath lastPathComponent], false)
                                );
        success = (url != nil);
    }
    
    // If the URL is bogus, let the user know.  Otherwise kick off the connection.
    
    if ( ! success) {
        NSLog(@"Invalid URL");
        [self returnError:@"Invalid URL"];
    } else {
        
        // Open a stream for the file we're going to send.  We do not open this stream;
        // NSURLConnection will do it for us.
        
        self.fileStream = [NSInputStream inputStreamWithFileAtPath:filePath];
        assert(self.fileStream != nil);
                
        [self.fileStream open];
        
        // Open a CFFTPStream for the URL.
        
        self.networkStream = CFBridgingRelease(
                                               CFWriteStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) url)
                                               );
        assert(self.networkStream != nil);
        
        success = [self.networkStream setProperty:username forKey:(id)kCFStreamPropertyFTPUserName];
        assert(success);
        success = [self.networkStream setProperty:password forKey:(id)kCFStreamPropertyFTPPassword];
        assert(success);
        
        //Following line is causing trouble
        //[self.networkStream setProperty:(id)kCFBooleanFalse forKey:(id)kCFStreamPropertyFTPUsePassiveMode];
        
        self.networkStream.delegate = self;
        [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        NSLog(@"%@", self.networkStream);
        [self.networkStream open];
        
        [self sendDidStart];
    }
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
// An NSStream delegate callback that's called when events happen on our
// network stream.
{
#pragma unused(aStream)
    assert(aStream == self.networkStream);
    
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            NSLog(@"Opened connection");
        } break;
        case NSStreamEventHasBytesAvailable: {
            assert(NO);     // should never happen for the output stream
        } break;
        case NSStreamEventHasSpaceAvailable: {
            NSLog(@"Sending");
            
            // If we don't have any data buffered, go read the next chunk of data.
            
            if (self.bufferOffset == self.bufferLimit) {
                NSInteger   bytesRead;
                
                bytesRead = [self.fileStream read:self.buffer maxLength:kSendBufferSize];
                
                if (bytesRead == -1) {
                    [self stopSendWithStatus:@"File read error"];
                } else if (bytesRead == 0) {
                    [self stopSendWithStatus:nil];
                    [self returnSuccess];
                } else {
                    self.bufferOffset = 0;
                    self.bufferLimit  = bytesRead;
                }
            }
            
            // If we're not out of data completely, send the next chunk.
            
            if (self.bufferOffset != self.bufferLimit) {
                NSInteger   bytesWritten;
                bytesWritten = [self.networkStream write:&self.buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
                assert(bytesWritten != 0);
                if (bytesWritten == -1) {
                    [self stopSendWithStatus:@"Network write error"];
                } else {
                    self.bufferOffset += bytesWritten;
                }
            }
        } break;
        case NSStreamEventErrorOccurred: {
            [self stopSendWithStatus:@"Stream open error"];
        } break;
        case NSStreamEventEndEncountered: {
            // ignore
            [self returnSuccess];
        } break;
        default: {
            assert(NO);
        } break;
    }
}

- (void)stopSendWithStatus:(NSString *)statusString
{
    
    if (self.networkStream != nil) {
        [self.networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.networkStream.delegate = nil;
        [self.networkStream close];
        self.networkStream = nil;
    }
    if (self.fileStream != nil) {
        [self.fileStream close];
        self.fileStream = nil;
    }
    
    [self sendDidStopWithStatus:statusString];
}

- (uint8_t *)buffer
{
    return self->_buffer;
}

- (BOOL)isSending
{
    return (self.networkStream != nil);
}


- (void)dealloc
{
    [self stopSendWithStatus:@"Stopped"];
}


#pragma mark Network manager utility functions

-(void)sendDidStart {
    NSLog(@"send did start");
}

- (void)sendDidStopWithStatus:(NSString *)statusString
{
    NSLog(@"send did stop");
    if (statusString == nil) {
        statusString = @"Succeeded";
        [self returnSuccess];
    } else {
        [self returnError:statusString];
    }
}

- (NSURL *)smartURLForString:(NSString *)str
{
    NSURL *     result;
    NSString *  trimmedStr;
    NSRange     schemeMarkerRange;
    NSString *  scheme;
    
    assert(str != nil);
    
    result = nil;
    
    trimmedStr = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ( (trimmedStr != nil) && ([trimmedStr length] != 0) ) {
        schemeMarkerRange = [trimmedStr rangeOfString:@"://"];
        
        if (schemeMarkerRange.location == NSNotFound) {
            result = [NSURL URLWithString:[NSString stringWithFormat:@"ftp://%@", trimmedStr]];
        } else {
            scheme = [trimmedStr substringWithRange:NSMakeRange(0, schemeMarkerRange.location)];
            assert(scheme != nil);
            
            if ( ([scheme compare:@"ftp"  options:NSCaseInsensitiveSearch] == NSOrderedSame) ) {
                result = [NSURL URLWithString:trimmedStr];
            } else {
                // It looks like this is some unsupported URL scheme.
            }
        }
    }
    
    return result;
}


- (void) returnSuccess {
    NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
    [posError setObject: [NSNumber numberWithInt: CDVCommandStatus_OK] forKey:@"code"];
    [posError setObject: @"Success" forKey: @"message"];
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:posError];
    
    if (callbackId) {
        [self writeJavascript:[result toSuccessCallbackString:callbackId]];
    }
}


- (void)returnError:(NSString*)message
{
    NSMutableDictionary* posError = [NSMutableDictionary dictionaryWithCapacity:2];
    [posError setObject: [NSNumber numberWithInt: CDVCommandStatus_ERROR] forKey:@"code"];
    [posError setObject: message ? message : @"" forKey: @"message"];
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:posError];
    
    if (callbackId) {
        [self writeJavascript:[result toErrorCallbackString:callbackId]];
    }
}

@end