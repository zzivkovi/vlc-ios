/*****************************************************************************
 * VLCUPnPServerListViewController.m
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013-2015 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *          Marc Etcheverry <marc@taplightsoftware.com>
 *          Pierre SAGASPE <pierre.sagaspe # me.com>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCUPnPServerListViewController.h"

#import "NSString+SupportedMedia.h"

#import "MediaServerBasicObjectParser.h"
#import "MediaServer1ItemObject.h"
#import "MediaServer1ContainerObject.h"
#import "MediaServer1Device.h"
#import "BasicUPnPDevice+VLC.h"
#import <upnpx/UPnPManager.h>

#import "FirstViewController.h"

@interface VLCUPnPServerListViewController () <UITableViewDataSource, UITableViewDelegate>
{
    MediaServer1Device *_UPNPdevice;
    NSString *_UPNProotID;
    NSMutableArray *_mutableObjectList;
    NSMutableArray *_searchData;

    MediaServer1ItemObject *_lastSelectedMediaItem;
    UIView *_resourceSelectionActionSheetAnchorView;
}

@end

@implementation VLCUPnPServerListViewController

- (void)configureWithUPNPDevice:(MediaServer1Device*)device header:(NSString*)header andRootID:(NSString*)rootID
{
    _UPNPdevice = device;
    self.title = header;
    _UPNProotID = rootID;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _mutableObjectList = [[NSMutableArray alloc] init];

    NSString *sortCriteria = @"";
    NSMutableString *outSortCaps = [[NSMutableString alloc] init];
    [[_UPNPdevice contentDirectory] GetSortCapabilitiesWithOutSortCaps:outSortCaps];

    if ([outSortCaps rangeOfString:@"dc:title"].location != NSNotFound)
    {
        sortCriteria = @"+dc:title";
    }

    NSMutableString *outResult = [[NSMutableString alloc] init];
    NSMutableString *outNumberReturned = [[NSMutableString alloc] init];
    NSMutableString *outTotalMatches = [[NSMutableString alloc] init];
    NSMutableString *outUpdateID = [[NSMutableString alloc] init];

    [[_UPNPdevice contentDirectory] BrowseWithObjectID:_UPNProotID BrowseFlag:@"BrowseDirectChildren" Filter:@"*" StartingIndex:@"0" RequestedCount:@"0" SortCriteria:sortCriteria OutResult:outResult OutNumberReturned:outNumberReturned OutTotalMatches:outTotalMatches OutUpdateID:outUpdateID];

    [_mutableObjectList removeAllObjects];
    NSData *didl = [outResult dataUsingEncoding:NSUTF8StringEncoding];
    MediaServerBasicObjectParser *parser;
    @synchronized(self) {
        parser = [[MediaServerBasicObjectParser alloc] initWithMediaObjectArray:_mutableObjectList itemsOnly:NO];
    }
    [parser parseFromData:didl];
}

#pragma mark - table view data source, for more see super

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _mutableObjectList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];

    MediaServer1BasicObject *item;
    item = _mutableObjectList[indexPath.row];

    if (![item isContainer]) {
        MediaServer1ItemObject *mediaItem;
        long long mediaSize = 0;
        unsigned int durationInSeconds = 0;
        unsigned int bitrate = 0;

        MediaServer1ItemRes *resource = nil;
        NSEnumerator *e = [[mediaItem resources] objectEnumerator];
        while((resource = (MediaServer1ItemRes*)[e nextObject])){
            if (resource.bitrate > 0 && resource.durationInSeconds > 0) {
                mediaSize = resource.size;
                durationInSeconds = resource.durationInSeconds;
                bitrate = resource.bitrate;
            }
        }
        if (mediaSize < 1)
            mediaSize = [mediaItem.size longLongValue];

        if (mediaSize < 1)
            mediaSize = (bitrate * durationInSeconds);

        // object.item.videoItem.videoBroadcast items (like the HDHomeRun) may not have this information. Center the title (this makes channel names look better for the HDHomeRun)
        if (mediaSize > 0 && durationInSeconds > 0) {
            [cell.detailTextLabel setText: [NSString stringWithFormat:@"%@ (%@)", [NSByteCountFormatter stringFromByteCount:mediaSize countStyle:NSByteCountFormatterCountStyleFile], [VLCTime timeWithInt:durationInSeconds * 1000].stringValue]];
        }

        // Custom TV icon for video broadcasts
        if ([[mediaItem objectClass] isEqualToString:@"object.item.videoItem.videoBroadcast"]) {
            UIImage *broadcastImage;

            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                broadcastImage = [UIImage imageNamed:@"TVBroadcastIcon"];
            } else {
                broadcastImage = [UIImage imageNamed:@"TVBroadcastIcon~ipad"];
            }
            cell.imageView.image = broadcastImage;
        } else {
            cell.imageView.image = [UIImage imageNamed:@"blank"];
        }

    } else {
        cell.imageView.image = [UIImage imageNamed:@"folder"];
    }
    cell.textLabel.text = [item title];

    return cell;
}

#pragma mark - table view delegate, for more see super

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MediaServer1BasicObject *item;
    item = _mutableObjectList[indexPath.row];

    if ([item isContainer]) {
        MediaServer1ContainerObject *container;
        container = _mutableObjectList[indexPath.row];

        [self performSegueWithIdentifier:@"showUPnP" sender:container];
    } else {
        MediaServer1ItemObject *mediaItem;
        mediaItem = _mutableObjectList[indexPath.row];
        NSURL *itemURL;
        NSArray *uriCollectionKeys = [[mediaItem uriCollection] allKeys];
        NSUInteger count = uriCollectionKeys.count;
        NSRange position;
        NSUInteger correctIndex = 0;
        NSUInteger numberOfDownloadableResources = 0;
        for (NSUInteger i = 0; i < count; i++) {
            position = [uriCollectionKeys[i] rangeOfString:@"http-get:*:video/"];
            if (position.location != NSNotFound) {
                correctIndex = i;
                numberOfDownloadableResources++;
            }
        }
        NSArray *uriCollectionObjects = [[mediaItem uriCollection] allValues];

        // Present an action sheet for the user to choose which URI to download. Do not deselect the cell to provide visual feedback to the user
        if (numberOfDownloadableResources > 1) {
            _resourceSelectionActionSheetAnchorView = [tableView cellForRowAtIndexPath:indexPath];
            //            [self presentResourceSelectionActionSheetForUPnPMediaItem:mediaItem forDownloading:NO];
        } else {
            if (uriCollectionObjects.count > 0) {
                itemURL = [NSURL URLWithString:uriCollectionObjects[correctIndex]];
            }
            if (itemURL) {
                [self performSegueWithIdentifier:@"showFromURL" sender:itemURL];
            }
        }
    }

    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}


// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showUPnP"])  {
        MediaServer1ContainerObject *container = sender;
        [(VLCUPnPServerListViewController *)segue.destinationViewController configureWithUPNPDevice:_UPNPdevice header:[container title] andRootID:[container objectID]];
    } else if ([segue.identifier isEqualToString:@"showFromURL"]) {
        [(FirstViewController *)segue.destinationViewController setUrl:sender];
    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if ([sender isKindOfClass:[UITableViewCell class]]) {
        return false;
    }
    return true;
}


@end
