// pinsidebar - add/remove/list items in the Finder sidebar Favourites.
// Uses the deprecated-but-functional LSSharedFileList API (same as `mysides`).
// Build: clang -fobjc-arc -O2 -framework Foundation -framework CoreServices pinsidebar.m -o pinsidebar
//
//   pinsidebar list             print the POSIX path of every Favourites item
//   pinsidebar toggle <path>…   add each path; if already present, remove it
#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

typedef struct OpaqueLSSharedFileListRef *LSSharedFileListRef;
typedef struct OpaqueLSSharedFileListItemRef *LSSharedFileListItemRef;

extern CFStringRef kLSSharedFileListFavoriteItems;
extern LSSharedFileListItemRef kLSSharedFileListItemLast;
extern LSSharedFileListRef LSSharedFileListCreate(CFAllocatorRef inAllocator, CFStringRef inListType, CFTypeRef listOptions);
extern CFArrayRef LSSharedFileListCopySnapshot(LSSharedFileListRef inList, UInt32 *outSnapshotSeed);
extern CFURLRef LSSharedFileListItemCopyResolvedURL(LSSharedFileListItemRef inItem, UInt32 inFlags, CFErrorRef *outError);
extern LSSharedFileListItemRef LSSharedFileListInsertItemURL(LSSharedFileListRef inList, LSSharedFileListItemRef insertAfterThisItem, CFStringRef inDisplayName, IconRef inIconRef, CFURLRef inURL, CFDictionaryRef inPropertiesToSet, CFArrayRef inPropertiesToClear);
extern OSStatus LSSharedFileListItemRemove(LSSharedFileListRef inList, LSSharedFileListItemRef inItem);

enum { kResolveNoUI = 0x1, kResolveNoMount = 0x2 };

static NSString *itemPath(LSSharedFileListItemRef item) {
    CFURLRef url = LSSharedFileListItemCopyResolvedURL(item, kResolveNoUI | kResolveNoMount, NULL);
    if (!url) return nil;
    NSString *path = [(__bridge NSURL *)url path];
    CFRelease(url);
    // standardize so both sides of a comparison agree (e.g. /private/tmp vs /tmp)
    return [path stringByStandardizingPath];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: pinsidebar list | pinsidebar toggle <path>...\n");
            return 2;
        }
        LSSharedFileListRef favs = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListFavoriteItems, NULL);
        if (!favs) { fprintf(stderr, "error: cannot open Favourites list\n"); return 1; }

        NSString *cmd = [NSString stringWithUTF8String:argv[1]];
        UInt32 seed = 0;
        NSArray *snapshot = CFBridgingRelease(LSSharedFileListCopySnapshot(favs, &seed));

        if ([cmd isEqualToString:@"list"]) {
            for (id obj in snapshot) {
                NSString *p = itemPath((__bridge LSSharedFileListItemRef)obj);
                printf("%s\n", p ? p.UTF8String : "(unresolvable)");
            }
            return 0;
        }

        if (![cmd isEqualToString:@"toggle"] || argc < 3) {
            fprintf(stderr, "usage: pinsidebar list | pinsidebar toggle <path>...\n");
            return 2;
        }

        int rc = 0;
        for (int i = 2; i < argc; i++) {
            NSString *raw = [NSString stringWithUTF8String:argv[i]];
            NSString *path = [raw stringByStandardizingPath];
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                fprintf(stderr, "skip (missing): %s\n", path.UTF8String);
                continue;
            }
            LSSharedFileListItemRef existing = NULL;
            for (id obj in snapshot) {
                NSString *p = itemPath((__bridge LSSharedFileListItemRef)obj);
                if (p && [p isEqualToString:path]) { existing = (__bridge LSSharedFileListItemRef)obj; break; }
            }
            if (existing) {
                OSStatus st = LSSharedFileListItemRemove(favs, existing);
                if (st == noErr) printf("removed %s\n", path.UTF8String);
                else { fprintf(stderr, "error removing %s (%d)\n", path.UTF8String, (int)st); rc = 1; }
            } else {
                NSURL *url = [NSURL fileURLWithPath:path];
                LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(favs, kLSSharedFileListItemLast, NULL, NULL, (__bridge CFURLRef)url, NULL, NULL);
                if (item) { printf("added %s\n", path.UTF8String); CFRelease(item); }
                else { fprintf(stderr, "error adding %s\n", path.UTF8String); rc = 1; }
            }
        }
        return rc;
    }
}
