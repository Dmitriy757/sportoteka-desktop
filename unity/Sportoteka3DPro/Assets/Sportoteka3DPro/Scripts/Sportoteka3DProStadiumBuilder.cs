
using UnityEngine;

namespace Sportoteka3DPro
{
    public static class Sportoteka3DProStadiumBuilder
    {
        public static void Build(Transform parent, float fieldLength, float fieldWidth)
        {
            var root = new GameObject("Sportoteka3DProStadium_PRO_TRIBUNES");
            root.transform.SetParent(parent, false);

            BuildOuterConcrete(root.transform, fieldLength, fieldWidth);
            BuildAdBoards(root.transform, fieldLength, fieldWidth);

            BuildLongStand(root.transform, "Main West Tribune", new Vector3(-64f, 0f, 0f), true);
            BuildLongStand(root.transform, "East Tribune", new Vector3(64f, 0f, 0f), false);

            BuildShortStand(root.transform, "North Tribune", new Vector3(0f, 0f, 48f), false);
            BuildShortStand(root.transform, "South Tribune", new Vector3(0f, 0f, -48f), true);

            BuildVipPressBlock(root.transform);
            BuildRoofAndBackFrame(root.transform);
            BuildFloodLights(root.transform);

            Debug.Log("[Sportoteka3DPro] PRO TRIBUNES stadium created.");
        }

        private static void BuildOuterConcrete(Transform parent, float fieldLength, float fieldWidth)
        {
            // Только окружение вокруг поля. Не перекрывает газон.
            var mat = CreateTexturedMaterial("Stadium Concrete", "#8F969C", "Textures/stadium_concrete_albedo", 3.5f, 3.5f);

            AddCube(parent, "Concrete Apron North", new Vector3(0f, -0.12f, fieldWidth / 2f + 7.5f), new Vector3(fieldLength + 32f, 0.28f, 14f), mat);
            AddCube(parent, "Concrete Apron South", new Vector3(0f, -0.12f, -fieldWidth / 2f - 7.5f), new Vector3(fieldLength + 32f, 0.28f, 14f), mat);
            AddCube(parent, "Concrete Apron West", new Vector3(-fieldLength / 2f - 8.5f, -0.12f, 0f), new Vector3(16f, 0.28f, fieldWidth + 20f), mat);
            AddCube(parent, "Concrete Apron East", new Vector3(fieldLength / 2f + 8.5f, -0.12f, 0f), new Vector3(16f, 0.28f, fieldWidth + 20f), mat);
        }

        private static void BuildLongStand(Transform parent, string name, Vector3 position, bool west)
        {
            var root = new GameObject(name);
            root.transform.SetParent(parent, false);
            root.transform.localPosition = position;

            var concrete = CreateTexturedMaterial("Tribune Concrete", "#A6ADB3", "Textures/stadium_concrete_albedo", 4f, 2f);
            var seatA = CreateTexturedMaterial("Seat Blue A", "#283A86", "Textures/seat_blue_albedo", 8f, 1f);
            var seatB = CreateTexturedMaterial("Seat Blue B", "#4652A3", "Textures/seat_blue_albedo", 8f, 1f);
            var rail = CreateSolidMaterial("Rail White", "#DCE5EA");
            var dark = CreateSolidMaterial("Tribune Dark Void", "#15191F");

            float sign = west ? -1f : 1f;

            AddCube(root.transform, "Back Wall", new Vector3(sign * 8.8f, 6.5f, 0f), new Vector3(2.2f, 13f, 90f), concrete);
            AddCube(root.transform, "Dark Under Stand", new Vector3(sign * 3.4f, 1.2f, 0f), new Vector3(7f, 2.4f, 90f), dark);

            for (int r = 0; r < 13; r++)
            {
                float y = 0.45f + r * 0.62f;
                float x = sign * (0.4f + r * 0.72f);

                AddCube(root.transform, "Concrete Step " + r, new Vector3(x, y - 0.16f, 0f), new Vector3(0.95f, 0.32f, 88f), concrete);
                AddCube(root.transform, "Seat Row " + r, new Vector3(x + sign * 0.1f, y + 0.16f, 0f), new Vector3(0.5f, 0.22f, 83f), (r % 2 == 0) ? seatA : seatB);

                if (r % 3 == 0)
                {
                    AddCube(root.transform, "White Row Rail " + r, new Vector3(x - sign * 0.22f, y + 0.42f, 0f), new Vector3(0.08f, 0.08f, 84f), rail);
                }
            }

            // Лестницы/проходы режем визуально светлыми полосами.
            for (int i = -3; i <= 3; i += 2)
            {
                AddCube(root.transform, "Aisle " + i, new Vector3(sign * 4.7f, 4.2f, i * 11f), new Vector3(7.6f, 0.12f, 1.0f), concrete);
            }
        }

        private static void BuildShortStand(Transform parent, string name, Vector3 position, bool south)
        {
            var root = new GameObject(name);
            root.transform.SetParent(parent, false);
            root.transform.localPosition = position;

            var concrete = CreateTexturedMaterial("Short Concrete", "#9EA5AA", "Textures/stadium_concrete_albedo", 3f, 2f);
            var seat = CreateTexturedMaterial("Short Seat Blue", "#33449C", "Textures/seat_blue_albedo", 6f, 1f);
            var dark = CreateSolidMaterial("Short Dark Void", "#14181E");

            float sign = south ? -1f : 1f;

            AddCube(root.transform, "Back Wall", new Vector3(0f, 5.3f, sign * 6.6f), new Vector3(112f, 10.6f, 1.8f), concrete);
            AddCube(root.transform, "Dark Under Stand", new Vector3(0f, 1.0f, sign * 2.8f), new Vector3(112f, 2.0f, 4.8f), dark);

            for (int r = 0; r < 9; r++)
            {
                float y = 0.4f + r * 0.58f;
                float z = sign * (0.2f + r * 0.72f);

                AddCube(root.transform, "Short Step " + r, new Vector3(0f, y - 0.12f, z), new Vector3(110f, 0.28f, 0.9f), concrete);
                AddCube(root.transform, "Short Seat Row " + r, new Vector3(0f, y + 0.12f, z + sign * 0.1f), new Vector3(104f, 0.22f, 0.48f), seat);
            }
        }

        private static void BuildVipPressBlock(Transform parent)
        {
            var concrete = CreateTexturedMaterial("VIP Concrete", "#B9C0C5", "Textures/stadium_concrete_albedo", 2.5f, 1.5f);
            var glass = CreateTransparentMaterial("VIP Glass", "#7DD3FC", 0.32f);
            var dark = CreateSolidMaterial("VIP Dark", "#1B2028");

            var root = new GameObject("VIP Press Center");
            root.transform.SetParent(parent, false);
            root.transform.localPosition = new Vector3(-67.5f, 12.0f, 0f);

            AddCube(root.transform, "VIP Body", new Vector3(-2.8f, 0f, 0f), new Vector3(5.6f, 5.2f, 38f), concrete);
            AddCube(root.transform, "VIP Window Strip", new Vector3(-5.62f, 0.55f, 0f), new Vector3(0.12f, 2.0f, 34f), glass);
            AddCube(root.transform, "VIP Roof", new Vector3(-2.8f, 3.0f, 0f), new Vector3(8.2f, 0.45f, 42f), dark);
        }

        private static void BuildRoofAndBackFrame(Transform parent)
        {
            var metal = CreateTexturedMaterial("Roof Metal", "#23262E", "Textures/roof_metal_albedo", 3f, 3f);
            var beam = CreateSolidMaterial("Steel Beam", "#2B3038");

            AddCube(parent, "West Roof", new Vector3(-68f, 15.8f, 0f), new Vector3(20f, 0.7f, 98f), metal);
            AddCube(parent, "East Roof", new Vector3(68f, 14.2f, 0f), new Vector3(17f, 0.6f, 90f), metal);

            for (int i = -4; i <= 4; i++)
            {
                AddCube(parent, "West Roof Beam " + i, new Vector3(-67.5f, 14.8f, i * 10f), new Vector3(18f, 0.25f, 0.25f), beam);
                AddCube(parent, "East Roof Beam " + i, new Vector3(67.5f, 13.4f, i * 10f), new Vector3(15f, 0.25f, 0.25f), beam);
            }
        }

        private static void BuildAdBoards(Transform parent, float fieldLength, float fieldWidth)
        {
            var boardMat = CreateTexturedMaterial("Ad Board", "#EEF2F5", "Textures/ad_board_albedo", 6f, 1f);
            var blackMat = CreateSolidMaterial("Board Back", "#111827");

            float y = 0.58f;
            float z = fieldWidth / 2f + 1.35f;
            float x = fieldLength / 2f + 1.35f;

            AddCube(parent, "Ad Board North", new Vector3(0f, y, z), new Vector3(fieldLength, 1.15f, 0.2f), boardMat);
            AddCube(parent, "Ad Board South", new Vector3(0f, y, -z), new Vector3(fieldLength, 1.15f, 0.2f), boardMat);
            AddCube(parent, "Ad Board East", new Vector3(x, y, 0f), new Vector3(0.2f, 1.15f, fieldWidth), blackMat);
            AddCube(parent, "Ad Board West", new Vector3(-x, y, 0f), new Vector3(0.2f, 1.15f, fieldWidth), blackMat);
        }

        private static void BuildFloodLights(Transform parent)
        {
            CreateLightTower(parent, new Vector3(-78f, 0f, -52f), 52f);
            CreateLightTower(parent, new Vector3(-78f, 0f, 52f), 52f);
            CreateLightTower(parent, new Vector3(78f, 0f, -52f), -52f);
            CreateLightTower(parent, new Vector3(78f, 0f, 52f), -52f);
        }

        private static void CreateLightTower(Transform parent, Vector3 position, float yaw)
        {
            var root = new GameObject("Pro FloodLight Tower");
            root.transform.SetParent(parent, false);
            root.transform.localPosition = position;

            var metal = CreateSolidMaterial("Flood Metal", "#242932");
            var lampMat = CreateSolidMaterial("Lamp White", "#FFF8E1");

            AddCube(root.transform, "Mast A", new Vector3(-0.45f, 10f, -0.45f), new Vector3(0.25f, 20f, 0.25f), metal);
            AddCube(root.transform, "Mast B", new Vector3(0.45f, 10f, -0.45f), new Vector3(0.25f, 20f, 0.25f), metal);
            AddCube(root.transform, "Mast C", new Vector3(-0.45f, 10f, 0.45f), new Vector3(0.25f, 20f, 0.25f), metal);
            AddCube(root.transform, "Mast D", new Vector3(0.45f, 10f, 0.45f), new Vector3(0.25f, 20f, 0.25f), metal);

            for (int i = 0; i < 4; i++)
            {
                AddCube(root.transform, "Cross Brace " + i, new Vector3(0f, 4f + i * 4f, 0f), new Vector3(1.8f, 0.16f, 0.16f), metal);
            }

            AddCube(root.transform, "Lamp Rack", new Vector3(0f, 21.5f, 0f), new Vector3(9f, 1.0f, 2.2f), metal);

            for (int i = -2; i <= 2; i++)
            {
                AddCube(root.transform, "Lamp " + i, new Vector3(i * 1.6f, 21.5f, -1.2f), new Vector3(0.85f, 0.55f, 0.16f), lampMat);
            }

            var lightObj = new GameObject("Tower Spot Light");
            lightObj.transform.SetParent(root.transform, false);
            lightObj.transform.localPosition = new Vector3(0f, 21.2f, -1.4f);
            lightObj.transform.rotation = Quaternion.Euler(62f, yaw, 0f);

            var light = lightObj.AddComponent<Light>();
            light.type = LightType.Spot;
            light.range = 220f;
            light.spotAngle = 80f;
            light.intensity = 2.6f;
            light.color = new Color(1f, 0.96f, 0.88f);
            light.shadows = LightShadows.Soft;
        }

        private static GameObject AddCube(Transform parent, string name, Vector3 pos, Vector3 scale, Material mat)
        {
            var obj = GameObject.CreatePrimitive(PrimitiveType.Cube);
            obj.name = name;
            obj.transform.SetParent(parent, false);
            obj.transform.localPosition = pos;
            obj.transform.localScale = scale;
            obj.GetComponent<MeshRenderer>().sharedMaterial = mat;
            return obj;
        }

        private static Material CreateSolidMaterial(string name, string hex)
        {
            Color color;
            if (!ColorUtility.TryParseHtmlString(hex, out color)) color = Color.white;
            return CreateSolidMaterial(name, color);
        }

        private static Material CreateSolidMaterial(string name, Color color)
        {
            Shader shader =
                Shader.Find("Standard") ??
                Shader.Find("Legacy Shaders/Diffuse") ??
                Shader.Find("Unlit/Color");

            var mat = new Material(shader);
            mat.name = name;
            ApplyColor(mat, color);
            if (mat.HasProperty("_Metallic")) mat.SetFloat("_Metallic", 0f);
            if (mat.HasProperty("_Glossiness")) mat.SetFloat("_Glossiness", 0.08f);
            if (mat.HasProperty("_Smoothness")) mat.SetFloat("_Smoothness", 0.08f);
            return mat;
        }

        private static Material CreateTexturedMaterial(string name, string hex, string resourcePath, float tileX, float tileY)
        {
            Color color;
            if (!ColorUtility.TryParseHtmlString(hex, out color)) color = Color.white;

            var mat = CreateSolidMaterial(name, color);
            var tex = Resources.Load<Texture2D>(resourcePath);

            if (tex != null)
            {
                if (mat.HasProperty("_MainTex")) mat.SetTexture("_MainTex", tex);
                if (mat.HasProperty("_BaseMap")) mat.SetTexture("_BaseMap", tex);
                mat.mainTextureScale = new Vector2(tileX, tileY);
                ApplyColor(mat, color);
            }

            return mat;
        }

        private static Material CreateTransparentMaterial(string name, string hex, float alpha)
        {
            var mat = CreateSolidMaterial(name, hex);
            Color color = Color.white;
            if (ColorUtility.TryParseHtmlString(hex, out color))
            {
                color.a = Mathf.Clamp01(alpha);
                ApplyColor(mat, color);
            }

            if (mat.HasProperty("_Mode")) mat.SetFloat("_Mode", 3f);
            if (mat.HasProperty("_SrcBlend")) mat.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
            if (mat.HasProperty("_DstBlend")) mat.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            if (mat.HasProperty("_ZWrite")) mat.SetInt("_ZWrite", 0);
            mat.EnableKeyword("_ALPHABLEND_ON");
            mat.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;

            return mat;
        }

        private static void ApplyColor(Material mat, Color color)
        {
            if (mat.HasProperty("_Color")) mat.SetColor("_Color", color);
            if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", color);
            if (mat.HasProperty("_Tint")) mat.SetColor("_Tint", color);
        }
    }
}
