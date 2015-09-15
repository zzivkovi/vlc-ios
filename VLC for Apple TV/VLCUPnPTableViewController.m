/*****************************************************************************
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2015 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Tobias Conradi <videolan@tobias-conradi.de>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCUPnPTableViewController.h"
#import <upnpx/UPnPManager.h>
#import "VLCUPnPServerListViewController.h"

@interface VLCUPnPTableViewController () <UPnPDBObserver>
{
    NSArray *_filteredUPNPDevices;
    NSArray *_UPNPdevices;
    BOOL _udnpDiscoveryRunning;
    NSTimer *_searchTimer;
    BOOL _setup;
}

@end

@implementation VLCUPnPTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self _startUPNPDiscovery];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self _stopUPNPDiscovery];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _filteredUPNPDevices.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"networkCell" forIndexPath:indexPath];

    BasicUPnPDevice *device = _filteredUPNPDevices[indexPath.row];
    cell.textLabel.text = [device friendlyName];
    cell.imageView.image = [device smallIcon];

    return cell;
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showUPnP"])  {
        NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
        if (!indexPath) {
            return;
        }

        BasicUPnPDevice *device = _filteredUPNPDevices[indexPath.row];
        if ([[device urn] isEqualToString:@"urn:schemas-upnp-org:device:MediaServer:1"]) {
            MediaServer1Device *server = (MediaServer1Device*)device;
            [(VLCUPnPServerListViewController *)segue.destinationViewController configureWithUPNPDevice:server header:[device friendlyName] andRootID:@"0"];
        }
    }
}

#pragma mark - UPNP discovery
- (void)_startUPNPDiscovery
{

    UPnPManager *managerInstance = [UPnPManager GetInstance];

    _UPNPdevices = [[managerInstance DB] rootDevices];

    if (_UPNPdevices.count > 0)
        [self UPnPDBUpdated:nil];

    [[managerInstance DB] addObserver:self];

    //Optional; set User Agent
    if (!_setup) {
        [[managerInstance SSDP] setUserAgentProduct:[NSString stringWithFormat:@"VLCforiOS/%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]] andOS:[NSString stringWithFormat:@"iOS/%@", [[UIDevice currentDevice] systemVersion]]];
        _setup = YES;
    }

    //Search for UPnP Devices
    [[managerInstance SSDP] startSSDP];
    [[managerInstance SSDP] notifySSDPAlive];

    _searchTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:1.0] interval:10.0 target:self selector:@selector(_performSSDPSearch) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_searchTimer forMode:NSRunLoopCommonModes];
    _udnpDiscoveryRunning = YES;
}

- (void)_performSSDPSearch
{
    UPnPManager *managerInstance = [UPnPManager GetInstance];
    [[managerInstance SSDP] searchSSDP];
    [[managerInstance SSDP] searchForMediaServer];
    [[managerInstance SSDP] performSelectorInBackground:@selector(SSDPDBUpdate) withObject:nil];
}

- (void)_stopUPNPDiscovery
{
    if (_udnpDiscoveryRunning) {
        UPnPManager *managerInstance = [UPnPManager GetInstance];
        [[managerInstance SSDP] notifySSDPByeBye];
        [_searchTimer invalidate];
        _searchTimer = nil;
        [[managerInstance DB] removeObserver:self];
        [[managerInstance SSDP] stopSSDP];
        _udnpDiscoveryRunning = NO;
    }
}

//protocol UPnPDBObserver
- (void)UPnPDBWillUpdate:(UPnPDB*)sender
{
}

- (void)UPnPDBUpdated:(UPnPDB*)sender
{
    NSUInteger count = _UPNPdevices.count;
    BasicUPnPDevice *device;
    NSMutableArray *mutArray = [[NSMutableArray alloc] init];
    for (NSUInteger x = 0; x < count; x++) {
        device = _UPNPdevices[x];
        if ([[device urn] isEqualToString:@"urn:schemas-upnp-org:device:MediaServer:1"])
            [mutArray addObject:device];
        else
            NSLog(@"found device '%@' with unsupported urn '%@'", [device friendlyName], [device urn]);
    }
    _filteredUPNPDevices = nil;
    _filteredUPNPDevices = [NSArray arrayWithArray:mutArray];

    [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}

@end
