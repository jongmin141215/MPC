//
//  CentralViewController.h
//  MPC
//
//  Created by Jongmin Kim on 11/11/15.
//  Copyright © 2015 Jongmin Kim. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
@import AVFoundation;

@interface CentralViewController : ViewController

@property (strong, nonatomic) AppDelegate *appDelegate;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) NSMutableArray *pendingRequests;
@property (strong, nonatomic) NSMutableData *bufferedSongData;
@property NSUInteger songSize;

@end
