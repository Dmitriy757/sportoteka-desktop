using UnityEngine;

namespace Sportoteka3DPro
{
    public static class Sportoteka3DProMaterialFactory
    {
        public static Material Solid(string name, string hex)
        {
            return Solid(name, hex, false, 1.0f);
        }

        public static Material Solid(string name, string hex, bool transparent)
        {
            return Solid(name, hex, transparent, 1.0f);
        }

        public static Material Solid(string name, string hex, bool transparent, float alpha)
        {
            Shader shader = transparent ? FindTransparentShader() : FindOpaqueShader();
            if (shader == null) shader = Shader.Find("Standard");
            if (shader == null) shader = Shader.Find("Sprites/Default");
            if (shader == null)
            {
                Debug.LogError("[Sportoteka3DPro] Compatible shader not found. Material will use Unity fallback.");
                shader = Shader.Find("Hidden/Internal-Colored");
            }

            Material material = new Material(shader);
            material.name = string.IsNullOrEmpty(name) ? "Sportoteka Material" : name;

            Color color = ParseColor(hex);
            color.a = transparent ? Mathf.Clamp01(alpha) : 1f;
            SetColor(material, color);

            if (transparent) MakeTransparent(material, color.a);
            return material;
        }

        public static Material Grass(string name, Color baseColor, Color darkColor)
        {
            Shader shader = Shader.Find("Unlit/Texture");
            if (shader == null) shader = FindOpaqueShader();
            Material material = new Material(shader);
            material.name = string.IsNullOrEmpty(name) ? "Sportoteka Grass Texture" : name;

            Texture2D texture = BuildGrassTexture(baseColor, darkColor);
            texture.wrapMode = TextureWrapMode.Repeat;
            texture.filterMode = FilterMode.Bilinear;
            material.mainTexture = texture;
            SetColor(material, Color.white);
            material.SetTextureScale("_MainTex", new Vector2(7.5f, 4.0f));
            return material;
        }

        public static Material Line(string name, string hex)
        {
            Material m = Solid(name, hex);
            m.renderQueue = 2450;
            return m;
        }

        private static Shader FindOpaqueShader()
        {
            string[] names =
            {
                "Unlit/Color",
                "Legacy Shaders/Diffuse",
                "Standard",
                "Sprites/Default"
            };

            for (int i = 0; i < names.Length; i++)
            {
                Shader shader = Shader.Find(names[i]);
                if (shader != null) return shader;
            }

            return null;
        }

        private static Shader FindTransparentShader()
        {
            string[] names =
            {
                "Unlit/Transparent",
                "Legacy Shaders/Transparent/Diffuse",
                "Standard",
                "Sprites/Default"
            };

            for (int i = 0; i < names.Length; i++)
            {
                Shader shader = Shader.Find(names[i]);
                if (shader != null) return shader;
            }

            return FindOpaqueShader();
        }

        private static void SetColor(Material material, Color color)
        {
            if (material == null) return;
            if (material.HasProperty("_Color")) material.SetColor("_Color", color);
            if (material.HasProperty("_BaseColor")) material.SetColor("_BaseColor", color);
        }

        public static Color ParseColor(string hex)
        {
            if (string.IsNullOrWhiteSpace(hex)) return Color.white;
            string value = hex.Trim();
            if (!value.StartsWith("#")) value = "#" + value;
            Color color;
            if (ColorUtility.TryParseHtmlString(value, out color)) return color;
            return Color.white;
        }

        private static void MakeTransparent(Material material, float alpha)
        {
            if (material == null) return;

            Color color = Color.white;
            if (material.HasProperty("_Color")) color = material.GetColor("_Color");
            color.a = Mathf.Clamp01(alpha);
            SetColor(material, color);

            if (material.HasProperty("_Mode")) material.SetFloat("_Mode", 3f);
            if (material.HasProperty("_SrcBlend")) material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
            if (material.HasProperty("_DstBlend")) material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            if (material.HasProperty("_ZWrite")) material.SetInt("_ZWrite", 0);
            material.EnableKeyword("_ALPHABLEND_ON");
            material.renderQueue = 3000;
        }

        private static Texture2D BuildGrassTexture(Color baseColor, Color darkColor)
        {
            int size = 512;
            Texture2D tex = new Texture2D(size, size, TextureFormat.RGBA32, true);
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float stripe = Mathf.Sin((float)x / size * Mathf.PI * 8f) * 0.5f + 0.5f;
                    float noise = Mathf.PerlinNoise(x * 0.035f, y * 0.045f) * 0.18f;
                    float fine = Mathf.PerlinNoise(x * 0.16f + 24.7f, y * 0.10f + 9.3f) * 0.08f;
                    Color c = Color.Lerp(darkColor, baseColor, 0.52f + stripe * 0.22f + noise + fine);
                    tex.SetPixel(x, y, c);
                }
            }
            tex.Apply(true, false);
            return tex;
        }
    }
}
