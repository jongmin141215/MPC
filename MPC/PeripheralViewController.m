//
//  PeripheralViewController.m
//  MPC
//
//  Created by Jongmin Kim on 11/11/15.
//  Copyright © 2015 Jongmin Kim. All rights reserved.
//

#import "PeripheralViewController.h"
@import MultipeerConnectivity;
@import MediaPlayer;
@import AVFoundation;

@interface PeripheralViewController ()

@end

@implementation PeripheralViewController

- (IBAction)sendMusic:(id)sender {
    [self.appDelegate.mpcHandler advertiseSelf:NO];
    
    NSError *error;
    
    NSLog(@"PERR: %@", self.appDelegate.mpcHandler.session.connectedPeers[0]);
    
    int songLen = _fullSongData.length;
    [self.appDelegate.mpcHandler.session sendData:[NSData dataWithBytes:&songLen length:sizeof(songLen)]
                                          toPeers:@[self.appDelegate.mpcHandler.session.connectedPeers[0]]
                                         withMode:MCSessionSendDataReliable
                                            error:&error];
    
    NSStream *outputStream = [self.appDelegate.mpcHandler.session startStreamWithName:@"musicStream" toPeer:self.appDelegate.mpcHandler.session.connectedPeers[0] error:&error];
    
    outputStream.delegate = self;
    [outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop]
                            forMode:NSDefaultRunLoopMode];
    [outputStream open];
    
    if (error != nil) {
        NSLog(@"%@", [error localizedDescription]);
    } else {
        NSLog(@"Success! Started music stream");
    }
}

- (void)stream:(NSOutputStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    switch(eventCode) {
        case NSStreamEventHasSpaceAvailable:
        {
            NSLog(@"Writing to stream");
            uint8_t *readBytes = (uint8_t *)[_fullSongData bytes];
            readBytes += _byteIndex; // instance variable to move pointer
            int data_len = [_fullSongData length];
            unsigned int len = ((data_len - _byteIndex >= 1024) ?
                                1024 : (data_len-_byteIndex));
            uint8_t buf[len];
            (void)memcpy(buf, readBytes, len);
            len = [stream write:(const uint8_t *)buf maxLength:len];
            NSLog(@"Len was %i, byte index is %i", len, _byteIndex);
            _byteIndex += len;
            break;
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _byteIndex = 0;
    
    //    NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"m4a"];
    //    _fullSongData = [NSData dataWithContentsOfURL:url];
    _fullSongData = [NSData data];
    
    self.appDelegate = (AppDelegate *) [[UIApplication sharedApplication] delegate];
    
    [self.appDelegate.mpcHandler setupPeerWithDisplayName:[UIDevice currentDevice].name];
    [self.appDelegate.mpcHandler setupSession];
    [self.appDelegate.mpcHandler advertiseSelf:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(peerChangedStateWithNotification:)
                                                 name:@"MPCDemo_DidChangeStateNotification"
                                               object:nil];
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)peerChangedStateWithNotification:(NSNotification *)notification {
    // Get the state of the peer.
    int state = [[[notification userInfo] objectForKey:@"state"] intValue];
    
    // We care only for the Connected and the Not Connected states.
    // The Connecting state will be simply ignored.
    if (state != MCSessionStateConnecting) {
        // We'll just display all the connected peers (players) to the text view.
        NSString *allPlayers = @"Other players connected with:\n\n";
        
        for (int i = 0; i < self.appDelegate.mpcHandler.session.connectedPeers.count; i++) {
            NSString *displayName = [[self.appDelegate.mpcHandler.session.connectedPeers objectAtIndex:i] displayName];
            
            allPlayers = [allPlayers stringByAppendingString:@"\n"];
            allPlayers = [allPlayers stringByAppendingString:displayName];
        }
        
        NSLog(@"users: %@", allPlayers);
    }
}

- (void)viewDidAppear:(BOOL)animated {
    //    if (self.appDelegate.mpcHandler.session != nil) {
    //        [[self.appDelegate mpcHandler] setupBrowser];
    //
    //        [self presentViewController:self.appDelegate.mpcHandler.browser
    //                           animated:YES
    //                         completion:nil];
    //    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}




- (IBAction)pickSong:(id)sender {
    MPMediaPickerController *picker = [[MPMediaPickerController alloc] initWithMediaTypes: MPMediaTypeMusic];
    
    [picker setDelegate: self];
    picker.showsCloudItems = NO;
    picker.allowsPickingMultipleItems = YES;
    picker.prompt =
    NSLocalizedString (@"Pick a song to send",
                       "Prompt in media item picker");
    
    [self presentModalViewController: picker animated: YES];
}

- (void) mediaPicker: (MPMediaPickerController *) mediaPicker
   didPickMediaItems: (MPMediaItemCollection *) collection {    
    NSLog(@"%@", collection.items[0]);
    [self mediaItemToData:collection.items[0]];
    
    [self dismissModalViewControllerAnimated: YES];
}
- (void) mediaPickerDidCancel: (MPMediaPickerController *) mediaPicker {
    [self dismissModalViewControllerAnimated: YES];
}


-(void)mediaItemToData : (MPMediaItem *) curItem
{
    NSURL *url = [curItem valueForProperty: MPMediaItemPropertyAssetURL];
    
    AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL: url options:nil];
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset: songAsset
                                                                      presetName:AVAssetExportPresetAppleM4A];
    
    exporter.outputFileType = @"com.apple.m4a-audio";
    exporter.shouldOptimizeForNetworkUse = YES;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * myDocumentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    [[NSDate date] timeIntervalSince1970];
    NSTimeInterval seconds = [[NSDate date] timeIntervalSince1970];
    NSString *intervalSeconds = [NSString stringWithFormat:@"%0.0f",seconds];
    
    NSString * fileName = [NSString stringWithFormat:@"%@.m4a",intervalSeconds];
    
    NSString *exportFile = [myDocumentsDirectory stringByAppendingPathComponent:fileName];
    
    NSURL *exportURL = [NSURL fileURLWithPath:exportFile];
    exporter.outputURL = exportURL;
    NSLog(@"%@", exportURL);
    
    // do the export
    // (completion handler block omitted)
    [exporter exportAsynchronouslyWithCompletionHandler:
     ^{
         int exportStatus = exporter.status;
         
         switch (exportStatus)
         {
             case AVAssetExportSessionStatusFailed:
             {
                 NSError *exportError = exporter.error;
                 NSLog (@"AVAssetExportSessionStatusFailed: %@", exportError);
                 break;
             }
             case AVAssetExportSessionStatusCompleted:
             {
                 NSLog (@"AVAssetExportSessionStatusCompleted");
                 
                 NSData *data = [NSData dataWithContentsOfFile: [myDocumentsDirectory
                                                                 stringByAppendingPathComponent:fileName]];
                 
                 NSLog(@"%i", data.length);
                 _fullSongData = data;
                 //DLog(@"Data %@",data);
                 data = nil;
                 
                 break;
             }
             case AVAssetExportSessionStatusUnknown:
             {
                 NSLog (@"AVAssetExportSessionStatusUnknown"); break;
             }
             case AVAssetExportSessionStatusExporting:
             {
                 NSLog (@"AVAssetExportSessionStatusExporting"); break;
             }
             case AVAssetExportSessionStatusCancelled:
             {
                 NSLog (@"AVAssetExportSessionStatusCancelled"); break;
             }
             case AVAssetExportSessionStatusWaiting:
             {
                 NSLog (@"AVAssetExportSessionStatusWaiting"); break;
             }
             default:
             {
                 NSLog (@"didn't get export status"); break;
             }
         }
     }];
}

@end
