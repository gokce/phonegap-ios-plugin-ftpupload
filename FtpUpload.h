//
//  FtpUpload.h
//  Ftp Upload Plugin
//
//  Created by Gokce Taskan on 22/8/13.
//
//

#import <Cordova/CDV.h>

@interface FtpUpload : CDVPlugin <NSStreamDelegate>

@property (nonatomic, assign, readonly ) BOOL              isSending;
@property (nonatomic, strong, readwrite) NSOutputStream *  networkStream;
@property (nonatomic, strong, readwrite) NSInputStream *   fileStream;
@property (nonatomic, assign, readonly ) uint8_t *         buffer;
@property (nonatomic, assign, readwrite) size_t            bufferOffset;
@property (nonatomic, assign, readwrite) size_t            bufferLimit;

@end