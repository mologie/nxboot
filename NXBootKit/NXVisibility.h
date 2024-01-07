#ifdef NXBOOTKIT_BUILDING
#define NXBOOTKIT_PUBLIC __attribute__((visibility("default")))
#else
#define NXBOOTKIT_PUBLIC
#endif
