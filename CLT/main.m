#import "XLFacilityMacros.h"
#import "XLTelnetServerLogger.h"
#import "XLHTTPServerLogger.h"

static int _counter = 0;

static void _RunLoopTimerCallBack(CFRunLoopTimerRef timer, void* info) {
  if (_counter % 2 == 0) {
    XLOG_VERBOSE(@"Tick");
  } else {
    XLOG_VERBOSE(@"Tock");
  }
  _counter += 1;
}

int main(int argc, const char* argv[]) {
  @autoreleasepool {
    [XLSharedFacility addLogger:[[XLTelnetServerLogger alloc] init]];
    [XLSharedFacility addLogger:[[XLHTTPServerLogger alloc] init]];
    
    CFRunLoopTimerRef timer = CFRunLoopTimerCreate(kCFAllocatorDefault, 0.0, 1.0, 0, 0, _RunLoopTimerCallBack, NULL);
    CFRunLoopAddTimer(CFRunLoopGetMain(), timer, kCFRunLoopCommonModes);
    
    CFRunLoopRun();
  }
  return 0;
}
