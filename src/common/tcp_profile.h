// Diagnostic instrumentation. OFF builds do not depend on UCX profiling.
#pragma once
#if defined(UCS_TCP_PROFILE_ENABLED) && UCS_TCP_PROFILE_ENABLED
#include <ucs/profile/tcp_profile.h>
#else
#define UCS_TP_SCOPE(_event, _object, _a) do { } while (0)
#define UCS_TP_MARK(_event, _object, _a, _b) do { } while (0)
#endif
