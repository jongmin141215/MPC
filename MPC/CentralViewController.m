//
//  CentralViewController.m
//  MPC
//
//  Created by Jongmin Kim on 11/11/15.
//  Copyright © 2015 Jongmin Kim. All rights reserved.
//

#import "CentralViewController.h"
@import MultipeerConnectivity;
@import AVFoundation;

@interface CentralViewController ()
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (nonatomic) float progressValue;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;


@end

@implementation CentralViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    self.progressBar.hidden = YES;
    self.progressBar.progress = 0.0;
    self.playButton.enabled = NO;
    self.bufferedSongData = [NSMutableData data];
    self.pendingRequests = [NSMutableArray array];
    
    self.appDelegate = (AppDelegate *) [[UIApplication sharedApplication] delegate];
    
    [self.appDelegate.mpcHandler setupPeerWithDisplayName:[UIDevice currentDevice].name];
    [self.appDelegate.mpcHandler setupSession];
    [self.appDelegate.mpcHandler advertiseSelf:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleReceivedDataWithNotification:)
                                                 name:@"MPCDemo_DidReceiveDataNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleStreamDataWithNotification:)
                                                 name:@"MPCDemo_DidReceiveStreamData"
                                               object:nil];
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidAppear:(BOOL)animated {
    }

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
    [self.appDelegate.mpcHandler.browser dismissViewControllerAnimated:YES completion:nil];
}

- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
    [self.appDelegate.mpcHandler.browser dismissViewControllerAnimated:YES completion:nil];
}

- (void)handleReceivedDataWithNotification:(NSNotification *)notification {
    NSLog(@"handleReceivedData");
    // Get the user info dictionary that was received along with the notification.
    NSDictionary *userInfoDict = [notification userInfo];
    
    // Convert the received data into a NSString object.
    
    NSData *fullSongData = [userInfoDict objectForKey:@"data"];
    [fullSongData getBytes:&_songSize length:sizeof(_songSize)];
    
    NSLog(@"Recv. %lu bytes", (unsigned long)_songSize);
    
    if(self.player == nil) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:@"streaming-file:///"] options:nil];
        [asset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
        
        self.pendingRequests = [NSMutableArray array];
        
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
        self.player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
        [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:NULL];
    }
    
    
    // Keep the sender's peerID and get its display name.
    //    MCPeerID *senderPeerID = [userInfoDict objectForKey:@"peerID"];
    //    NSString *senderDisplayName = senderPeerID.displayName;
}
- (void)handleStreamDataWithNotification:(NSNotification *)notification {
    NSLog(@"handleStreamData");
    self.progressBar.hidden = NO;
    NSDictionary *userInfoDict = [notification userInfo];
    
    NSData *data = [userInfoDict objectForKey:@"data"];
    [_bufferedSongData appendData:data];
    self.progressValue = [[NSNumber numberWithInt: self.bufferedSongData.length] floatValue]/ [[NSNumber numberWithInt: self.songSize] floatValue];
    NSLog(@"float number: %f", self.progressBar.progress);
    if (_progressValue >= 1) {
        self.progressBar.hidden = YES;
    } else {
        self.progressBar.progress = self.progressValue;
    }

    [self processPendingRequests];
    
    NSLog(@"Recv. %lu bytes", (unsigned long)data.length);
    NSLog(@"Total recv: %lu", (unsigned long)_bufferedSongData.length);
}











#pragma mark - AVURLAsset resource loading

- (void)processPendingRequests
{
    //    NSLog(@"processPendingRequests");
    NSMutableArray *requestsCompleted = [NSMutableArray array];
    
    for (AVAssetResourceLoadingRequest *loadingRequest in self.pendingRequests)
    {
        [self fillInContentInformation:loadingRequest.contentInformationRequest];
        
        BOOL didRespondCompletely = [self respondWithDataForRequest:loadingRequest.dataRequest];
        
        if (didRespondCompletely)
        {
            [requestsCompleted addObject:loadingRequest];
            
            [loadingRequest finishLoading];
            
            NSLog(@"Finished processing loading request!");
            
        }
    }
    
    [self.pendingRequests removeObjectsInArray:requestsCompleted];
}

- (void)fillInContentInformation:(AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest
{
    //    NSLog(@"fillInContentInformation");
    if (contentInformationRequest == nil)
    {
        return;
    }
    
    contentInformationRequest.byteRangeAccessSupported = YES;
    contentInformationRequest.contentType = @"com.apple.m4a-audio";
    contentInformationRequest.contentLength = _songSize;
}

- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest
{
    //    NSLog(@"respondWithDataForRequest");
    long long startOffset = dataRequest.requestedOffset;
    //    NSLog(@"Requested offset: %i", dataRequest.requestedOffset);
    if (dataRequest.currentOffset != 0)
    {
        //        NSLog(@"dataRequest.currentOffset <> 0");
        startOffset = dataRequest.currentOffset;
        //        NSLog(@"New startOffeset = %i", dataRequest.currentOffset);
    }
    
    // Don't have any data at all for this request
    if (self.bufferedSongData.length == 0 || self.bufferedSongData.length < startOffset)
    {
        NSLog(@"Not enough data for the request; wanted startOffset %lli, only have %lu bytes of data", startOffset, (unsigned long)self.bufferedSongData.length);
        return NO;
    }
    
    // This is the total data we have from startOffset to whatever has been downloaded so far
    NSUInteger unreadBytes = self.bufferedSongData.length - (NSUInteger)startOffset;
    //    NSLog(@"Unread bytes: %i", unreadBytes);
    
    // Respond with whatever is available if we can't satisfy the request fully yet
    NSUInteger numberOfBytesToRespondWith = MIN((NSUInteger)dataRequest.requestedLength, unreadBytes);
    NSLog(@"==> Responding with bytes: %lu", (unsigned long)numberOfBytesToRespondWith);
    
    [dataRequest respondWithData:[self.bufferedSongData subdataWithRange:NSMakeRange((NSUInteger)startOffset, numberOfBytesToRespondWith)]];
    
    NSLog(@"----------------------");
    NSLog(@"Cur offset: %lli", dataRequest.currentOffset);
    NSLog(@"----------------------");
    BOOL didRespondFully = (dataRequest.currentOffset - dataRequest.requestedOffset) >= dataRequest.requestedLength;
    
    return didRespondFully;
}


- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    //    NSLog(@"shouldWaitForLoadingOfRequestedResource");
    [self.pendingRequests addObject:loadingRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    //    NSLog(@"didCancelLoadingRequest");
    [self.pendingRequests removeObject:loadingRequest];
}

#pragma KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (self.player.currentItem.status == AVPlayerItemStatusReadyToPlay)
    {
        NSLog(@"READY TO PLAY");
        self.playButton.enabled = YES;
    }
}

- (IBAction)playButtonPressed:(id)sender {
    [self.player play];
}
- (IBAction)searchForPeers:(id)sender {
    if (self.appDelegate.mpcHandler.session != nil) {
        [[self.appDelegate mpcHandler] setupBrowser];
        [[[self.appDelegate mpcHandler] browser] setDelegate:self];
        
        [self presentViewController:self.appDelegate.mpcHandler.browser
                           animated:YES
                         completion:nil];
    }

}


@end
