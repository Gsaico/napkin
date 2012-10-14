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
        public void UpdateDeviceLocation()
        {
            if (_deviceLocation != "???") return;

            _deviceLocation = ConfigUtil.GetOrInitConfigValue(_napkinServerUri, _deviceId, "device_location", "???", _credential);
            Debug.Print("Got device_location: " + _deviceLocation);
        }

        public readonly LongSampler MemCheck = CreateMemCheck();
        private static long TakeMemorySample()
        {
            return Debug.GC(false);
        }
        private static LongSampler CreateMemCheck(string statusKeyPrefix = "memory")
        {
            LongSampler sampler = new LongSampler(TakeMemorySample, statusKeyPrefix);
            return sampler;
        }

        public StringBuilder AppendStatus(StringBuilder sb = null)
        {
            if (sb == null) sb = new StringBuilder();
            sb.Append("device_id=").AppendLine(_deviceId);
            sb.Append("device_start_count=").AppendLine(_deviceStartCountCurrent.ToString());
            sb.Append("device_cycle=").AppendLine(_cycleCount.ToString());
            sb.Append("device_location=").AppendLine(_deviceLocation);
            sb.Append(MemCheck.GetStatus());
            return sb;
        }
    }
}
