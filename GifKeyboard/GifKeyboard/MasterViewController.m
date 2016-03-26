//
//  MasterViewController.m
//  GifKeyboard
//
//  Created by LouieShum on 3/21/16.
//  Copyright © 2016 LouieShum. All rights reserved.
//

#import "MasterViewController.h"
#import "DetailViewController.h"
#import "TakeViedoViewController.h"

@interface VideoCell : UITableViewCell

@end
@implementation VideoCell

@end

@interface MasterViewController ()

@property NSArray *AllVideos;
@end

@implementation MasterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.leftBarButtonItem = self.editButtonItem;

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
    self.navigationItem.rightBarButtonItem = addButton;
    
    [self.tableView registerClass:[VideoCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)reloadData{
    self.AllVideos =  @[[[NSBundle mainBundle] pathForResource:@"test1" ofType:@"mp4"],
                       [[NSBundle mainBundle] pathForResource:@"test2" ofType:@"mp4"],
                        [[NSBundle mainBundle] pathForResource:@"Android1" ofType:@"mp4"],
                        [[NSBundle mainBundle] pathForResource:@"Android2" ofType:@"mp4"],
                        [[NSBundle mainBundle] pathForResource:@"Android3" ofType:@"mp4"],
                        [[NSBundle mainBundle] pathForResource:@"Android4" ofType:@"mp4"],
                        [[NSBundle mainBundle] pathForResource:@"Android5" ofType:@"mp4"],
                        [[NSBundle mainBundle] pathForResource:@"Android6" ofType:@"mp4"]];
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)insertNewObject:(id)sender{
    [self.navigationController pushViewController:[TakeViedoViewController new] animated:YES];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.AllVideos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = [NSString stringWithFormat:@"Video %@", @(indexPath.row)];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    DetailViewController *dt = [DetailViewController new];
    dt.path = [self.AllVideos objectAtIndex:indexPath.row];
    [self.navigationController pushViewController:dt animated:YES];
}
@end
