/*
 * Copyright 2010 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *    http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FBUserSettingsViewController.h"
#import "FBProfilePictureView.h"
#import "FBGraphUser.h"
#import "FBSession.h"
#import "FBRequest.h"
#import "FBViewController+Internal.h"
#import "FBUtility.h"

@interface FBUserSettingsViewController ()

@property (nonatomic, retain) FBProfilePictureView *profilePicture;
@property (nonatomic, retain) UIImageView *backgroundImageView;
@property (nonatomic, retain) UILabel *connectedStateLabel;
@property (nonatomic, retain) id<FBGraphUser> me;
@property (nonatomic, retain) UIButton *loginLogoutButton;
@property (nonatomic) BOOL attemptingLogin;

- (void)loginLogoutButtonPressed:(id)sender;
- (void)sessionStateChanged:(FBSession *)session 
                      state:(FBSessionState)state
                      error:(NSError *)error;
- (void)openSession;
- (void)updateControls;
- (void)updateBackgroundImage;

@end

@implementation FBUserSettingsViewController

@synthesize profilePicture = _profilePicture;
@synthesize connectedStateLabel = _connectedStateLabel;
@synthesize me = _me;
@synthesize loginLogoutButton = _loginLogoutButton;
@synthesize permissions = _permissions;
@synthesize attemptingLogin = _attemptingLogin;
@synthesize backgroundImageView = _backgroundImageView;

#pragma mark View controller lifecycle

- (id)init {
    self = [super init];
    if (self) {
        self.cancelButton = nil;
        self.attemptingLogin = NO;
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.cancelButton = nil;
        self.attemptingLogin = NO;
    }
    return self;
}

- (void)dealloc {
    [super dealloc];
    
    [_profilePicture release];
    [_connectedStateLabel release];
    [_me release];
    [_loginLogoutButton release];
    [_permissions release];
    [_backgroundImageView release];
}

#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // If we are not being presented modally, we don't need a Done button.
    if (self.compatiblePresentingViewController == nil) {
        self.doneButton = nil;
    }
    
    const CGFloat kInternalMarginY = 20.0;
    
    CGRect usableBounds = self.canvasView.bounds;

    self.backgroundImageView = [[[UIImageView alloc] init] autorelease];
    self.backgroundImageView.frame = usableBounds;
    self.backgroundImageView.userInteractionEnabled = NO;
    self.backgroundImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.canvasView addSubview:self.backgroundImageView];
    [self updateBackgroundImage];
    
    UIImageView *logo = [[[UIImageView alloc] 
                         initWithImage:[UIImage imageNamed:@"FacebookSDKResources.bundle/FBLoginView/images/facebook.png"]] autorelease];
    CGPoint center = CGPointMake(CGRectGetMidX(usableBounds), 60);
    logo.center = center;
    logo.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.canvasView addSubview:logo];
    
    // We want the profile picture control and label to be grouped together when autoresized,
    // so we put them in a subview.
    UIView *containerView = [[[UIView alloc] init] autorelease];
    containerView.frame = CGRectMake(0, 
                                     logo.frame.origin.y * 2 + logo.frame.size.height, 
                                     usableBounds.size.width,
                                     110);
    containerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;

    // Add profile picture control
    self.profilePicture = [[[FBProfilePictureView alloc] initWithProfileID:nil
                                                        pictureCropping:FBProfilePictureCroppingSquare]
                           autorelease];
    self.profilePicture.frame = CGRectMake(containerView.frame.size.width / 2 - 32, 0, 64, 64);
    [containerView addSubview:self.profilePicture];

    // Add connected state/name control
    self.connectedStateLabel = [[[UILabel alloc] init] autorelease];
    self.connectedStateLabel.frame = CGRectMake(0, 
                                                self.profilePicture.frame.size.height + 16.0, 
                                                containerView.frame.size.width,
                                                20);
    self.connectedStateLabel.backgroundColor = [UIColor clearColor];
    self.connectedStateLabel.textAlignment = UITextAlignmentCenter;
    self.connectedStateLabel.numberOfLines = 0;
    self.connectedStateLabel.font = [UIFont boldSystemFontOfSize:16.0];
    self.connectedStateLabel.shadowColor = [UIColor blackColor];
    self.connectedStateLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    [containerView addSubview:self.connectedStateLabel];
    [self.canvasView addSubview:containerView];
    
    // Add the login/logout button
    self.loginLogoutButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *image = [UIImage imageNamed:@"FacebookSDKResources.bundle/FBUserSettingsView/images/silver-button-normal.png"];
    [self.loginLogoutButton setBackgroundImage:image forState:UIControlStateNormal];
    image = [UIImage imageNamed:@"FacebookSDKResources.bundle/FBUserSettingsView/images/silver-button-pressed.png"];
    [self.loginLogoutButton setBackgroundImage:image forState:UIControlStateHighlighted];
    self.loginLogoutButton.frame = CGRectMake((int)((usableBounds.size.width - image.size.width) / 2),
                                              CGRectGetMaxY(containerView.frame) + kInternalMarginY * 2,
                                              image.size.width,
                                              image.size.height);
    [self.loginLogoutButton addTarget:self
                               action:@selector(loginLogoutButtonPressed:)
                     forControlEvents:UIControlEventTouchUpInside];
    self.loginLogoutButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    UIColor *loginTitleColor = [UIColor colorWithRed:75.0 / 255.0
                                               green:81.0 / 255.0
                                                blue:100.0 / 255.0
                                               alpha:1.0];
    [self.loginLogoutButton setTitleColor:loginTitleColor forState:UIControlStateNormal];
    self.loginLogoutButton.titleLabel.font = [UIFont boldSystemFontOfSize:18.0];

    UIColor *loginShadowColor = [UIColor colorWithRed:212.0 / 255.0
                                                green:218.0 / 255.0
                                                 blue:225.0 / 255.0
                                                alpha:1.0];
    [self.loginLogoutButton setTitleShadowColor:loginShadowColor forState:UIControlStateNormal];
    self.loginLogoutButton.titleLabel.shadowOffset = CGSizeMake(0.0, 1.0);
    [self.canvasView addSubview:self.loginLogoutButton];
    
    // We need to know when the active session changes state.
    // We use the same handler for both, because we don't actually care about distinguishing between them.
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(handleActiveSessionStateChanged:) 
                                                 name:FBSessionDidBecomeOpenActiveSessionNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(handleActiveSessionStateChanged:) 
                                                 name:FBSessionDidBecomeClosedActiveSessionNotification
                                               object:nil];

    [self updateControls];
}

- (void)updateBackgroundImage {
    NSString *orientation = UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? @"Portrait" : @"Landscape";
    NSString *idiom = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) ? @"IPhone" : @"IPad";
    NSString *imagePath = [NSString stringWithFormat:@"FacebookSDKResources.bundle/FBUserSettingsView/images/loginBackground%@%@.jpg", idiom, orientation];
    self.backgroundImageView.image = [UIImage imageNamed:imagePath];
}

- (void)viewDidUnload {
    [super viewDidUnload];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self updateBackgroundImage];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) || UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
#pragma mark Implementation

- (void)updateControls {
    if (FBSession.activeSession.isOpen) {
        NSString *loginLogoutText = [FBUtility localizedStringForKey:@"FBUSVC:LogOut"
                                                         withDefault:@"Log Out"];
        [self.loginLogoutButton setTitle:loginLogoutText forState:UIControlStateNormal];
        
        // Label should be white with a shadow
        self.connectedStateLabel.textColor = [UIColor whiteColor];
        self.connectedStateLabel.shadowColor = [UIColor blackColor];

        // Move the label back below the profile view and show the profile view
        self.connectedStateLabel.frame = CGRectMake(0, 
                                                    self.profilePicture.frame.size.height + 16.0, 
                                                    self.connectedStateLabel.frame.size.width,
                                                    20);
        self.profilePicture.hidden = NO;
        
        // Do we know the user's name? If not, request it.
        if (self.me != nil) {
            self.connectedStateLabel.text = self.me.name;
            self.profilePicture.profileID = [self.me objectForKey:@"id"];
        } else {
            self.connectedStateLabel.text = [FBUtility localizedStringForKey:@"FBUSVC:LoggedIn"
                                                                 withDefault:@"Logged in"];
            self.profilePicture.profileID = nil;

            [[FBRequest requestForMe] startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                if (result) {
                    self.me = result;
                    [self updateControls];
                }
            }];
        }
    } else {
        self.me = nil;
        
        // Label should be gray and centered in its superview; hide the profile view
        self.connectedStateLabel.textColor = [UIColor colorWithRed:166.0 / 255.0
                                                             green:174.0 / 255.0
                                                              blue:215.0 / 255.0 
                                                             alpha:1.0];
        self.connectedStateLabel.shadowColor = nil;

        CGRect parentBounds = self.connectedStateLabel.superview.bounds;
        self.connectedStateLabel.center = CGPointMake(CGRectGetMidX(parentBounds),
                                                      CGRectGetMidY(parentBounds));
        self.profilePicture.hidden = YES;
        
        self.connectedStateLabel.text = [FBUtility localizedStringForKey:@"FBUSVC:NotLoggedIn"
                                                             withDefault:@"Not logged in"];
        self.profilePicture.profileID = nil;
        NSString *loginLogoutText = [FBUtility localizedStringForKey:@"FBUSVC:LogIn"
                                                         withDefault:@"Log In..."];
        [self.loginLogoutButton setTitle:loginLogoutText forState:UIControlStateNormal];
    }
}

- (void)sessionStateChanged:(FBSession *)session 
                      state:(FBSessionState)state
                      error:(NSError *)error
{
    if (error &&
        [self.delegate respondsToSelector:@selector(loginViewController:receivedError:)]) {
        [(id)self.delegate loginViewController:self receivedError:error];
    }

    if (self.attemptingLogin) {
        if (FB_ISSESSIONOPENWITHSTATE(state)) {
            self.attemptingLogin = NO;

            if ([self.delegate respondsToSelector:@selector(loginViewControllerDidLogUserIn:)]) {
                [(id)self.delegate loginViewControllerDidLogUserIn:self];
            }
        } else if (FB_ISSESSIONSTATETERMINAL(state)) {
            self.attemptingLogin = NO;
        }
    }
}

- (void)openSession {
    if ([self.delegate respondsToSelector:@selector(loginViewControllerWillAttemptToLogUserIn:)]) {
        [(id)self.delegate loginViewControllerWillAttemptToLogUserIn:self];
    }

    self.attemptingLogin = YES;

    [FBSession openActiveSessionWithPermissions:self.permissions
                                   allowLoginUI:YES
                              completionHandler:^(FBSession *session, FBSessionState state, NSError *error) {
                                  [self sessionStateChanged:session state:state error:error];
                              }];
}

#pragma mark Handlers

- (void)loginLogoutButtonPressed:(id)sender {
    if (FBSession.activeSession.isOpen) {
        if ([self.delegate respondsToSelector:@selector(loginViewControllerWillLogUserOut:)]) {
            [(id)self.delegate loginViewControllerWillLogUserOut:self];
        }

        [FBSession.activeSession closeAndClearTokenInformation];

        if ([self.delegate respondsToSelector:@selector(loginViewControllerDidLogUserOut:)]) {
            [(id)self.delegate loginViewControllerDidLogUserOut:self];
        }
    } else {
        [self openSession];
    }
}

- (void)handleActiveSessionStateChanged:(NSNotification *)notification {
    [self updateControls];
}

@end