using UnityEngine;

namespace Sportoteka3DPro
{
    /// <summary>
    /// Compatibility object for Flutter integration.
    /// Flutter code can call:
    /// sendToUnity("FlutterBridge", "LoadScheme", json)
    /// sendToUnity("FlutterBridge", "SetCameraPreset", "top")
    /// sendToUnity("FlutterBridge", "ClearScheme", "")
    /// </summary>
    public sealed class Sportoteka3DProFlutterBridgeProxy : MonoBehaviour
    {
        private Sportoteka3DProBridge Bridge
        {
            get
            {
                var go = GameObject.Find("Sportoteka3DProBridge");
                if (go == null) return null;
                return go.GetComponent<Sportoteka3DProBridge>();
            }
        }

        public void LoadScheme(string json)
        {
            var bridge = Bridge;
            if (bridge != null) bridge.ApplySceneJson(json);
            Debug.Log("[Sportoteka3DPro] FlutterBridge.LoadScheme");
        }

        public void ApplySceneJson(string json)
        {
            LoadScheme(json);
        }

        public void SetCameraPreset(string preset)
        {
            var bridge = Bridge;
            if (bridge != null) bridge.SetCameraPreset(preset);
        }

        public void ClearScheme(string unused = "")
        {
            var bridge = Bridge;
            if (bridge != null) bridge.ClearAnnotations(unused);
        }

        public void ResetScene(string unused = "")
        {
            var bridge = Bridge;
            if (bridge != null) bridge.ResetScene();
        }

        public void ExportScheme(string unused = "")
        {
            Debug.Log("{\"type\":\"scheme_export\",\"status\":\"unity_runtime_ready\"}");
        }
    }
}
