/*****************************************************************************
 * VLCUPnPServerListViewController.h
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2015 VideoLAN. All rights reserved.
 * $Id$
 *
 * Author: Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCNetworkListViewController.h"

@class MediaServer1Device;

@interface VLCUPnPServerListViewController : UITableViewController

- (void)configureWithUPNPDevice:(MediaServer1Device *)device header:(NSString *)header andRootID:(NSString *)rootID;

@end
