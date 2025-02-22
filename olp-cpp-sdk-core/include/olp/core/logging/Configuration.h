/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

#pragma once

#include <memory>
#include <utility>
#include <vector>

#include <olp/core/CoreApi.h>
#include <olp/core/logging/Appender.h>
#include <olp/core/logging/MessageFormatter.h>

namespace olp {
namespace logging {
/**
 * @brief Class for configuring the appenders and loggers available by the
 * logging system.
 */
class CORE_API Configuration {
 public:
  /**
   * @brief Struct containing an appender and a log level that the appender is
   * enabled with.
   */
  struct AppenderWithLogLevel {
    /**
     * @brief The log level the appender is enabled with.
     *
     * Any log levels less than this level will be ignored.
     */
    logging::Level logLevel;

    /**
     * @brief The appender.
     */
    std::shared_ptr<IAppender> appender;

    /**
     * @brief Checks to see if the appender is enabled for a log level.
     * @param level The log level.
     */
    bool isEnabled(logging::Level level) const {
      return appender && static_cast<int>(level) >= static_cast<int>(logLevel);
    }
  };

  /**
   * @brief Typedef for a list of appenders
   */
  using AppenderList = std::vector<AppenderWithLogLevel>;

  /**
   * @brief Creates a default configuration by adding the DebugAppender and the
   * ConsoleAppender as appenders.
   * @return The default configuration.
   */
  static Configuration createDefault();

  /**
   * @brief Returns whether or not the configuration is valid.
   * @return Whether or not the configuration is valid.
   */
  inline bool isValid() const;

  /**
   * @brief Adds an appender along with its logging level to the configuration.
   * @param appender The appender to add.
   * @param level The log level belonging to appender.
   */
  inline Configuration& addAppender(
      std::shared_ptr<IAppender> appender,
      logging::Level level = logging::Level::Trace);

  /**
   * @brief Clears the list of appenders.
   */
  inline Configuration& clear();

  /**
   * @brief Gets the appenders from the configuration.
   * @return The appenders and belonging log levels.
   */
  inline const AppenderList& getAppenders() const;

 private:
  AppenderList m_appenders;
};

inline bool Configuration::isValid() const { return !m_appenders.empty(); }

inline Configuration& Configuration::addAppender(
    std::shared_ptr<IAppender> appender, logging::Level level) {
  if (appender) {
    AppenderWithLogLevel appenderWithLogLevel = {level, std::move(appender)};
    m_appenders.emplace_back(std::move(appenderWithLogLevel));
  }
  return *this;
}

inline Configuration& Configuration::clear() {
  m_appenders.clear();
  return *this;
}

inline auto Configuration::getAppenders() const -> const AppenderList& {
  return m_appenders;
}

}  // namespace logging
}  // namespace olp
