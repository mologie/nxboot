#import "PayloadStorage.h"

// for data migration from v0.1
#import <CoreData/CoreData.h>
#import "FLBootProfile+CoreDataClass.h"

NSNotificationName const NXBootPayloadStorageChangedExternally = @"NXBootPayloadStorageChangedExternally";
static NSString *const NXBootPayloadsExplicitOrder = @"NXBootPayloadsExplicitOrder";

@implementation Payload

- (instancetype)initWithPath:(NSString *)path {
    if (![[NSFileManager defaultManager] isReadableFileAtPath:path]) {
        return nil;
    }
    self = [super init];
    if (self) {
        self.path = path;
    }
    return self;
}

- (NSData *)data {
    return [NSData dataWithContentsOfFile:self.path];
}

- (NSString *)displayName {
    return [self.path.lastPathComponent stringByDeletingPathExtension];
}

- (NSDictionary<NSFileAttributeKey, id> *)attribs {
    return [[NSFileManager defaultManager] attributesOfItemAtPath:self.path error:nil];
}

- (unsigned long long)fileSize {
    return self.attribs.fileSize;
}

- (NSDate *)fileDate {
    return self.attribs.fileModificationDate;
}

- (NSUInteger)hash {
    return [self.path hash];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    } else if ([object isKindOfClass:Payload.class]) {
        Payload *payload = (Payload *)object;
        return [self.path isEqualToString:payload.path];
    } else {
        return NO;
    }
}

@end

@interface PayloadStorage ()
@property (nonatomic, strong) NSUserDefaults *userDefaults;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSString *payloadsDir;
@end

@implementation PayloadStorage

+ (instancetype)sharedPayloadStorage {
    static PayloadStorage *instance = nil;
    if (!instance) {
        static dispatch_once_t once = 0;
        dispatch_once(&once, ^{
            instance = [[PayloadStorage alloc] init];
        });
    }
    return instance;
}

+ (NSData *)relocator {
    static NSData *data = nil;
    if (!data) {
        static dispatch_once_t once = 0;
        dispatch_once(&once, ^{
            NSURL *url = [[NSBundle mainBundle] URLForResource:@"intermezzo" withExtension:@"bin"];
            if (!url) {
                abort();
            }
            data = [NSData dataWithContentsOfURL:url options:0 error:nil];
            if (!data) {
                abort();
            }
        });
    }
    return data;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.userDefaults = [NSUserDefaults standardUserDefaults];
        self.fileManager = [NSFileManager defaultManager];

        NSURL *documentsDir = [self.fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
        self.payloadsDir = [documentsDir URLByAppendingPathComponent:@"Payloads" isDirectory:YES].path;

        NSError *error = nil;
        if ([self.fileManager createDirectoryAtPath:self.payloadsDir withIntermediateDirectories:NO attributes:nil error:&error]) {
            NSLog(@"[PayloadStorage] running migration");
            [self migrateFromCoreData];
        } else if (![error.domain isEqual:NSCocoaErrorDomain] || error.code != NSFileWriteFileExistsError) {
            NSLog(@"[PayloadStorage] error creating Payloads directory: %@", error);
        }
    }
    return self;
}

- (void)migrateFromCoreData {
    if (@available(iOS 10, *)) {
        NSPersistentContainer *pc = [[NSPersistentContainer alloc] initWithName:@"Model"];
        [pc loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *storeDescription, NSError *error) {
            if (error) {
                NSLog(@"[PayloadStorage] persistent storage setup error: %@", error);
                return;
            }
            NSLog(@"[PayloadStorage] migration started");
            NSFetchRequest *fr = [FLBootProfile fetchRequest];
            fr.predicate = [NSPredicate predicateWithFormat:@"isDemoProfile = nil"];
            NSArray<FLBootProfile *> *results = [pc.viewContext executeFetchRequest:fr error:&error];
            NSCharacterSet *charsToReplace = [NSCharacterSet characterSetWithCharactersInString:@"/:"];
            if (!results) {
                NSLog(@"[PayloadStorage] migration query failed: %@", error);
                return;
            }
            for (FLBootProfile *legacyProfile in results) {
                if (![legacyProfile.relocatorName isEqualToString:@"intermezzo.bin"]) {
                    // Coreboot/CBFS is no longer supported since version 0.2, and we cannot migrate those payloads.
                    // This is not relevant in practice as L4T and Lakka are now booted through Hekate.
                    // Users that require this feature can downgrade back to 0.1 and continue to use it normally.
                    NSLog(@"[PayloadStorage] skipping migration of %@ because relocator is unsupported: %@", legacyProfile.name, legacyProfile.relocatorName);
                    continue;
                }
                if (!legacyProfile.payloadBin) {
                    NSLog(@"[PayloadStorage] skipping migration of %@ because binary payload data is not set", legacyProfile.name);
                    continue;
                }
                NSString *fileName = [[legacyProfile.name componentsSeparatedByCharactersInSet:charsToReplace] componentsJoinedByString:@"_"];
                if ([fileName hasPrefix:@"."]) {
                    fileName = [fileName substringFromIndex:1];
                }
                if (fileName.length == 0) {
                    fileName = @"Imported";
                }
                NSString *filePath = [[self.payloadsDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"bin"];
                for (int suffix = 2; [self.fileManager fileExistsAtPath:filePath]; suffix++) {
                    NSString *altName = [NSString stringWithFormat:@"%@ (%d)", fileName, suffix];
                    filePath = [[self.payloadsDir stringByAppendingPathComponent:altName] stringByAppendingPathExtension:@"bin"];
                }
                if ([legacyProfile.payloadBin writeToFile:filePath options:0 error:&error]) {
                    NSLog(@"[PayloadStorage] exported %@'s %@ to %@", legacyProfile.name, legacyProfile.payloadName, filePath);
                } else {
                    NSLog(@"[PayloadStorage] failed to write %@'s %@ to %@: %@", legacyProfile.name, legacyProfile.payloadName, filePath, error);
                }
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:NXBootPayloadStorageChangedExternally object:self];
            NSLog(@"[PayloadStorage] migration completed");
        }];
    }
}

- (nonnull NSArray<Payload *> *)loadPayloads {
    // Array defines order, set avoids duplicates
    NSMutableArray<Payload *> *payloads = [[NSMutableArray alloc] init];
    NSMutableSet<Payload *> *payloadsSet = [[NSMutableSet alloc] init];

    // First add all known payloads in explicit order
    NSArray<NSString *> *order = [self.userDefaults objectForKey:NXBootPayloadsExplicitOrder];
    for (NSString *fileName in order) {
        NSString *path = [self.payloadsDir stringByAppendingPathComponent:fileName];
        Payload *payload = [[Payload alloc] initWithPath:path];
        if (payload) {
            if (![payloadsSet containsObject:payload]) {
                [payloadsSet addObject:payload];
                [payloads addObject:payload];
            }
        }
    }

    // Then append all new/unknown ones, such as those moved into the app via share sheet
    NSError *error = nil;
    NSArray<NSString *> *fileNames = [self.fileManager contentsOfDirectoryAtPath:self.payloadsDir error:&error];
    if (fileNames) {
        NSMutableArray<Payload *> *discoveredPayloads = [[NSMutableArray alloc] init];
        for (NSString *fileName in fileNames) {
            NSString *path = [self.payloadsDir stringByAppendingPathComponent:fileName];
            Payload *payload = [[Payload alloc] initWithPath:path];
            if (![payloadsSet containsObject:payload]) {
                [payloadsSet addObject:payload];
                [discoveredPayloads addObject:payload];
            }
        }
        [discoveredPayloads sortUsingComparator:^NSComparisonResult(Payload *a, Payload *b) {
            return [a.path compare:b.path];
        }];
        [payloads addObjectsFromArray:discoveredPayloads];
    } else {
        NSLog(@"[PayloadStorage] failed to list directory contents: %@", error);
    }

    return payloads;
}

- (void)storePayloadSortOrder:(nonnull NSArray<Payload *> *)payloads {
    NSMutableArray *order = [[NSMutableArray alloc] initWithCapacity:payloads.count];
    for (Payload *payload in payloads) {
        [order addObject:payload.path.lastPathComponent];
    }
    [self.userDefaults setObject:order forKey:NXBootPayloadsExplicitOrder];
}

- (Payload *)importPayload:(NSString *)filePath move:(BOOL)moveFile error:(NSError **)error {
    NSString *targetPath = [self.payloadsDir stringByAppendingPathComponent:filePath.lastPathComponent];
    if (targetPath.pathExtension.length == 0) {
        targetPath = [targetPath stringByAppendingPathExtension:@"bin"];
    }
    if (moveFile) {
        if (![self.fileManager moveItemAtPath:filePath toPath:targetPath error:error]) {
            return nil;
        }
    } else if (![self.fileManager copyItemAtPath:filePath toPath:targetPath error:error]) {
        return nil;
    }
    Payload *payload = [[Payload alloc] init];
    payload.path = targetPath;
    return payload;
}

- (BOOL)renamePayload:(nonnull Payload *)payload withNewName:(nonnull NSString *)name error:(NSError **)error {
    NSString *newName = [name stringByAppendingPathExtension:payload.path.pathExtension];
    NSString *newPath = [self.payloadsDir stringByAppendingPathComponent:newName];
    if ([self.fileManager moveItemAtPath:payload.path toPath:newPath error:error]) {
        payload.path = newPath;
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)deletePayload:(nonnull Payload *)payload error:(NSError **)error {
    return [self.fileManager removeItemAtPath:payload.path error:error];
}

@end
