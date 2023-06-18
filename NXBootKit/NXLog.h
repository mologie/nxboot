/**
 * @file NXBootKit logging
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de
 */

#pragma once

extern BOOL NXBootKitDebugEnabled;

#define NXLog(...) do { if (NXBootKitDebugEnabled) NSLog(__VA_ARGS__); } while (0)
