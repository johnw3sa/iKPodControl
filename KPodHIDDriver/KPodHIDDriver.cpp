//
//  KPodHIDDriver.cpp
//  KPodHIDDriver
//
//  Created by John Eigenbrode on 7/22/25.
//

#include <os/log.h>

#include <DriverKit/IOUserServer.h>
#include <DriverKit/IOLib.h>

#include "KPodHIDDriver.h"

kern_return_t
IMPL(KPodHIDDriver, Start)
{
    kern_return_t ret;
    ret = Start(provider, SUPERDISPATCH);
    os_log(OS_LOG_DEFAULT, "Hello World");
    return ret;
}
