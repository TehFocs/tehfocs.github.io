// DemoLoop 1.3 by TehFocs
// Fullscreen looping video for a "store demo" device (iOS 6 - 8, armv7).
// Video: any .mp4 / .mov / .m4v in /Library/Application Support/DemoLoop/
// (the old folder /var/mobile/Media/DemoLoop is still checked too)
// Hidden gestures: 5 taps top-left = exit + pause, 5 taps top-right = show help.

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/MobileCoreServices.h>

#define VIDEO_DIR     @"/Library/Application Support/DemoLoop"
#define OLD_DIR       @"/var/mobile/Media/DemoLoop"   // legacy location, still supported
#define VERSION_STR   @"1.4"
#define MUTED         YES     // NO = play sound
#define BRIGHTNESS    1.0     // 0.0 - 1.0
#define ROTATE_SIGN   1.0     // for a landscape video: 1.0 or -1.0 flips the direction
#define HELP_AUTOSTART_SECONDS 120.0

// ---------------------------------------------------------------- files

static NSArray *Dirs(void) { return @[VIDEO_DIR, OLD_DIR]; }

// first .mp4/.mov/.m4v (alphabetical) found in the demo folders
static NSString *FindVideoPath(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    // a video chosen from the gallery (copied as DemoLoop-selected.*) wins over everything else
    for (NSString *dir in Dirs()) {
        for (NSString *ext in @[@"mov", @"mp4", @"m4v"]) {
            NSString *p = [dir stringByAppendingPathComponent:[@"DemoLoop-selected." stringByAppendingString:ext]];
            if ([fm fileExistsAtPath:p]) return p;
        }
    }
    for (NSString *dir in Dirs()) {
        NSArray *files = [[fm contentsOfDirectoryAtPath:dir error:nil] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *name in files) {
            if ([name hasPrefix:@"."]) continue;
            NSString *ext = [[name pathExtension] lowercaseString];
            if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"] || [ext isEqualToString:@"m4v"])
                return [dir stringByAppendingPathComponent:name];
        }
    }
    return nil;
}

static BOOL FlagExists(NSString *name) {
    for (NSString *dir in Dirs())
        if ([[NSFileManager defaultManager] fileExistsAtPath:[dir stringByAppendingPathComponent:name]]) return YES;
    return NO;
}

static void ClearFlag(NSString *name) {
    for (NSString *dir in Dirs())
        [[NSFileManager defaultManager] removeItemAtPath:[dir stringByAppendingPathComponent:name] error:nil];
}

// writes the flag to the first folder we are allowed to write to
static void SetFlag(NSString *name) {
    for (NSString *dir in Dirs()) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        if ([@"1" writeToFile:[dir stringByAppendingPathComponent:name] atomically:YES encoding:NSUTF8StringEncoding error:nil]) return;
    }
}

static BOOL DirExists(NSString *p) {
    BOOL isDir = NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:p isDirectory:&isDir] && isDir;
}

// The folder we tell the user to use. If the installer did not create the main
// folder, the app creates the fallback one itself (the app can write to /var/mobile/Media).
static NSString *UsableFolder(BOOL *usedFallback) {
    if (DirExists(VIDEO_DIR)) { if (usedFallback) *usedFallback = NO; return VIDEO_DIR; }
    [[NSFileManager defaultManager] createDirectoryAtPath:OLD_DIR withIntermediateDirectories:YES attributes:nil error:nil];
    if (usedFallback) *usedFallback = YES;
    return OLD_DIR;
}

// where the gallery import puts the video: the main folder if the app can write there, else the fallback
static NSString *ImportFolder(void) {
    if (DirExists(VIDEO_DIR) && [[NSFileManager defaultManager] isWritableFileAtPath:VIDEO_DIR]) return VIDEO_DIR;
    [[NSFileManager defaultManager] createDirectoryAtPath:OLD_DIR withIntermediateDirectories:YES attributes:nil error:nil];
    return OLD_DIR;
}

static void ShowAlert(NSString *title, NSString *message) {
    [[[UIAlertView alloc] initWithTitle:title message:message delegate:nil
                      cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

// ---------------------------------------------------------------- UI helpers

static UIColor *BodyColor(void) { return [UIColor colorWithRed:0.18 green:0.20 blue:0.25 alpha:1]; }
static UIColor *GrayColor(void) { return [UIColor colorWithRed:0.30 green:0.34 blue:0.42 alpha:1]; }

// "Settings" look. iOS 6: our own striped blue-gray pattern (groupTableViewBackgroundColor
// comes out transparent on iOS 6 here, which made the screens overlap). iOS 7+: flat gray.
static UIColor *SettingsBackground(void) {
    static UIColor *cached = nil;
    if (cached) return cached;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        cached = [UIColor colorWithRed:0.937 green:0.937 blue:0.957 alpha:1];
        return cached;
    }
    UIColor *solid = [UIColor colorWithRed:0.80 green:0.83 blue:0.87 alpha:1];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(4, 4), YES, 0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(c, solid.CGColor);
    CGContextFillRect(c, CGRectMake(0, 0, 4, 4));
    CGContextSetFillColorWithColor(c, [UIColor colorWithRed:0.77 green:0.80 blue:0.85 alpha:1].CGColor);
    CGContextFillRect(c, CGRectMake(0, 0, 2, 4));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    cached = img ? [UIColor colorWithPatternImage:img] : solid;
    return cached;
}

static CGFloat TextHeight(NSString *s, UIFont *f, CGFloat w) {
    return ceilf([s sizeWithFont:f constrainedToSize:CGSizeMake(w, 100000) lineBreakMode:NSLineBreakByWordWrapping].height);
}

// adds a wrapped label at (x, *y) and moves *y below it
static UILabel *AddLabel(UIView *parent, NSString *text, UIFont *font, UIColor *color, CGFloat x, CGFloat *y, CGFloat w, CGFloat gapAfter) {
    UILabel *l = [[UILabel alloc] init];
    l.numberOfLines = 0;
    l.lineBreakMode = NSLineBreakByWordWrapping;
    l.backgroundColor = [UIColor clearColor];
    l.font = font;
    l.textColor = color;
    l.text = text;
    CGFloat h = TextHeight(text, font, w);
    l.frame = CGRectMake(x, *y, w, h);
    [parent addSubview:l];
    *y += h + gapAfter;
    return l;
}

static UIView *MakeCard(void) {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 10;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [UIColor colorWithWhite:0.72 alpha:1].CGColor;
    return card;
}

@interface DLButton : UIButton
@property (nonatomic, strong) CAGradientLayer *grad;
+ (DLButton *)blueButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action;
@end

@implementation DLButton
+ (DLButton *)blueButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action {
    DLButton *b = [DLButton buttonWithType:UIButtonTypeCustom];
    b.layer.cornerRadius = 9;
    b.layer.masksToBounds = YES;
    b.layer.borderWidth = 1;
    b.layer.borderColor = [UIColor colorWithRed:0.08 green:0.27 blue:0.60 alpha:1].CGColor;
    b.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    b.titleLabel.textAlignment = NSTextAlignmentCenter;
    b.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    b.titleLabel.numberOfLines = 2;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.grad) {
        self.grad = [CAGradientLayer layer];
        self.grad.colors = @[(id)[UIColor colorWithRed:0.40 green:0.63 blue:0.95 alpha:1].CGColor,
                             (id)[UIColor colorWithRed:0.14 green:0.39 blue:0.82 alpha:1].CGColor];
        [self.layer insertSublayer:self.grad atIndex:0];
    }
    self.grad.frame = self.bounds;
}
- (void)setHighlighted:(BOOL)h {
    [super setHighlighted:h];
    self.alpha = h ? 0.65 : 1.0;
}
@end

// ---------------------------------------------------------------- help texts

static NSArray *DetailSections(int ru, NSString *folder) {
    if (ru) {
        return @[
          @[@"Папка с видео",
            [NSString stringWithFormat:@"%@/\nТакже проверяется: /var/mobile/Media/DemoLoop/\nПодойдёт любой файл .mp4, .mov или .m4v. Если файлов несколько, играет первый по имени. Копируй через iFile, Filza или SFTP.", folder]],
          @[@"Видео из галереи",
            @"Кнопка 'Выбрать видео из галереи' копирует видео в папку под именем DemoLoop-selected.mov (или .mp4) и запускает его. Такой файл главнее остальных; удали его, чтобы вернуться к другим файлам. Нужно свободное место, равное размеру видео. Если качество после выбора хуже оригинала, положи файл в папку вручную."],
          @[@"Автозапуск",
            @"Фоновая служба стартует при включении, ждёт около 20 секунд, пока загрузится домашний экран, и дальше держит DemoLoop запущенным, пока в папке есть видео. Для этого нужен бесплатный пакет 'Open' из Cydia. Если нажать Home, приложение закроется и вернётся примерно через 5 секунд."],
          @[@"Необязательные файлы-флаги",
            @"Создай пустой файл в папке с видео:\nfill - обрезать видео и закрыть весь экран (без чёрных полос).\npause - создаётся жестом выхода; удали его или нажми на иконку Demo Loop, чтобы продолжить."],
          @[@"Управление",
            @"5 тапов в левом верхнем углу: выйти и поставить демо на паузу.\n5 тапов в правом верхнем углу: показать эту инструкцию.\nЗвук по умолчанию выключен."],
          @[@"Советы",
            @"Настройки > Основные > Автоблокировка > Никогда. Отключи пароль. Держи устройство на зарядке. Горизонтальное видео поворачивается на весь экран - положи устройство на бок."],
          @[@"Рекомендуемый размер видео",
            @"H.264 (MP4 / MOV), 24-30 кадров/с, вертикальное:\n\niPhone 3GS: 320x480\niPhone 4, 4S, iPod touch 4: 640x960\niPhone 5, 5c, iPod touch 5: 640x1136\niPad 2, iPad mini: 768x1024\niPad 3, iPad 4: 1080x1440 (экран 1536x2048, но видео больше 1080p может не воспроизводиться)\n\nЕсли пропорции другие, по краям будут чёрные полосы (или обрезка, если есть файл 'fill')."],
          @[@"Устройства",
            @"32-битные, iOS 6.0 - 8.4.1: iPhone 3GS, 4, 4S, 5, 5c; iPod touch 4, 5; iPad 2, 3, 4; iPad mini."]
        ];
    }
    return @[
      @[@"Video folder",
        [NSString stringWithFormat:@"%@/\nAlso checked: /var/mobile/Media/DemoLoop/\nAny .mp4, .mov or .m4v file. If there are several, the first one by name is played. Copy files with iFile, Filza or SFTP.", folder]],
      @[@"Video from Photos",
        @"The 'Choose video from Photos' button copies the video into the folder as DemoLoop-selected.mov (or .mp4) and plays it. This file has priority over all others; delete it to go back to the other files. You need free space equal to the video size. If the quality after picking is worse than the original, copy the file into the folder yourself."],
      @[@"Autostart",
        @"A background service starts at boot, waits about 20 seconds for the home screen and then keeps DemoLoop running while a video is in the folder. It needs the free 'Open' package from Cydia. If you press Home, the app closes and comes back in about 5 seconds."],
      @[@"Optional flag files",
        @"Create an empty file in the video folder:\nfill - crop the video to cover the whole screen (no black bars).\npause - created by the exit gesture; delete it, or tap the Demo Loop icon, to resume."],
      @[@"Controls",
        @"5 taps top-left: exit and pause the demo.\n5 taps top-right: show this help.\nSound is muted by default."],
      @[@"Tips",
        @"Settings > General > Auto-Lock > Never. Turn the passcode off. Keep the device on a charger. A landscape video is rotated to fill the portrait screen - place the device on its side."],
      @[@"Recommended video size",
        @"H.264 (MP4 / MOV), 24-30 fps, portrait:\n\niPhone 3GS: 320x480\niPhone 4, 4S, iPod touch 4: 640x960\niPhone 5, 5c, iPod touch 5: 640x1136\niPad 2, iPad mini: 768x1024\niPad 3, iPad 4: 1080x1440 (the screen is 1536x2048, but video larger than 1080p may not play)\n\nA different aspect ratio is fitted with black bars (or cropped if a 'fill' file exists)."],
      @[@"Devices",
        @"32-bit, iOS 6.0 - 8.4.1: iPhone 3GS, 4, 4S, 5, 5c; iPod touch 4, 5; iPad 2, 3, 4; iPad mini."]
    ];
}

// ---------------------------------------------------------------- help screen

@interface DLHelpView : UIView
@property (nonatomic, copy) void (^onStart)(void);
@property (nonatomic, copy) void (^onChoose)(void);
@property (nonatomic, strong) UIView *chooserView;
@property (nonatomic, copy) NSString *folder;
@property (nonatomic, assign) BOOL fallback;
@property (nonatomic, strong) UIScrollView *mainScroll;
@property (nonatomic, strong) UIScrollView *detailScroll;
- (instancetype)initWithFrame:(CGRect)f folder:(NSString *)folder fallback:(BOOL)fb canStart:(BOOL)canStart chooser:(BOOL)chooser;
@end

@implementation DLHelpView

- (instancetype)initWithFrame:(CGRect)f folder:(NSString *)folder fallback:(BOOL)fb canStart:(BOOL)canStart chooser:(BOOL)chooser {
    if ((self = [super initWithFrame:f])) {
        self.folder = folder;
        self.fallback = fb;
        self.backgroundColor = SettingsBackground();
        self.opaque = YES;
        self.mainScroll = [[UIScrollView alloc] initWithFrame:self.bounds];
        self.mainScroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.mainScroll.alwaysBounceVertical = YES;
        [self addSubview:self.mainScroll];
        [self buildMainCanStart:canStart];
        if (chooser) [self buildChooser];
    }
    return self;
}

- (NSString *)mainBody:(int)ru {
    NSString *note = @"";
    if (self.fallback) {
        note = ru
          ? [NSString stringWithFormat:@"Внимание: установщик не создал папку %@, поэтому приложение создало другую. Используй её.\n\n", VIDEO_DIR]
          : [NSString stringWithFormat:@"Note: the installer did not create %@, so the app created this folder instead. Use it.\n\n", VIDEO_DIR];
    }
    if (ru) {
        return [note stringByAppendingFormat:
          @"DemoLoop крутит видео на весь экран по кругу, как демо-аппарат в магазине.\n\n"
          @"1. Скопируй видео (.mp4, .mov или .m4v) в папку:\n%@/\n(через iFile или Filza)\n\n"
          @"2. Видео запустится само через несколько секунд и будет играть по кругу.\n\n"
          @"3. Выход из демо: 5 быстрых тапов в левом верхнем углу экрана.\n"
          @"Показать эту инструкцию снова: 5 тапов в правом верхнем углу.", self.folder];
    }
    return [note stringByAppendingFormat:
      @"DemoLoop plays a fullscreen video in a loop, like a store demo unit.\n\n"
      @"1. Copy your video (.mp4, .mov or .m4v) into this folder:\n%@/\n(use iFile or Filza)\n\n"
      @"2. The video starts by itself within a few seconds and loops forever.\n\n"
      @"3. Exit the demo: tap 5 times in the top-left corner of the screen.\n"
      @"Show this help again: tap 5 times in the top-right corner.", self.folder];
}

- (CGFloat)addCardForLang:(int)ru x:(CGFloat)X y:(CGFloat)y w:(CGFloat)W {
    AddLabel(self.mainScroll, ru ? @"РУССКИЙ" : @"ENGLISH", [UIFont boldSystemFontOfSize:14], GrayColor(), X + 12, &y, W - 24, 6);
    CGFloat pad = 14, tw = W - 2 * pad, cy = pad;
    UIView *card = MakeCard();
    AddLabel(card, [self mainBody:ru], [UIFont systemFontOfSize:15], BodyColor(), pad, &cy, tw, 14);
    DLButton *b = [DLButton blueButtonWithTitle:(ru ? @"Подробная инструкция и размеры видео" : @"Detailed guide & video sizes")
                                         target:self action:(ru ? @selector(detailsRU) : @selector(detailsEN))];
    b.frame = CGRectMake(pad, cy, tw, 52);
    [card addSubview:b];
    cy += 52 + pad;
    card.frame = CGRectMake(X, y, W, cy);
    [self.mainScroll addSubview:card];
    return y + cy + 22;
}

- (void)buildMainCanStart:(BOOL)canStart {
    CGFloat W = MIN(self.bounds.size.width - 32, 560);
    CGFloat X = floorf((self.bounds.size.width - W) / 2);
    CGFloat y = 28;
    UILabel *t = AddLabel(self.mainScroll, @"DemoLoop", [UIFont boldSystemFontOfSize:28], BodyColor(), X, &y, W, 2);
    t.textAlignment = NSTextAlignmentCenter;
    UILabel *v = AddLabel(self.mainScroll, @"v" VERSION_STR @"  by TehFocs", [UIFont systemFontOfSize:13], GrayColor(), X, &y, W, 16);
    v.textAlignment = NSTextAlignmentCenter;
    if (canStart) {
        DLButton *s = [DLButton blueButtonWithTitle:@"Start demo  /  Начать демо" target:self action:@selector(startTapped)];
        s.frame = CGRectMake(X, y, W, 46);
        [self.mainScroll addSubview:s];
        y += 46 + 12;
    }
    DLButton *c = [DLButton blueButtonWithTitle:@"Choose video from Photos  /  Выбрать видео из галереи" target:self action:@selector(chooseTapped)];
    c.frame = CGRectMake(X, y, W, 52);
    [self.mainScroll addSubview:c];
    y += 52 + 20;
    y = [self addCardForLang:0 x:X y:y w:W];
    y = [self addCardForLang:1 x:X y:y w:W];
    self.mainScroll.contentSize = CGSizeMake(self.bounds.size.width, y + 10);
}

- (void)startTapped { if (self.onStart) self.onStart(); }
- (void)chooseTapped { if (self.onChoose) self.onChoose(); }

// first-launch screen: automatic (pick from Photos) or manual (instructions)
- (void)buildChooser {
    UIScrollView *s = [[UIScrollView alloc] initWithFrame:self.bounds];
    s.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    s.alwaysBounceVertical = YES;
    s.backgroundColor = SettingsBackground();
    s.opaque = YES;

    CGFloat W = MIN(self.bounds.size.width - 32, 560);
    CGFloat X = floorf((self.bounds.size.width - W) / 2);
    CGFloat y = 36;
    UILabel *t = AddLabel(s, @"DemoLoop", [UIFont boldSystemFontOfSize:32], BodyColor(), X, &y, W, 2);
    t.textAlignment = NSTextAlignmentCenter;
    UILabel *v = AddLabel(s, @"v" VERSION_STR @"  by TehFocs", [UIFont systemFontOfSize:13], GrayColor(), X, &y, W, 22);
    v.textAlignment = NSTextAlignmentCenter;
    UILabel *q = AddLabel(s, @"How do you want to set up the demo?\nКак настроить демо?", [UIFont boldSystemFontOfSize:17], BodyColor(), X, &y, W, 20);
    q.textAlignment = NSTextAlignmentCenter;

    DLButton *a = [DLButton blueButtonWithTitle:@"Automatic\nChoose a video from Photos\n\nАвтоматически\nВыбрать видео из галереи"
                                         target:self action:@selector(chooseTapped)];
    a.titleLabel.numberOfLines = 0;
    a.frame = CGRectMake(X, y, W, 128);
    [s addSubview:a];
    y += 128 + 14;

    DLButton *m = [DLButton blueButtonWithTitle:@"Manual\nPut the video in the folder yourself (instructions)\n\nВручную\nПоложить видео в папку самому (инструкция)"
                                         target:self action:@selector(manualTapped)];
    m.titleLabel.numberOfLines = 0;
    m.frame = CGRectMake(X, y, W, 128);
    [s addSubview:m];
    y += 128 + 18;

    UILabel *n = AddLabel(s, @"Show this screen again: 5 taps in the top-right corner.\nСнова открыть: 5 тапов в правом верхнем углу.",
                          [UIFont systemFontOfSize:13], GrayColor(), X, &y, W, 10);
    n.textAlignment = NSTextAlignmentCenter;

    s.contentSize = CGSizeMake(self.bounds.size.width, y + 10);
    [self addSubview:s];
    self.chooserView = s;
}

- (void)manualTapped {
    [self.chooserView removeFromSuperview];
    self.chooserView = nil;
}
- (void)detailsEN { [self showDetails:0]; }
- (void)detailsRU { [self showDetails:1]; }

- (void)backTapped {
    [self.detailScroll removeFromSuperview];
    self.detailScroll = nil;
}

- (void)showDetails:(int)ru {
    if (self.detailScroll) return;
    UIScrollView *s = [[UIScrollView alloc] initWithFrame:self.bounds];
    s.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    s.alwaysBounceVertical = YES;
    s.backgroundColor = SettingsBackground();
    s.opaque = YES;

    CGFloat W = MIN(self.bounds.size.width - 32, 560);
    CGFloat X = floorf((self.bounds.size.width - W) / 2);
    CGFloat y = 22;
    DLButton *back = [DLButton blueButtonWithTitle:(ru ? @"< Назад" : @"< Back") target:self action:@selector(backTapped)];
    back.frame = CGRectMake(X, y, 110, 40);
    [s addSubview:back];
    y += 40 + 14;
    AddLabel(s, ru ? @"Подробная инструкция" : @"Detailed guide", [UIFont boldSystemFontOfSize:24], BodyColor(), X, &y, W, 14);

    for (NSArray *sec in DetailSections(ru, self.folder)) {
        CGFloat pad = 14, tw = W - 2 * pad, cy = pad;
        UIView *card = MakeCard();
        AddLabel(card, sec[0], [UIFont boldSystemFontOfSize:16], [UIColor blackColor], pad, &cy, tw, 6);
        AddLabel(card, sec[1], [UIFont systemFontOfSize:15], BodyColor(), pad, &cy, tw, pad);
        card.frame = CGRectMake(X, y, W, cy);
        [s addSubview:card];
        y += cy + 14;
    }
    s.contentSize = CGSizeMake(self.bounds.size.width, y + 20);
    [self addSubview:s];
    self.detailScroll = s;
}

@end

// ---------------------------------------------------------------- player

@interface DLController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverControllerDelegate>
@property (nonatomic, strong) UIPopoverController *popover;
@property (nonatomic, strong) UIView *busyView;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) DLHelpView *helpView;
@property (nonatomic, strong) NSTimer *watchdog;
@property (nonatomic, assign) BOOL landscapeVideo;
@property (nonatomic, assign) BOOL helpWaitsForUser;
@end

@implementation DLController

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)shouldAutorotate { return NO; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }

- (void)addZone:(CGRect)f action:(SEL)a mask:(UIViewAutoresizing)m {
    UIView *z = [[UIView alloc] initWithFrame:f];
    z.backgroundColor = [UIColor clearColor];
    z.autoresizingMask = m;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:a];
    tap.numberOfTapsRequired = 5;
    [z addGestureRecognizer:tap];
    [self.view addSubview:z];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    // secret zones: top-left = exit, top-right = help
    [self addZone:CGRectMake(0, 0, 90, 90) action:@selector(secretExit) mask:UIViewAutoresizingFlexibleRightMargin];
    [self addZone:CGRectMake(self.view.bounds.size.width - 90, 0, 90, 90) action:@selector(helpGesture) mask:UIViewAutoresizingFlexibleLeftMargin];

    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [UIScreen mainScreen].brightness = BRIGHTNESS;

    // first launch: show the instructions once, even if a video is already there
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL seen = [ud boolForKey:@"HelpSeen"];
    if (!seen) { [ud setBool:YES forKey:@"HelpSeen"]; [ud synchronize]; }

    if (!seen)                 [self showHelpCanStart:(FindVideoPath() != nil) chooser:YES];  // first launch: choose Automatic / Manual
    else if (!FindVideoPath()) [self showHelpCanStart:NO chooser:NO];
    else                       [self startPlayback];

    self.watchdog = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
}

// ---- help

- (void)showHelpCanStart:(BOOL)canStart { [self showHelpCanStart:canStart chooser:NO]; }

- (void)showHelpCanStart:(BOOL)canStart chooser:(BOOL)chooser {
    if (self.helpView) return;
    BOOL fallback = NO;
    NSString *folder = UsableFolder(&fallback);
    DLHelpView *h = [[DLHelpView alloc] initWithFrame:self.view.bounds folder:folder fallback:fallback canStart:canStart chooser:chooser];
    h.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    __weak DLController *wself = self;
    h.onStart = ^{ [wself hideHelp]; };
    h.onChoose = ^{ [wself chooseVideo]; };
    [self.view addSubview:h];
    self.helpView = h;
    self.helpWaitsForUser = canStart;
    if (canStart) [self performSelector:@selector(hideHelp) withObject:nil afterDelay:HELP_AUTOSTART_SECONDS];
}

- (void)closeHelpView {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideHelp) object:nil];
    [self.helpView removeFromSuperview];
    self.helpView = nil;
    self.helpWaitsForUser = NO;
}

- (void)hideHelp {
    [self closeHelpView];
    if (!self.player && FindVideoPath()) [self startPlayback];
}

- (void)helpGesture { [self showHelpCanStart:YES]; }

// ---- gallery import

- (void)rearmAutostart {
    if (self.helpView && self.helpWaitsForUser)
        [self performSelector:@selector(hideHelp) withObject:nil afterDelay:HELP_AUTOSTART_SECONDS];
}

- (void)chooseVideo {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        ShowAlert(@"Photos not available / Галерея недоступна", @"Could not open the photo library.\nНе удалось открыть галерею.");
        return;
    }
    // the help screen must not close (and start the old video) while the picker is open
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideHelp) object:nil];

    UIImagePickerController *p = [[UIImagePickerController alloc] init];
    p.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    p.mediaTypes = @[(__bridge NSString *)kUTTypeMovie];
    p.allowsEditing = NO;
    p.videoQuality = UIImagePickerControllerQualityTypeHigh;
    p.delegate = self;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UIPopoverController *pop = [[UIPopoverController alloc] initWithContentViewController:p];
        pop.delegate = self;
        self.popover = pop;
        CGRect r = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
        [pop presentPopoverFromRect:r inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else {
        [self presentViewController:p animated:YES completion:nil];
    }
}

- (void)dismissPickerThen:(void (^)(void))block {
    if (self.popover) {
        [self.popover dismissPopoverAnimated:YES];
        self.popover = nil;
        if (block) block();
    } else {
        [self dismissViewControllerAnimated:YES completion:block];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSURL *url = info[UIImagePickerControllerMediaURL];
    [self dismissPickerThen:^{
        if (url) [self importVideoAtURL:url];
        else {
            ShowAlert(@"No video / Нет видео", @"The picker did not return a video file.\nГалерея не вернула видеофайл.");
            [self rearmAutostart];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissPickerThen:^{ [self rearmAutostart]; }];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)pc {
    self.popover = nil;
    [self rearmAutostart];
}

- (void)showBusy {
    if (self.busyView) return;
    UIView *v = [[UIView alloc] initWithFrame:self.view.bounds];
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    v.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    UIActivityIndicatorView *a = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    a.center = CGPointMake(v.bounds.size.width / 2, v.bounds.size.height / 2 - 24);
    a.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                         UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [a startAnimating];
    [v addSubview:a];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, v.bounds.size.height / 2 + 14, v.bounds.size.width, 24)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    l.backgroundColor = [UIColor clearColor];
    l.textColor = [UIColor whiteColor];
    l.textAlignment = NSTextAlignmentCenter;
    l.font = [UIFont systemFontOfSize:16];
    l.text = @"Copying video...  /  Копирую видео...";
    [v addSubview:l];
    [self.view addSubview:v];
    self.busyView = v;
}

- (void)hideBusy {
    [self.busyView removeFromSuperview];
    self.busyView = nil;
}

// copies the chosen video into the demo folder as DemoLoop-selected.<ext> and plays it
- (void)importVideoAtURL:(NSURL *)url {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = [url path];
    NSString *dst = ImportFolder();

    unsigned long long need = [[[fm attributesOfItemAtPath:src error:nil] objectForKey:NSFileSize] unsignedLongLongValue];
    unsigned long long avail = [[[fm attributesOfFileSystemForPath:dst error:nil] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
    if (avail > 0 && need + 30ULL * 1024 * 1024 > avail) {
        ShowAlert(@"Not enough free space / Мало места",
                  [NSString stringWithFormat:@"The video needs %llu MB, free: %llu MB.\nНужно %llu МБ, свободно: %llu МБ.",
                   need >> 20, avail >> 20, need >> 20, avail >> 20]);
        [self rearmAutostart];
        return;
    }

    NSString *ext = [[src pathExtension] lowercaseString];
    if (![@[@"mov", @"mp4", @"m4v"] containsObject:ext]) ext = @"mov";
    NSString *part = [dst stringByAppendingPathComponent:@"DemoLoop-selected.part"];
    NSString *final = [dst stringByAppendingPathComponent:[@"DemoLoop-selected." stringByAppendingString:ext]];

    [self showBusy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *f = [NSFileManager defaultManager];
        NSError *err = nil;
        [f removeItemAtPath:part error:nil];
        BOOL ok = [f copyItemAtPath:src toPath:part error:&err];   // .part is ignored until the copy is complete
        if (ok) {
            for (NSString *e in @[@"mov", @"mp4", @"m4v"])          // drop the previous selection
                [f removeItemAtPath:[dst stringByAppendingPathComponent:[@"DemoLoop-selected." stringByAppendingString:e]] error:nil];
            ok = [f moveItemAtPath:part toPath:final error:&err];
        }
        // clean up the picker's temporary copy, but never touch a file in the photo library itself
        if (ok && [src rangeOfString:@"/tmp/"].location != NSNotFound && [src rangeOfString:@"/DCIM/"].location == NSNotFound)
            [f removeItemAtPath:src error:nil];
        NSString *msg = err ? [err localizedDescription] : @"";
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideBusy];
            if (ok) {
                ClearFlag(@"pause");
                [self closeHelpView];
                [self startPlayback];
            } else {
                [[NSFileManager defaultManager] removeItemAtPath:part error:nil];
                ShowAlert(@"Could not copy the video / Не удалось скопировать видео", msg);
                [self rearmAutostart];
            }
        });
    });
}

// ---- playback

// iOS 7+: AVPlayer.muted. iOS 6: silence the audio tracks with an audio mix.
- (void)muteItem:(AVPlayerItem *)item {
    if ([self.player respondsToSelector:@selector(setMuted:)]) {
        [self.player setMuted:YES];
        return;
    }
    NSMutableArray *params = [NSMutableArray array];
    for (AVAssetTrack *t in [item.asset tracksWithMediaType:AVMediaTypeAudio]) {
        AVMutableAudioMixInputParameters *p = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:t];
        [p setVolume:0.0f atTime:kCMTimeZero];
        [params addObject:p];
    }
    AVMutableAudioMix *mix = [AVMutableAudioMix audioMix];
    mix.inputParameters = params;
    item.audioMix = mix;
}

- (void)startPlayback {
    NSString *path = FindVideoPath();
    if (!path) { [self showHelpCanStart:NO]; return; }

    [self stopPlayback];

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:path]];
    self.player = [AVPlayer playerWithPlayerItem:item];
    if (MUTED) [self muteItem:item];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(itemEnded:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    [nc addObserver:self selector:@selector(itemFailed:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:item];

    // portrait or landscape video?
    self.landscapeVideo = NO;
    NSArray *tracks = [item.asset tracksWithMediaType:AVMediaTypeVideo];
    if (tracks.count) {
        AVAssetTrack *t = tracks[0];
        CGSize sz = CGSizeApplyAffineTransform(t.naturalSize, t.preferredTransform);
        self.landscapeVideo = fabs(sz.width) > fabs(sz.height);
    }

    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    BOOL fill = FlagExists(@"fill");
    self.playerLayer.videoGravity = fill ? AVLayerVideoGravityResizeAspectFill : AVLayerVideoGravityResizeAspect;
    [self.view.layer insertSublayer:self.playerLayer atIndex:0];
    [self layoutPlayerLayer];

    [self.player play];
}

- (void)stopPlayback {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.player pause];
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
    self.player = nil;
}

- (void)layoutPlayerLayer {
    CGRect b = self.view.bounds;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (self.landscapeVideo) {
        self.playerLayer.bounds = CGRectMake(0, 0, b.size.height, b.size.width);
        self.playerLayer.position = CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b));
        self.playerLayer.affineTransform = CGAffineTransformMakeRotation(M_PI_2 * ROTATE_SIGN);
    } else {
        self.playerLayer.affineTransform = CGAffineTransformIdentity;
        self.playerLayer.frame = b;
    }
    [CATransaction commit];
}

- (void)itemEnded:(NSNotification *)n {
    [self.player seekToTime:kCMTimeZero];
    [self.player play];
}

- (void)itemFailed:(NSNotification *)n {
    [self startPlayback];
}

// every 3 s: if playback stopped or the video appeared, (re)start it
- (void)tick {
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    if (self.helpView) {
        // "no video yet" help closes by itself as soon as a video shows up
        if (!self.helpWaitsForUser && FindVideoPath()) [self hideHelp];
        return;
    }
    if (!self.player) { [self startPlayback]; return; }
    if (self.player.currentItem.status == AVPlayerItemStatusFailed ||
        self.player.status == AVPlayerStatusFailed) {
        [self startPlayback];
    } else if (self.player.rate == 0.0f) {
        [self.player play];
    }
}

- (void)secretExit {
    SetFlag(@"pause");
    exit(0);
}

@end

@interface DLAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation DLAppDelegate

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    // manual launch from the icon = resume demo mode
    ClearFlag(@"pause");
    app.idleTimerDisabled = YES;

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[DLController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)app {
    app.idleTimerDisabled = YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([DLAppDelegate class]));
    }
}
