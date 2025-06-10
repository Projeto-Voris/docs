#!/bin/bash
export SPINNAKER_GENTL64_CTI=/opt/spinnaker/lib/spinnaker-gentl/Spinnaker_GenTL.cti
export LD_LIBRARY_PATH=/opt/spinnaker/lib:$LD_LIBRARY_PATH
export DISPLAY=:0

source /opt/ros/humble/setup.bash
source ~/ros2_ws/install/setup.bash

exec ros2 launch voris_bringup active_system.launch.py
