// No updates on Android (the app is installed by hand): the menu's update popup
// never shows, but ui.cpp still names what it would ask a running update.

#include "updater.h"

namespace launcher {

std::string UpdateJob::error() const {
  std::lock_guard lock(error_mutex_);
  return error_;
}

}  // namespace launcher
