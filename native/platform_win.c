/* See platform_posix.c. */
#include "zoo_native.h"
#include <windows.h>

int32_t zoo_platform(void) { return 0; }

/* See platform_posix.c; GetLocalTime already answers in the user's zone. */
int32_t zoo_local_minutes(void) {
    SYSTEMTIME t;
    GetLocalTime(&t);
    return (int32_t)(t.wHour * 60 + t.wMinute);
}

/* Hides the console that Windows opens for a double-clicked program. Goose
   links every program as a console program, so Explorer makes a console
   window first, gives it the focus, and the launcher's own window opens
   behind it. The console is only ours to hide when no other process shares
   it: started from a terminal, that terminal is the user's and stays. */
void zoo_hide_console(void) {
    HWND console = GetConsoleWindow();
    DWORD attached[2];
    if (console == NULL) { return; }
    if (GetConsoleProcessList(attached, 2) != 1) { return; }
    ShowWindow(console, SW_HIDE);
}

/* Brings zoo's own window to the front once it exists. A window created by a
   process that Explorer started by double-click does not get the foreground
   by itself, so the launcher appears to do nothing while it sits behind the
   browser. SDL has no call for this, and the window handle never reaches
   Goose, so the process's own top-level window is found here. */
static BOOL CALLBACK zoo_pick_window(HWND window, LPARAM out) {
    DWORD owner = 0;
    GetWindowThreadProcessId(window, &owner);
    if (owner != GetCurrentProcessId() || !IsWindowVisible(window)) { return TRUE; }
    if (GetWindow(window, GW_OWNER) != NULL) { return TRUE; }
    *(HWND *)out = window;
    return FALSE;
}

void zoo_raise_window(void) {
    HWND window = NULL;
    EnumWindows(zoo_pick_window, (LPARAM)&window);
    if (window == NULL) { return; }
    if (IsIconic(window)) { ShowWindow(window, SW_RESTORE); }
    /* Topmost and back again: SetForegroundWindow alone is refused for a
       process the user has not interacted with, which is exactly our case. */
    SetWindowPos(window, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    SetWindowPos(window, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    BringWindowToTop(window);
    SetForegroundWindow(window);
}
