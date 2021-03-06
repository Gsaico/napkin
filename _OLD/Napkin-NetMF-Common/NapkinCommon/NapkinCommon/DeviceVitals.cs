/****
 * Copyright (c) 2013 Chris J Daly (github user cjdaly)
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * 
 * Contributors:
 *   cjdaly - initial API and implementation
 ****/
using System;
using System.Net;
using System.Text;
using Microsoft.SPOT;

namespace NapkinCommon
{
    public class DeviceVitals
    {
        private string _napkinServerUri;
        private string _deviceId;
        private NetworkCredential _credential;

        public DeviceVitals(string napkinServerUri, string deviceId, NetworkCredential credential)
        {
            _napkinServerUri = napkinServerUri;
            _deviceId = deviceId;
            _credential = credential;
        }

        private int _cycleCount = 0;
        public int CycleCount { get { return _cycleCount; } }
        public void IncrementCycleCount()
        {
            _cycleCount++;
        }

        private int _postCycleDefault = 12 * 5;
        private int _postCycle = -1;
        public int PostCycle { get { return _postCycle; } }
        public void InitPostCycle()
        {
            if (_postCycle != -1) return;

            string postCycleText = ConfigUtil.GetOrInitConfigValue(_napkinServerUri, _deviceId, "post_cycle", _postCycleDefault.ToString(), _credential);

            try
            {
                _postCycle = int.Parse(postCycleText);
            }
            catch (Exception)
            {
                _postCycle = _postCycleDefault;
                Debug.Print("Error in InitPostCycle: " + postCycleText);
            }
        }

        private int _cycleDelayMillisecondsDefault = 5 * 1000;
        private int _cycleDelayMilliseconds = -1;
        public int CycleDelayMilliseconds { get { return _cycleDelayMilliseconds; } }
        public void InitCycleDelayMilliseconds()
        {
            if (_cycleDelayMilliseconds != -1) return;

            string cycleDelayMillisecondsText = ConfigUtil.GetOrInitConfigValue(_napkinServerUri, _deviceId, "cycle_delay_milliseconds", _cycleDelayMillisecondsDefault.ToString(), _credential);

            try
            {
                _cycleDelayMilliseconds = int.Parse(cycleDelayMillisecondsText);
            }
            catch (Exception)
            {
                _cycleDelayMilliseconds = _cycleDelayMillisecondsDefault;
                Debug.Print("Error in InitCycleDelayMilliseconds: " + cycleDelayMillisecondsText);
            }
        }


        private int _deviceStartCountCurrent = -1;
        public void UpdateDeviceStarts()
        {
            if (_deviceStartCountCurrent > -1) return;

            string deviceStartsText = ConfigUtil.GetOrInitConfigValue(_napkinServerUri, _deviceId, "device_start_count", "0", _credential);

            try
            {
                int deviceStartCountPrevious = int.Parse(deviceStartsText);
                _deviceStartCountCurrent = deviceStartCountPrevious + 1;

                ConfigUtil.PutConfigValue(_napkinServerUri + "/config/" + _deviceId, "device_start_count", _deviceStartCountCurrent.ToString(), _credential);
                Debug.Print("UpdateDeviceStarts updated device_start_count: " + _deviceStartCountCurrent);
            }
            catch (Exception)
            {
                Debug.Print("Error in UpdateDeviceStarts: " + deviceStartsText);
            }
        }

        private string _deviceLocation = "???";
        public string DeviceLocation { get { return _deviceLocation; } }
        public void UpdateDeviceLocation(bool force = false)
        {
            if (_deviceLocation != "???" && !force) return;

            _deviceLocation = ConfigUtil.GetOrInitConfigValue(_napkinServerUri, _deviceId, "device_location", "???", _credential);
            Debug.Print("Got device_location: " + _deviceLocation);
        }

        public StringBuilder AppendStatus(StringBuilder sb = null)
        {
            if (sb == null) sb = new StringBuilder();
            sb.Append("chatter.device.vitals~id=").AppendLine(_deviceId);
            sb.Append("chatter.device.vitals~startCount=").AppendLine(_deviceStartCountCurrent.ToString());
            sb.Append("chatter.device.vitals~currentCycle=").AppendLine(_cycleCount.ToString());
            sb.Append("chatter.device.vitals~location=").AppendLine(_deviceLocation);

            return sb;
        }
    }
}
