using UnityEngine;

namespace Sportoteka3DPro
{
    public static class Sportoteka3DProRuntimeBootstrap
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void EnsureBridge()
        {
            GameObject bridgeObject = GameObject.Find("Sportoteka3DProBridge");
            if (bridgeObject == null)
            {
                bridgeObject = new GameObject("Sportoteka3DProBridge");
                Debug.Log("[Sportoteka3DPro] Bridge created by runtime bootstrap.");
            }

            if (bridgeObject.GetComponent<Sportoteka3DProBridge>() == null)
            {
                bridgeObject.AddComponent<Sportoteka3DProBridge>();
                Debug.Log("[Sportoteka3DPro] Bridge component added by runtime bootstrap.");
            }

            if (bridgeObject.GetComponent<Sportoteka3DProDrawController>() == null)
            {
                bridgeObject.AddComponent<Sportoteka3DProDrawController>();
            }

            GameObject flutterBridge = GameObject.Find("FlutterBridge");
            if (flutterBridge == null)
            {
                flutterBridge = new GameObject("FlutterBridge");
                Debug.Log("[Sportoteka3DPro] FlutterBridge proxy created.");
            }

            if (flutterBridge.GetComponent<Sportoteka3DProFlutterBridgeProxy>() == null)
            {
                flutterBridge.AddComponent<Sportoteka3DProFlutterBridgeProxy>();
            }
        }
    }
}
