//
//  PeripheralViewController.h
//  MPC
//
//  Created by Jongmin Kim on 11/11/15.
//  Copyright © 2015 Jongmin Kim. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"

@interface PeripheralViewController : ViewController

- (IBAction)sendMusic:(id)sender;
- (IBAction)pickSong:(id)sender;

@property (strong, nonatomic) AppDelegate *appDelegate;
@property (strong, nonatomic) NSData *fullSongData;
@property int byteIndex;

@end
