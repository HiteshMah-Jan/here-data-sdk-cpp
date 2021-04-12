#!/bin/bash -ex
#
# Copyright (C) 2021 HERE Europe B.V.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
# License-Filename: LICENSE

###
### Script starts Mock server, install certificate, add it to trusted and
### run FV functional test against it inside iOS Simulator (more info in OLPEDGE-1773)
### NOTE: Simulator start fails, so disabled until OLPEDGE-2543 is DONE.
###
# For core dump backtrace
ulimit -c unlimited

# Set workspace location
if [[ ${CI_PROJECT_DIR} == "" ]]; then
    export CI_PROJECT_DIR=$(pwd)
fi

if [[ ${GITHUB_RUN_ID} == "" ]]; then
    export GITHUB_RUN_ID=$(date '+%s')
else
    echo ">>> Installing mock server SSL certificate into OS... >>>"
    curl https://raw.githubusercontent.com/mock-server/mockserver/master/mockserver-core/src/main/resources/org/mockserver/socket/CertificateAuthorityCertificate.pem --output mock-server-cert.pem

    # Import and Make trusted
    sudo security import mock-server-cert.pem
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain mock-server-cert.pem
    # Validate cert: if trusted - succeeded , if not trusted - fails
    sudo security verify-cert -c mock-server-cert.pem
fi

echo ">>> Starting Mock Server... >>>"
pushd tests/utils/mock-server
npm install
node server.js & export SERVER_PID=$!
popd

# Node can start server in 1 second, but not faster.
# Add waiter for server to be started. No other way to solve that.
# Curl returns code 1 - means server still down. Curl returns 0 when server is up
RC=1
while [[ ${RC} -ne 0 ]];
do
        set +e
        curl -s http://localhost:1080
        RC=$?
        sleep 0.2
        set -e
done

# Functional test should be able to use this variable : IP_ADDR for connecting to Mock Server.
# Looks like localhost is not reachable for Simulator.
export IP_ADDR=$(ipconfig getifaddr en0)
curl -s http://${IP_ADDR}:1080

echo ">>> Start network tests ... >>>"
# List available devices, runtimes on MacOS node
xcrun simctl list
xcrun simctl list devices
xcrun simctl list runtimes

export CurrentDeviceUDID=$(xcrun simctl list devices | grep "iPhone 8 (" | grep -v "unavailable" | grep -v "com.apple.CoreSimulator.SimDeviceType" | cut -d'(' -f2 | cut -d')' -f1 | head -1)

# Create new Simulator device

xcrun simctl list devices
xcrun simctl boot "iPhone 8"
xcrun simctl list devices
xcrun simctl create ${GITHUB_RUN_ID}_iphone8 "com.apple.CoreSimulator.SimDeviceType.iPhone-8"
xcrun simctl list devices
echo "Simulator created"

/Applications/Xcode_11.2.1.app/Contents/Developer/Applications/Simulator.app/Contents/MacOS/Simulator -CurrentDeviceUDID ${CurrentDeviceUDID} & export SIMULATOR_PID=$! || /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app/Contents/MacOS/Simulator -CurrentDeviceUDID ${CurrentDeviceUDID} & export SIMULATOR_PID=$!
echo "Simulator started device"

xcrun simctl logverbose enable
xcrun simctl install ${CurrentDeviceUDID} ./build/tests/functional/ios/olp-cpp-sdk-functional-tests-tester/Debug-iphonesimulator/olp-ios-olp-cpp-sdk-functional-tests-lib-tester.app
echo "App installed"
xcrun simctl launch ${CurrentDeviceUDID} com.here.olp.olp-ios-olp-cpp-sdk-functional-tests-lib-tester
result=$?
echo "App launched"
xcrun simctl shutdown ${CurrentDeviceUDID}
echo "Simulator shutdown done"



# TODO:
#  1. Find out how to save xml report after Simulator test done.
#  2. Fix `xcrun simctl launch` cmd below.
#  3. Functional test should be able to use this variable : IP_ADDR for connecting to Mock Server.

#
# export IP_ADDR=$(ipconfig getifaddr en0)
# curl -s http://${IP_ADDR}:1080
#
# xcrun simctl launch A95C5F91-DE57-4BA7-B905-E50AA2BCF9B8 com.here.olp.olp-ios-olp-cpp-sdk-functional-tests-lib-tester
# echo "App launched"
#
# Fol linux fv network tests pleaserefer to : ./scripts/linux/fv/gitlab-olp-cpp-sdk-functional-network-test.sh

echo ">>> Finished network tests >>>"

# Terminate the mock server
kill -TERM $SERVER_PID
kill -TERM $SIMULATOR_PID

wait

exit ${result}
