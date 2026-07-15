using System;
using System.Collections.Generic;
using UnityEngine;

namespace Sportoteka3DPro
{
    public sealed class Sportoteka3DProBridge : MonoBehaviour
    {
        private Transform _sceneRoot;

        private void Awake()
        {
            gameObject.name = "Sportoteka3DProBridge";
            DontDestroyOnLoad(gameObject);
            EnsureLighting();
            EnsureRoot();
        }

        private void Start()
        {
            Debug.Log("[Sportoteka3DPro] Sportoteka3DProReady");
            ApplySceneJson(CreateDemoJson());
        }

        public void ApplySceneJson(string json)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(json)) json = CreateDemoJson();
                var scene = JsonUtility.FromJson<Sportoteka3DProScene>(json);
                if (scene == null) scene = DemoScene();
                BuildScene(scene);
                Debug.Log("[Sportoteka3DPro] Sportoteka3DProSceneApplied objects=" + (scene.objects == null ? 0 : scene.objects.Length));
            }
            catch (Exception ex)
            {
                Debug.LogError("[Sportoteka3DPro] ApplySceneJson failed: " + ex.Message + "\n" + ex.StackTrace);
                BuildScene(DemoScene());
            }
        }

        public void SetCameraPreset(string preset)
        {
            Sportoteka3DProCameraRig.ApplyPreset(new Sportoteka3DProCamera { preset = preset });
        }

        public void ResetScene()
        {
            ApplySceneJson(CreateDemoJson());
        }

        public void ClearAnnotations(string unused = "")
        {
            var root = GameObject.Find("Sportoteka3DProRuntimeScene");
            if (root == null) return;
            var remove = new List<GameObject>();
            foreach (Transform child in root.transform)
            {
                if (child.name.StartsWith("Player_") || child.name.StartsWith("Ball_") || child.name.StartsWith("Cone_") ||
                    child.name.StartsWith("Arrow_") || child.name.StartsWith("Zone_") || child.name.StartsWith("Label_") ||
                    child.name.StartsWith("GoalMarker_") || child.name.StartsWith("Marker_") || child.name.Contains("Drawing"))
                {
                    remove.Add(child.gameObject);
                }
            }

            foreach (var go in remove)
            {
                if (Application.isPlaying) Destroy(go);
                else UnityEngine.Object.DestroyImmediate(go);
            }
        }

        private void BuildScene(Sportoteka3DProScene scene)
        {
            EnsureLighting();
            EnsureRoot();
            ClearRoot();
            Sportoteka3DProFieldBuilder.Build(_sceneRoot);

            if (scene.objects != null)
            {
                foreach (var item in scene.objects)
                {
                    Sportoteka3DProObjectFactory.Create(item, _sceneRoot);
                }
            }

            Sportoteka3DProCameraRig.ApplyPreset(scene.camera ?? new Sportoteka3DProCamera { preset = "top" });
        }

        private void EnsureRoot()
        {
            if (_sceneRoot != null) return;
            var existing = GameObject.Find("Sportoteka3DProRuntimeScene");
            if (existing == null) existing = new GameObject("Sportoteka3DProRuntimeScene");
            _sceneRoot = existing.transform;
        }

        private void ClearRoot()
        {
            for (int i = _sceneRoot.childCount - 1; i >= 0; i--)
            {
                var child = _sceneRoot.GetChild(i);
                if (Application.isPlaying) Destroy(child.gameObject);
                else UnityEngine.Object.DestroyImmediate(child.gameObject);
            }
        }

        private static void EnsureLighting()
        {
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.20f, 0.24f, 0.28f);
            RenderSettings.fog = false;

            var sun = GameObject.Find("Sportoteka 3D Pro Sun");
            Light light;
            if (sun == null)
            {
                var lightObject = new GameObject("Sportoteka 3D Pro Sun");
                light = lightObject.AddComponent<Light>();
                lightObject.transform.rotation = Quaternion.Euler(58f, -34f, 0f);
            }
            else
            {
                light = sun.GetComponent<Light>() ?? sun.AddComponent<Light>();
            }

            light.type = LightType.Directional;
            light.intensity = 0.95f;
            light.shadows = LightShadows.Soft;
            light.color = new Color(1f, 0.97f, 0.92f);
        }

        private static Sportoteka3DProScene DemoScene()
        {
            return new Sportoteka3DProScene
            {
                title = "Sportoteka Football Board",
                meta = new Sportoteka3DProMeta { clubName = "Sportoteka", phase = "football_only" },
                field = new Sportoteka3DProField { type = "football", length = 105f, width = 68f, grassStyle = "broadcast", lineStyle = "tv", stadiumStyle = "training_arena" },
                camera = new Sportoteka3DProCamera { preset = "top" },
                objects = DemoObjects()
            };
        }

        private static Sportoteka3DProObject[] DemoObjects()
        {
            return new[]
            {
                new Sportoteka3DProObject { id = "home_6", type = "player", team = "home", number = 6, label = "6", kitColor = "#00A750", x = 0f, z = 7f, scale = 1.05f },
                new Sportoteka3DProObject { id = "home_8", type = "player", team = "home", number = 8, label = "8", kitColor = "#00A750", x = -14f, z = -8f, scale = 1.05f },
                new Sportoteka3DProObject { id = "home_10", type = "player", team = "home", number = 10, label = "10", kitColor = "#00A750", x = 12f, z = -11f, scale = 1.05f },
                new Sportoteka3DProObject { id = "home_9", type = "player", team = "home", number = 9, label = "9", kitColor = "#00A750", x = 0f, z = -27f, scale = 1.05f },
                new Sportoteka3DProObject { id = "away_4", type = "player", team = "away", number = 4, label = "4", kitColor = "#EF4444", x = -8f, z = -19f, scale = 1f },
                new Sportoteka3DProObject { id = "away_5", type = "player", team = "away", number = 5, label = "5", kitColor = "#EF4444", x = 8f, z = -19f, scale = 1f },
                new Sportoteka3DProObject { id = "ball_demo", type = "ball", x = 0f, z = 7f, scale = 1f },
                new Sportoteka3DProObject { id = "pass_demo", type = "pass", x = 0f, z = 7f, toX = 12f, toZ = -11f, color = "#FDE047", width = 1.0f },
                new Sportoteka3DProObject { id = "run_demo", type = "run", x = 0f, z = -27f, toX = 7f, toZ = -32f, color = "#38BDF8", width = 1.0f },
                new Sportoteka3DProObject { id = "press_zone", type = "zone", x = 0f, z = -22f, width = 32f, length = 16f, color = "#00A750", opacity = 0.16f },
                new Sportoteka3DProObject { id = "label_demo", type = "label", label = "Sportoteka Football Board", x = 0f, y = 2.1f, z = 31f, color = "#F8FAFC", scale = 1.1f }
            };
        }

        private static string CreateDemoJson()
        {
            return JsonUtility.ToJson(DemoScene());
        }
    }
}
