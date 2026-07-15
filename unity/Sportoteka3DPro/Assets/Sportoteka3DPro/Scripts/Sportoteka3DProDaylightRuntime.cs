
using UnityEngine;
using UnityEngine.Rendering;

namespace Sportoteka3DPro
{
    public sealed class Sportoteka3DProDaylightRuntime : MonoBehaviour
    {
        private float _nextRefresh;
        private int _refreshCount;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void EnsureDaylightRuntime()
        {
            var existing = GameObject.Find("Sportoteka 3D Pro Daylight Runtime");
            if (existing == null)
            {
                existing = new GameObject("Sportoteka 3D Pro Daylight Runtime");
                DontDestroyOnLoad(existing);
            }

            if (existing.GetComponent<Sportoteka3DProDaylightRuntime>() == null)
            {
                existing.AddComponent<Sportoteka3DProDaylightRuntime>();
            }

            ApplyDaylight();
        }

        private void Awake()
        {
            DontDestroyOnLoad(gameObject);
            ApplyDaylight();
        }

        private void OnEnable()
        {
            ApplyDaylight();
        }

        private void Start()
        {
            ApplyDaylight();
        }

        private void Update()
        {
            // Bridge/Scene builder иногда пересоздаёт свет после загрузки сцены.
            // Первые секунды мягко переустанавливаем daylight-настройки.
            if (_refreshCount < 12 && Time.unscaledTime >= _nextRefresh)
            {
                _nextRefresh = Time.unscaledTime + 0.5f;
                _refreshCount++;
                ApplyDaylight();
            }
        }

        public static void ApplyDaylight()
        {
            SetupAmbient();
            SetupSkybox();
            SetupSun();
            SetupFillLight();
            SetupCameraBackground();
            SetupQuality();
        }

        private static void SetupAmbient()
        {
            RenderSettings.fog = false;
            RenderSettings.ambientMode = AmbientMode.Trilight;

            // Мягкое дневное освещение: не белит поле, но даёт объём трибунам.
            RenderSettings.ambientSkyColor = new Color(0.72f, 0.84f, 1.0f, 1f);
            RenderSettings.ambientEquatorColor = new Color(0.55f, 0.62f, 0.68f, 1f);
            RenderSettings.ambientGroundColor = new Color(0.22f, 0.28f, 0.22f, 1f);

            RenderSettings.reflectionIntensity = 0.35f;
            RenderSettings.defaultReflectionMode = DefaultReflectionMode.Skybox;
        }

        private static void SetupSkybox()
        {
            Shader skyShader = Shader.Find("Skybox/Procedural");
            if (skyShader == null) return;

            Material sky = RenderSettings.skybox;
            if (sky == null || sky.shader != skyShader || sky.name != "Sportoteka Day Skybox")
            {
                sky = new Material(skyShader);
                sky.name = "Sportoteka Day Skybox";
                RenderSettings.skybox = sky;
            }

            if (sky.HasProperty("_SunSize")) sky.SetFloat("_SunSize", 0.025f);
            if (sky.HasProperty("_SunSizeConvergence")) sky.SetFloat("_SunSizeConvergence", 4.0f);
            if (sky.HasProperty("_AtmosphereThickness")) sky.SetFloat("_AtmosphereThickness", 0.95f);
            if (sky.HasProperty("_SkyTint")) sky.SetColor("_SkyTint", new Color(0.56f, 0.74f, 1.0f, 1f));
            if (sky.HasProperty("_GroundColor")) sky.SetColor("_GroundColor", new Color(0.32f, 0.38f, 0.34f, 1f));
            if (sky.HasProperty("_Exposure")) sky.SetFloat("_Exposure", 1.05f);
        }

        private static void SetupSun()
        {
            Light sun = GetOrCreateDirectional("Sportoteka 3D Pro Sun");

            sun.type = LightType.Directional;
            sun.transform.rotation = Quaternion.Euler(48f, -34f, 0f);

            // Не ставим слишком большую интенсивность, иначе газон снова может казаться белёсым.
            sun.intensity = 1.12f;
            sun.color = new Color(1.0f, 0.95f, 0.84f, 1f);

            sun.shadows = LightShadows.Soft;
            sun.shadowStrength = 0.42f;
            sun.shadowBias = 0.035f;
            sun.shadowNormalBias = 0.28f;
            sun.shadowNearPlane = 0.2f;

            RenderSettings.sun = sun;
        }

        private static void SetupFillLight()
        {
            Light fill = GetOrCreateDirectional("Sportoteka Day Fill Light");

            fill.type = LightType.Directional;
            fill.transform.rotation = Quaternion.Euler(28f, 145f, 0f);
            fill.intensity = 0.22f;
            fill.color = new Color(0.70f, 0.82f, 1.0f, 1f);
            fill.shadows = LightShadows.None;
        }

        private static Light GetOrCreateDirectional(string name)
        {
            GameObject obj = GameObject.Find(name);
            if (obj == null)
            {
                obj = new GameObject(name);
                DontDestroyOnLoad(obj);
            }

            Light light = obj.GetComponent<Light>();
            if (light == null)
            {
                light = obj.AddComponent<Light>();
            }

            return light;
        }

        private static void SetupCameraBackground()
        {
            Camera camera = Camera.main;
            if (camera == null) return;

            camera.clearFlags = RenderSettings.skybox != null ? CameraClearFlags.Skybox : CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.50f, 0.72f, 0.94f, 1f);

            camera.nearClipPlane = 0.05f;
            camera.farClipPlane = 900f;
            camera.allowHDR = false;
            camera.allowMSAA = true;
        }

        private static void SetupQuality()
        {
            QualitySettings.shadows = ShadowQuality.All;
            QualitySettings.shadowDistance = 95f;
            QualitySettings.shadowProjection = ShadowProjection.StableFit;
            QualitySettings.shadowCascades = 2;
            QualitySettings.pixelLightCount = 4;
            QualitySettings.antiAliasing = Mathf.Max(QualitySettings.antiAliasing, 2);
        }
    }
}
