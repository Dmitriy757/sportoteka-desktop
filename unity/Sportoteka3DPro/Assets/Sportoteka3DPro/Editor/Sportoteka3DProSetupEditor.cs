using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Sportoteka3DPro.EditorTools
{
    public static class Sportoteka3DProSetupEditor
    {
        [MenuItem("Sportoteka 3D Pro/Create Football Board Scene")]
        public static void CreateFootballBoardScene()
        {
            EnsureFolders();

            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            scene.name = "SportotekaFootballBoard";

            GameObject bridgeObject = new GameObject("Sportoteka3DProBridge");
            bridgeObject.AddComponent<Sportoteka3DPro.Sportoteka3DProBridge>();
            bridgeObject.AddComponent<Sportoteka3DPro.Sportoteka3DProDrawController>();

            GameObject flutterBridge = new GameObject("FlutterBridge");
            flutterBridge.AddComponent<Sportoteka3DPro.Sportoteka3DProFlutterBridgeProxy>();

            GameObject lightObject = new GameObject("Sportoteka Sun Light");
            Light light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 0.78f;
            light.shadows = LightShadows.None;
            lightObject.transform.rotation = Quaternion.Euler(50f, -35f, 0f);

            GameObject cameraObject = new GameObject("Main Camera");
            cameraObject.tag = "MainCamera";
            Camera camera = cameraObject.AddComponent<Camera>();
            cameraObject.AddComponent<AudioListener>();
            camera.backgroundColor = new Color(0.42f, 0.52f, 0.60f);
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.fieldOfView = 35f;
            camera.transform.position = new Vector3(-22f, 30f, -86f);
            camera.transform.LookAt(new Vector3(5f, 0f, -6f));

            Sportoteka3DPro.Sportoteka3DProBridge bridge = bridgeObject.GetComponent<Sportoteka3DPro.Sportoteka3DProBridge>();
            bridge.ApplySceneJson("");

            string scenePath = "Assets/Sportoteka3DPro/Scenes/SportotekaFootballBoard.unity";
            EditorSceneManager.SaveScene(scene, scenePath);
            SetBuildScene(scenePath);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            Debug.Log("[Sportoteka3DPro] Football Board scene created: " + scenePath);
        }

        [MenuItem("Sportoteka 3D Pro/Open Football Board Scene")]
        public static void OpenScene()
        {
            string scenePath = "Assets/Sportoteka3DPro/Scenes/SportotekaFootballBoard.unity";
            if (File.Exists(scenePath)) EditorSceneManager.OpenScene(scenePath);
            else CreateFootballBoardScene();
        }

        private static void EnsureFolders()
        {
            CreateFolder("Assets", "Sportoteka3DPro");
            CreateFolder("Assets/Sportoteka3DPro", "Scenes");
            CreateFolder("Assets/Sportoteka3DPro", "Resources");
            CreateFolder("Assets/Sportoteka3DPro/Resources", "Models");
            CreateFolder("Assets/Sportoteka3DPro/Resources", "Textures");
        }

        private static void CreateFolder(string parent, string child)
        {
            if (!AssetDatabase.IsValidFolder(parent + "/" + child))
            {
                AssetDatabase.CreateFolder(parent, child);
            }
        }

        private static void SetBuildScene(string scenePath)
        {
            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(scenePath, true)
            };
        }
    }
}
