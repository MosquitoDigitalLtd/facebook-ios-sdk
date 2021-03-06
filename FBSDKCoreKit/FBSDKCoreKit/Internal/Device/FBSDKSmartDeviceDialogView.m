// Copyright (c) 2014-present, Facebook, Inc. All rights reserved.
//
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Facebook.
//
// As with any software that integrates with the Facebook platform, your use of
// this software is subject to the Facebook Developer Principles and Policies
// [http://developers.facebook.com/policy/]. This copyright notice shall be
// included in all copies or substantial portions of the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "FBSDKSmartDeviceDialogView.h"

#import "FBSDKCoreKit+Internal.h"

// don't download icons more than once a day.
static const NSTimeInterval kSmartLoginIconsTTL = 60 * 60 * 24;

@implementation FBSDKSmartDeviceDialogView
{
  UIActivityIndicatorView *_spinner;
  UILabel *_confirmationCodeLabel;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    [self _prepareImageCache];
  }
  return self;
}

#pragma mark - Overrides

- (void)setConfirmationCode:(NSString *)confirmationCode
{
  if (![self.confirmationCode isEqualToString:confirmationCode]) {
    if (confirmationCode == nil) {
      _confirmationCodeLabel.text = @"";
      _confirmationCodeLabel.hidden = YES;
      [_spinner startAnimating];
    } else {
      [_spinner stopAnimating];
      _confirmationCodeLabel.text = confirmationCode;
      _confirmationCodeLabel.hidden = NO;
    }
  }
}

- (void)buildView
{
  //intentionally blank.
}

#pragma mark - Helpers

- (void)_prepareImageCache
{
  [FBSDKServerConfigurationManager loadServerConfigurationWithCompletionBlock:^(FBSDKServerConfiguration *serverConfiguration, NSError *error) {
    if ((serverConfiguration.smartLoginOptions & FBSDKServerConfigurationSmartLoginOptionsEnabled) &&
        serverConfiguration.smartLoginMenuIconURL &&
        serverConfiguration.smartLoginBookmarkIconURL) {
      __block UIImage *bookmarkIconImage;
      __block UIImage *menuIconImage;
      __block NSUInteger count = 0;
      void(^buildViewBlock)(void) = ^{
        count++;
        if (count >= 2){
          dispatch_async(dispatch_get_main_queue(), ^{
            [self _buildViewWithBookmarkIcon:bookmarkIconImage
                                    menuIcon:menuIconImage];
            [self setNeedsLayout];
          });
        }
      };
      [[FBSDKImageDownloader sharedInstance] downloadImageWithURL:serverConfiguration.smartLoginBookmarkIconURL
                                                              ttl:kSmartLoginIconsTTL
                                                       completion:^(UIImage *image) {
                                                         bookmarkIconImage = image;
                                                         buildViewBlock();
                                                       }];
      [[FBSDKImageDownloader sharedInstance] downloadImageWithURL:serverConfiguration.smartLoginMenuIconURL
                                                              ttl:kSmartLoginIconsTTL
                                                       completion:^(UIImage *image) {
                                                         menuIconImage = image;
                                                         buildViewBlock();
                                                       }];
    } else {
      [self _buildViewWithBookmarkIcon:nil menuIcon:nil];
    }
  }];
}

- (void)_buildViewWithBookmarkIcon:(UIImage *)bookmarkIcon
                          menuIcon:(UIImage *)menuIcon
{
  // This is a "static" view with just a cancel button so add all the constraints here
  // rather than properly override `updateConstraints`.
  const CGFloat kWidth = 1080;
  const CGFloat kHeight = 820;
  const CGFloat kVerticalSpaceBetweenHeaderViewAndInstructionLabel = 50;
  const CGFloat kDialogHeaderViewHeight = 250;
  const CGFloat kLogoSize = 44;
  const CGFloat kLogoMargin = 30;
  const CGFloat kInstructionTextHorizontalMargin = 100;
  const CGFloat kConfirmationCodeFontSize = 108;
  const CGFloat kFontColorValue = 119.0/255.0;
  const CGFloat kInstructionFontSize = 32;
  const CGFloat kVerticalMarginOrLabel = 40;

  // build the container view.
  UIView *dialogView = [[UIView alloc] init];
  dialogView.layer.cornerRadius = 3;
  dialogView.translatesAutoresizingMaskIntoConstraints = NO;
  dialogView.clipsToBounds = YES;
  dialogView.backgroundColor = [UIColor whiteColor];
  [self addSubview:dialogView];
  [NSLayoutConstraint constraintWithItem:dialogView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0].active = YES;;
  [NSLayoutConstraint constraintWithItem:dialogView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0].active = YES;
  [dialogView.widthAnchor constraintEqualToConstant:kWidth].active = YES;
  [dialogView.heightAnchor constraintEqualToConstant:kHeight].active = YES;

  // build the header container view (which will contain the logo and code).
  UIView *dialogHeaderView = [[UIView alloc] init];
  dialogHeaderView.translatesAutoresizingMaskIntoConstraints = NO;
  dialogHeaderView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:235.0/255.0 alpha:0.85];
  [dialogView addSubview:dialogHeaderView];
  [dialogHeaderView.leadingAnchor constraintEqualToAnchor:dialogView.leadingAnchor].active = YES;
  [dialogHeaderView.trailingAnchor constraintEqualToAnchor:dialogView.trailingAnchor].active = YES;
  [dialogHeaderView.heightAnchor constraintEqualToConstant:kDialogHeaderViewHeight].active = YES;
  [dialogHeaderView.topAnchor constraintEqualToAnchor:dialogView.topAnchor].active = YES;

  // build the logo.
  CGSize imageSize = CGSizeMake(kLogoSize, kLogoSize);
  FBSDKLogo *logoHelper =[[FBSDKLogo alloc] initWithColor:[UIColor colorWithRed:66.0/255.0 green:103.0/255.0 blue:178.0/255.0 alpha:1]];
  UIImage *image = [logoHelper imageWithSize:imageSize];
  image = [image resizableImageWithCapInsets:UIEdgeInsetsZero resizingMode:UIImageResizingModeStretch];
  UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
  imageView.translatesAutoresizingMaskIntoConstraints = NO;
  [dialogHeaderView addSubview:imageView];
  [imageView.widthAnchor constraintEqualToConstant:kLogoSize].active = YES;
  [imageView.heightAnchor constraintEqualToConstant:kLogoSize].active = YES;
  [imageView.topAnchor constraintEqualToAnchor:dialogHeaderView.topAnchor constant:kLogoMargin].active = YES;
  [imageView.leadingAnchor constraintEqualToAnchor:dialogHeaderView.leadingAnchor constant:kLogoMargin].active = YES;

  // build the activity spinner
  _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
  _spinner.translatesAutoresizingMaskIntoConstraints = NO;
  [dialogHeaderView addSubview:_spinner];
  [NSLayoutConstraint constraintWithItem:_spinner attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:dialogHeaderView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0].active = YES;
  [NSLayoutConstraint constraintWithItem:_spinner attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:dialogHeaderView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0].active = YES;
  [_spinner.widthAnchor constraintEqualToConstant:kConfirmationCodeFontSize].active = YES;
  [_spinner.heightAnchor constraintEqualToConstant:kConfirmationCodeFontSize].active = YES;
  [_spinner startAnimating];

  // build the confirmation code (which replaces the spinner when the code is available).
  _confirmationCodeLabel = [[UILabel alloc] init];
  _confirmationCodeLabel.translatesAutoresizingMaskIntoConstraints = NO;
  _confirmationCodeLabel.textColor = logoHelper.color;
  _confirmationCodeLabel.font = [UIFont systemFontOfSize:kConfirmationCodeFontSize weight:UIFontWeightLight];
  _confirmationCodeLabel.textAlignment = NSTextAlignmentCenter;
  [_confirmationCodeLabel sizeToFit];
  [dialogHeaderView addSubview:_confirmationCodeLabel];
  [NSLayoutConstraint constraintWithItem:_confirmationCodeLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:dialogHeaderView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0].active = YES;
  [NSLayoutConstraint constraintWithItem:_confirmationCodeLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:dialogHeaderView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0].active = YES;
  _confirmationCodeLabel.hidden = YES;

  // build the smartlogin instructions
  UILabel *smartInstructionLabel = [[UILabel alloc] init];
  smartInstructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
  NSString *smartInstructionsStep0 = NSLocalizedStringWithDefaultValue(@"DeviceLogin.SmartLogInStep0",
                                                                      @"FacebookSDK",
                                                                      [FBSDKInternalUtility bundleForStrings],
                                                                      @"Confirm your code on Facebook.",
                                                                      @"The string for smart login instructions");
  NSString *smartInstructionsStep1 = NSLocalizedStringWithDefaultValue(@"DeviceLogin.SmartLogInStep1",
                                                                       @"FacebookSDK",
                                                                       [FBSDKInternalUtility bundleForStrings],
                                                                       @"\n1. Go to the Menu  ",
                                                                       @"The string for smart login instructions");
  NSString *smartInstructionsStep2 = NSLocalizedStringWithDefaultValue(@"DeviceLogin.SmartLogInStep2",
                                                                       @"FacebookSDK",
                                                                       [FBSDKInternalUtility bundleForStrings],
                                                                       @"\n2. Select Device Requests  ",
                                                                       @"The string for smart login instructions");
  NSString *smartInstructionsStep3 = NSLocalizedStringWithDefaultValue(@"DeviceLogin.SmartLogInStep3",
                                                                       @"FacebookSDK",
                                                                       [FBSDKInternalUtility bundleForStrings],
                                                                       @"\n3. Confirm code.",
                                                                       @"The string for smart login instructions");
  NSTextAttachment *bookmarkAttachment = [[NSTextAttachment alloc] init];
  bookmarkAttachment.image = bookmarkIcon;
  NSAttributedString *attributedBookmarkString = [NSAttributedString attributedStringWithAttachment:bookmarkAttachment];

  NSTextAttachment *menuAttachment = [[NSTextAttachment alloc] init];
  menuAttachment.image = menuIcon;
  NSAttributedString *attributedMenuString = [NSAttributedString attributedStringWithAttachment:menuAttachment];

  NSMutableParagraphStyle *instructionLabelParagraphStyle = [[NSMutableParagraphStyle alloc] init];
  instructionLabelParagraphStyle.lineHeightMultiple = 1.3;
  NSMutableAttributedString *attributedSmartString = [[NSMutableAttributedString alloc] initWithString:smartInstructionsStep0
                                                                                            attributes:@{ NSParagraphStyleAttributeName : instructionLabelParagraphStyle }];
  [attributedSmartString appendAttributedString:[[NSAttributedString alloc] initWithString:smartInstructionsStep1]];
  [attributedSmartString appendAttributedString:attributedMenuString];
  [attributedSmartString appendAttributedString:[[NSAttributedString alloc] initWithString:smartInstructionsStep2]];
  [attributedSmartString appendAttributedString:attributedBookmarkString];
  [attributedSmartString appendAttributedString:[[NSAttributedString alloc] initWithString:smartInstructionsStep3]];

  UIFont *instructionFont = [UIFont systemFontOfSize:kInstructionFontSize weight:UIFontWeightLight];
  smartInstructionLabel.font = instructionFont;
  smartInstructionLabel.attributedText = attributedSmartString;
  smartInstructionLabel.numberOfLines = 0;
  smartInstructionLabel.textAlignment = NSTextAlignmentCenter;
  [smartInstructionLabel sizeToFit];

  // resize the icons to fit with the font, and also vertically align them
  // so that they start at the cap height. Annoyingly, the menu bookmark has some extra padding
  // in the image so we offset that by an additional 2 points.
  menuAttachment.bounds = CGRectMake(0, -(instructionFont.ascender - instructionFont.capHeight)+2, kInstructionFontSize, kInstructionFontSize);
  bookmarkAttachment.bounds = CGRectMake(0, -(instructionFont.ascender - instructionFont.capHeight), kInstructionFontSize, kInstructionFontSize);

  smartInstructionLabel.textColor = [UIColor colorWithWhite:kFontColorValue alpha:1.0];
  [dialogView addSubview:smartInstructionLabel];
  [smartInstructionLabel.topAnchor constraintEqualToAnchor:dialogHeaderView.bottomAnchor
                                             constant:kVerticalSpaceBetweenHeaderViewAndInstructionLabel].active = YES;
  [smartInstructionLabel.leadingAnchor constraintEqualToAnchor:dialogView.leadingAnchor constant:kInstructionTextHorizontalMargin].active = YES;
  [dialogView.trailingAnchor constraintEqualToAnchor:smartInstructionLabel.trailingAnchor constant:kInstructionTextHorizontalMargin].active = YES;

  // build 'or' label
  UILabel *orInstructionLabel = [[UILabel alloc] init];
  orInstructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
  orInstructionLabel.font = [UIFont systemFontOfSize:kInstructionFontSize weight:UIFontWeightBold];
  orInstructionLabel.text = NSLocalizedStringWithDefaultValue(@"DeviceLogin.SmartLogInOrLabel",
                                                              @"FacebookSDK",
                                                              [FBSDKInternalUtility bundleForStrings],
                                                              @"-- OR --",
                                                              @"The 'or' string for smart login instructions");;
  orInstructionLabel.numberOfLines = 0;
  orInstructionLabel.textAlignment = NSTextAlignmentCenter;
  [orInstructionLabel sizeToFit];
  orInstructionLabel.textColor = [UIColor colorWithWhite:kFontColorValue alpha:1.0];
  [dialogView addSubview:orInstructionLabel];
  [orInstructionLabel.topAnchor constraintGreaterThanOrEqualToAnchor:smartInstructionLabel.bottomAnchor
                                                            constant:kVerticalMarginOrLabel].active = YES;

  [orInstructionLabel.leadingAnchor constraintEqualToAnchor:dialogView.leadingAnchor constant:kInstructionTextHorizontalMargin].active = YES;
  [dialogView.trailingAnchor constraintEqualToAnchor:orInstructionLabel.trailingAnchor constant:kInstructionTextHorizontalMargin].active = YES;

  // build the instructions UILabel
  UILabel *instructionLabel = [[UILabel alloc] init];
  instructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
  NSString *localizedFormatString = NSLocalizedStringWithDefaultValue(@"DeviceLogin.LogInPrompt",
                                                                      @"FacebookSDK",
                                                                      [FBSDKInternalUtility bundleForStrings],
                                                                      @"Visit %@ and enter your code.",
                                                                      @"The format string for device login instructions");

  NSString *const deviceLoginURLString = @"facebook.com/device";
  NSString *instructionString = [NSString localizedStringWithFormat:localizedFormatString, deviceLoginURLString];
  NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:instructionString
                                                                                       attributes:@{ NSParagraphStyleAttributeName : instructionLabelParagraphStyle }];
  NSRange range = [instructionString rangeOfString:deviceLoginURLString];
  [attributedString addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:kInstructionFontSize weight:UIFontWeightMedium] range:range];
  instructionLabel.font = instructionFont;
  instructionLabel.attributedText = attributedString;
  instructionLabel.numberOfLines = 0;
  instructionLabel.textAlignment = NSTextAlignmentCenter;
  [instructionLabel sizeToFit];
  instructionLabel.textColor = [UIColor colorWithWhite:kFontColorValue alpha:1.0];
  [dialogView addSubview:instructionLabel];
  [instructionLabel.topAnchor constraintEqualToAnchor:orInstructionLabel.bottomAnchor
                                             constant:kVerticalMarginOrLabel].active = YES;
  [instructionLabel.leadingAnchor constraintEqualToAnchor:dialogView.leadingAnchor constant:kInstructionTextHorizontalMargin].active = YES;
  [dialogView.trailingAnchor constraintEqualToAnchor:instructionLabel.trailingAnchor constant:kInstructionTextHorizontalMargin].active = YES;

  // build the container view for the cancel button.
  UIView *buttonContainerView = [[UIView alloc] init];
  buttonContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  [dialogView addSubview:buttonContainerView];
  [NSLayoutConstraint constraintWithItem:buttonContainerView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:dialogView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0].active = YES;
  [buttonContainerView.heightAnchor constraintEqualToConstant:60].active = YES;
  [buttonContainerView.leadingAnchor constraintEqualToAnchor:dialogView.leadingAnchor
                                                    constant:400].active = YES;
  [dialogView.trailingAnchor constraintEqualToAnchor:buttonContainerView.trailingAnchor
                                            constant:400].active = YES;
  [buttonContainerView.topAnchor constraintEqualToAnchor:instructionLabel.bottomAnchor
                                                constant:kVerticalMarginOrLabel].active = YES;

  // build the cancel button.
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  button.layer.cornerRadius = 4.0;
  button.translatesAutoresizingMaskIntoConstraints = NO;
  [button setTitle:NSLocalizedStringWithDefaultValue(@"LoginButton.CancelLogout",
                                                     @"FacebookSDK",
                                                     [FBSDKInternalUtility bundleForStrings],
                                                     @"Cancel",
                                                     @"The label for the FBSDKLoginButton action sheet to cancel logging out")
          forState:UIControlStateNormal];
  button.titleLabel.font = instructionLabel.font;
  [buttonContainerView addSubview:button];
  [button.leadingAnchor constraintEqualToAnchor:buttonContainerView.leadingAnchor].active = YES;
  [button.trailingAnchor constraintEqualToAnchor:buttonContainerView.trailingAnchor].active = YES;
  [button.topAnchor constraintEqualToAnchor:buttonContainerView.topAnchor].active = YES;
  [button.bottomAnchor constraintEqualToAnchor:buttonContainerView.bottomAnchor].active = YES;
  [button setTitleColor:[UIColor colorWithWhite:kFontColorValue alpha:1] forState:UIControlStateNormal];

  [button addTarget:self action:@selector(_cancelButtonTap:) forControlEvents:UIControlEventPrimaryActionTriggered];
}

- (void)_cancelButtonTap:(id)sender
{
  [self.delegate deviceDialogViewDidCancel:self];
}

@end
