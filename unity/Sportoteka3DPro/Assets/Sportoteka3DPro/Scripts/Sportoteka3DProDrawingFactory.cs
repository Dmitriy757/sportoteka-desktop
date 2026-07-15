
using UnityEngine;

namespace Sportoteka3DPro
{
    public static class Sportoteka3DProDrawingFactory
    {
        public static GameObject Create(Sportoteka3DProPlanItem item, Transform parent, Texture2D avatarTexture, bool preview)
        {
            var holder = new GameObject("PLAN_" + item.id + "_" + item.type + (preview ? "_preview" : ""));
            holder.transform.SetParent(parent, false);

            Color color = Html(string.IsNullOrEmpty(item.color) ? "#00A750" : item.color);
            color.a = preview ? Mathf.Min(0.35f, item.alpha) : item.alpha;

            switch (item.type)
            {
                case "player":
                case "opponent":
                    CreatePlayer(holder.transform, item, color, avatarTexture);
                    break;
                case "pass":
                    CreateArrow(holder.transform, P(item.x, item.z), P(item.toX, item.toZ), color, false, item.width);
                    break;
                case "run":
                    CreateArrow(holder.transform, P(item.x, item.z), P(item.toX, item.toZ), color, true, item.width);
                    break;
                case "curve":
                    CreateCurveArrow(holder.transform, P(item.x, item.z), P(item.controlX, item.controlZ), P(item.toX, item.toZ), color, item.width);
                    break;
                case "line":
                    CreateLine(holder.transform, P(item.x, item.z), P(item.toX, item.toZ), item.width, color);
                    break;
                case "dashed":
                    CreateDashedLine(holder.transform, P(item.x, item.z), P(item.toX, item.toZ), item.width, color);
                    break;
                case "zone":
                    CreateZone(holder.transform, item, color, false);
                    break;
                case "hatched_zone":
                    CreateZone(holder.transform, item, color, true);
                    break;
                case "circle":
                    CreateCircle(holder.transform, P(item.x, item.z), Mathf.Max(0.8f, Vector3.Distance(P(item.x, item.z), P(item.toX, item.toZ))), color);
                    break;
                case "text":
                    CreateText(holder.transform, item, color);
                    break;
                case "cone":
                    CreateCone(holder.transform, item, color);
                    break;
                case "ball":
                    CreateBall(holder.transform, item);
                    break;
                case "mini_goal":
                case "big_goal":
                    CreateGoal(holder.transform, item, color, item.type == "big_goal");
                    break;
                case "mannequin":
                    CreateMannequin(holder.transform, item, color);
                    break;
                case "ladder":
                    CreateLadder(holder.transform, item, color);
                    break;
                case "hurdle":
                    CreateHurdle(holder.transform, item, color);
                    break;
                case "gate":
                    CreateGate(holder.transform, item, color);
                    break;
                case "pole":
                    CreatePole(holder.transform, item, color);
                    break;
                case "spotlight":
                    CreateSpotlight(holder.transform, item, color);
                    break;
                case "matchup":
                    CreateMatchup(holder.transform, item, color);
                    break;
                case "offside":
                    CreateOffside(holder.transform, item, color);
                    break;
                case "measurement":
                    CreateMeasurement(holder.transform, item, color);
                    break;
                case "team_badge":
                    CreateTeamBadge(holder.transform, item, color);
                    break;
                case "calibration":
                    CreateCalibration(holder.transform, item, color);
                    break;
                default:
                    CreateCircle(holder.transform, P(item.x, item.z), 1.0f, color);
                    break;
            }

            return holder;
        }

        public static Vector3 Center(Sportoteka3DProPlanItem item)
        {
            if (IsPointType(item.type)) return new Vector3(item.x, 0, item.z);
            return new Vector3((item.x + item.toX) * 0.5f, 0, (item.z + item.toZ) * 0.5f);
        }

        public static bool IsPointType(string type)
        {
            return type == "player" || type == "opponent" || type == "cone" || type == "ball" || type == "mini_goal" ||
                   type == "big_goal" || type == "mannequin" || type == "ladder" || type == "hurdle" || type == "gate" ||
                   type == "pole" || type == "spotlight" || type == "team_badge" || type == "calibration" || type == "text";
        }

        public static float Radius(Sportoteka3DProPlanItem item)
        {
            if (IsPointType(item.type)) return Mathf.Clamp(item.scale * 1.2f, 0.8f, 5f);
            return Mathf.Clamp(Vector3.Distance(P(item.x, item.z), P(item.toX, item.toZ)) * 0.16f, 1.0f, 7.0f);
        }

        private static Vector3 P(float x, float z) { return new Vector3(x, 0.18f, z); }

        private static void CreatePlayer(Transform parent, Sportoteka3DProPlanItem item, Color color, Texture2D avatarTexture)
        {
            var root = new GameObject("PlayerRoot");
            root.transform.SetParent(parent, false);
            root.transform.position = new Vector3(item.x, 0.14f, item.z);
            root.transform.localScale = Vector3.one * Mathf.Max(0.45f, item.scale);
            root.transform.rotation = Quaternion.Euler(0f, item.rotation, 0f);

            var border = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            border.name = "PlayerBorder";
            border.transform.SetParent(root.transform, false);
            border.transform.localScale = new Vector3(1.18f, 0.018f, 1.18f);
            border.GetComponent<MeshRenderer>().sharedMaterial = Mat("white", Color.white);

            var disc = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            disc.name = "PlayerDisc";
            disc.transform.SetParent(root.transform, false);
            disc.transform.localPosition = new Vector3(0f, 0.035f, 0f);
            disc.transform.localScale = new Vector3(1.0f, 0.036f, 1.0f);
            disc.GetComponent<MeshRenderer>().sharedMaterial = Mat("player", color);

            if (avatarTexture != null)
            {
                var avatar = GameObject.CreatePrimitive(PrimitiveType.Plane);
                avatar.name = "PlayerAvatar";
                avatar.transform.SetParent(root.transform, false);
                avatar.transform.localPosition = new Vector3(0f, 0.09f, 0f);
                avatar.transform.localRotation = Quaternion.identity;
                avatar.transform.localScale = new Vector3(0.105f, 1f, 0.105f);
                avatar.GetComponent<MeshRenderer>().sharedMaterial = TextureMat("avatar", avatarTexture);
            }
            else
            {
                AddTextMesh(root.transform, string.IsNullOrEmpty(item.initials) ? item.number.ToString() : item.initials, new Vector3(0, 0.11f, -0.08f), 0.12f, Color.white, 46);
            }

            if (!string.IsNullOrEmpty(item.position))
            {
                AddTextMesh(root.transform, item.position, new Vector3(0, 0.12f, 1.12f), 0.075f, Color.white, 32);
            }
        }

        private static void CreateArrow(Transform parent, Vector3 a, Vector3 b, Color color, bool dashed, float width)
        {
            if ((b - a).sqrMagnitude < 0.25f) return;
            if (dashed) CreateDashedLine(parent, a, b, width, color);
            else CreateLine(parent, a, b, width, color);

            Vector3 dir = (b - a).normalized;
            Vector3 right = Quaternion.Euler(0, 32, 0) * -dir;
            Vector3 left = Quaternion.Euler(0, -32, 0) * -dir;
            float head = Mathf.Clamp(Vector3.Distance(a, b) * 0.08f, 0.38f, 0.82f);
            CreateLine(parent, b, b + right * head, Mathf.Max(0.035f, width * 0.62f), color);
            CreateLine(parent, b, b + left * head, Mathf.Max(0.035f, width * 0.62f), color);
        }

        private static void CreateCurveArrow(Transform parent, Vector3 a, Vector3 control, Vector3 b, Color color, float width)
        {
            Vector3 prev = a;
            for (int i = 1; i <= 24; i++)
            {
                float t = i / 24f;
                Vector3 p = Bezier(a, control, b, t);
                CreateLine(parent, prev, p, width, color);
                prev = p;
            }
            Vector3 near = Bezier(a, control, b, 0.88f);
            Vector3 dir = (b - near).normalized;
            Vector3 right = Quaternion.Euler(0, 32, 0) * -dir;
            Vector3 left = Quaternion.Euler(0, -32, 0) * -dir;
            float head = Mathf.Clamp(Vector3.Distance(a, b) * 0.07f, 0.38f, 0.82f);
            CreateLine(parent, b, b + right * head, Mathf.Max(0.035f, width * 0.62f), color);
            CreateLine(parent, b, b + left * head, Mathf.Max(0.035f, width * 0.62f), color);
        }

        private static Vector3 Bezier(Vector3 a, Vector3 c, Vector3 b, float t)
        {
            float u = 1f - t;
            return u * u * a + 2f * u * t * c + t * t * b;
        }

        public static void CreateLine(Transform parent, Vector3 a, Vector3 b, float width, Color color)
        {
            Vector3 delta = b - a;
            if (delta.sqrMagnitude < 0.0001f) return;

            // V9: smooth coach-board graphics instead of rectangular/pixel-looking bars.
            // Cylinder is aligned along the vector, giving clean rounded line caps in 2D and 3D.
            float radius = Mathf.Clamp(width * 0.42f, 0.012f, 0.065f);
            var line = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            line.name = "SmoothLine";
            line.transform.SetParent(parent, false);
            line.transform.position = a + delta * 0.5f;
            line.transform.rotation = Quaternion.FromToRotation(Vector3.up, delta.normalized);
            line.transform.localScale = new Vector3(radius, delta.magnitude * 0.5f, radius);
            line.GetComponent<MeshRenderer>().sharedMaterial = Mat("line_smooth", color);
        }

        public static void CreateDashedLine(Transform parent, Vector3 a, Vector3 b, float width, Color color)
        {
            Vector3 delta = b - a;
            float len = delta.magnitude;
            if (len < 0.1f) return;
            Vector3 dir = delta.normalized;
            float dash = 0.62f;
            float gap = 0.38f;
            for (float p = 0; p < len; p += dash + gap)
            {
                float seg = Mathf.Min(dash, len - p);
                CreateLine(parent, a + dir * p, a + dir * (p + seg), width, color);
            }
        }

        private static void CreateZone(Transform parent, Sportoteka3DProPlanItem item, Color color, bool hatched)
        {
            float minX = Mathf.Min(item.x, item.toX);
            float maxX = Mathf.Max(item.x, item.toX);
            float minZ = Mathf.Min(item.z, item.toZ);
            float maxZ = Mathf.Max(item.z, item.toZ);
            float cx = (minX + maxX) * 0.5f;
            float cz = (minZ + maxZ) * 0.5f;

            var zone = GameObject.CreatePrimitive(PrimitiveType.Cube);
            zone.name = "TacticalZone";
            zone.transform.SetParent(parent, false);
            zone.transform.position = new Vector3(cx, 0.125f, cz);
            zone.transform.localScale = new Vector3(Mathf.Max(0.5f, maxX - minX), 0.02f, Mathf.Max(0.5f, maxZ - minZ));
            zone.GetComponent<MeshRenderer>().sharedMaterial = TransparentMat("zone", new Color(color.r, color.g, color.b, hatched ? 0.12f : 0.20f));

            CreateLine(parent, new Vector3(minX, 0.19f, minZ), new Vector3(maxX, 0.19f, minZ), item.width, color);
            CreateLine(parent, new Vector3(maxX, 0.19f, minZ), new Vector3(maxX, 0.19f, maxZ), item.width, color);
            CreateLine(parent, new Vector3(maxX, 0.19f, maxZ), new Vector3(minX, 0.19f, maxZ), item.width, color);
            CreateLine(parent, new Vector3(minX, 0.19f, maxZ), new Vector3(minX, 0.19f, minZ), item.width, color);

            if (hatched)
            {
                for (float x = minX - 12; x < maxX + 12; x += 3f)
                {
                    CreateLine(parent, new Vector3(x, 0.2f, minZ), new Vector3(x + 12f, 0.2f, maxZ), 0.035f, color);
                }
            }
        }

        private static void CreateCircle(Transform parent, Vector3 center, float radius, Color color)
        {
            int segments = 64;
            Vector3 prev = center + new Vector3(radius, 0, 0);
            for (int i = 1; i <= segments; i++)
            {
                float a = i * Mathf.PI * 2f / segments;
                Vector3 p = center + new Vector3(Mathf.Cos(a) * radius, 0, Mathf.Sin(a) * radius);
                CreateLine(parent, prev, p, 0.055f, color);
                prev = p;
            }
        }

        private static void CreateText(Transform parent, Sportoteka3DProPlanItem item, Color color)
        {
            AddTextMesh(parent, string.IsNullOrEmpty(item.text) ? item.name : item.text, new Vector3(item.x, 0.35f, item.z), 0.18f * Mathf.Max(0.45f, item.scale), color, 44, item.rotation);
        }

        private static void CreateCone(Transform parent, Sportoteka3DProPlanItem item, Color color)
        {
            var cone = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            cone.name = "Cone";
            cone.transform.SetParent(parent, false);
            cone.transform.position = new Vector3(item.x, 0.36f, item.z);
            cone.transform.localScale = new Vector3(0.34f, 0.55f, 0.34f) * Mathf.Max(0.45f, item.scale);
            cone.GetComponent<MeshRenderer>().sharedMaterial = Mat("cone", color);
        }

        private static void CreateBall(Transform parent, Sportoteka3DProPlanItem item)
        {
            var ball = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            ball.name = "Ball";
            ball.transform.SetParent(parent, false);
            ball.transform.position = new Vector3(item.x, 0.38f, item.z);
            ball.transform.localScale = new Vector3(0.52f, 0.52f, 0.52f) * Mathf.Max(0.45f, item.scale);
            ball.GetComponent<MeshRenderer>().sharedMaterial = Mat("ball", Color.white);
        }

        private static void CreateGoal(Transform parent, Sportoteka3DProPlanItem item, Color color, bool big)
        {
            var root = new GameObject("GoalRoot");
            root.transform.SetParent(parent, false);
            root.transform.position = new Vector3(item.x, 0.02f, item.z);
            root.transform.localScale = Vector3.one * Mathf.Max(0.45f, item.scale) * (big ? 1.75f : 1f);
            root.transform.rotation = Quaternion.Euler(0f, item.rotation, 0f);
            var mat = Mat("goal", Color.white);
            AddBar(root.transform, "back", new Vector3(0, 0.84f, 0.75f), new Vector3(2.6f, 0.08f, 0.08f), mat);
            AddBar(root.transform, "front", new Vector3(0, 0.84f, -0.75f), new Vector3(2.6f, 0.08f, 0.08f), mat);
            AddBar(root.transform, "leftPost", new Vector3(-1.3f, 0.42f, -0.75f), new Vector3(0.08f, 0.84f, 0.08f), mat);
            AddBar(root.transform, "rightPost", new Vector3(1.3f, 0.42f, -0.75f), new Vector3(0.08f, 0.84f, 0.08f), mat);
        }

        private static void CreateMannequin(Transform parent, Sportoteka3DProPlanItem item, Color color)
        {
            var root = new GameObject("MannequinRoot");
            root.transform.SetParent(parent, false);
            root.transform.position = new Vector3(item.x, 0, item.z);
            root.transform.localScale = Vector3.one * Mathf.Max(0.45f, item.scale);
            root.transform.rotation = Quaternion.Euler(0, item.rotation, 0);
            var body = GameObject.CreatePrimitive(PrimitiveType.Capsule);
            body.name = "Mannequin";
            body.transform.SetParent(root.transform, false);
            body.transform.localPosition = new Vector3(0, 0.85f, 0);
            body.transform.localScale = new Vector3(0.42f, 0.82f, 0.22f);
            body.GetComponent<MeshRenderer>().sharedMaterial = Mat("mannequin", color);
        }

        private static void CreateLadder(Transform parent, Sportoteka3DProPlanItem item, Color color)
        {
            var root = new GameObject("LadderRoot");
            root.transform.SetParent(parent, false);
            root.transform.position = new Vector3(item.x, 0.16f, item.z);
            root.transform.localScale = Vector3.one * Mathf.Max(0.45f, item.scale);
            root.transform.rotation = Quaternion.Euler(0, item.rotation, 0);
            for (int i = 0; i < 6; i++)
            {
                float z = -2.3f + i * 0.8f;
                CreateLine(root.transform, new Vector3(-0.75f, 0.02f, z), new Vector3(0.75f, 0.02f, z), 0.055f, color);
            }
            CreateLine(root.transform, new Vector3(-0.75f, 0.02f, -2.3f), new Vector3(-0.75f, 0.02f, 2.3f), 0.055f, color);
            CreateLine(root.transform, new Vector3(0.75f, 0.02f, -2.3f), new Vector3(0.75f, 0.02f, 2.3f), 0.055f, color);
        }

        private static void CreateHurdle(Transform parent, Sportoteka3DProPlanItem item, Color color) { CreateGate(parent, item, color); }

        private static void CreateGate(Transform parent, Sportoteka3DProPlanItem item, Color color)
        {
            var root = new GameObject("GateRoot");
            root.transform.SetParent(parent, false);
            root.transform.position = new Vector3(item.x, 0, item.z);
            root.transform.localScale = Vector3.one * Mathf.Max(0.45f, item.scale);
            root.transform.rotation = Quaternion.Euler(0, item.rotation, 0);
            var mat = Mat("gate", color);
            AddBar(root.transform, "left", new Vector3(-0.85f, 0.45f, 0), new Vector3(0.07f, 0.9f, 0.07f), mat);
            AddBar(root.transform, "right", new Vector3(0.85f, 0.45f, 0), new Vector3(0.07f, 0.9f, 0.07f), mat);
            AddBar(root.transform, "top", new Vector3(0, 0.9f, 0), new Vector3(1.75f, 0.07f, 0.07f), mat);
        }

        private static void CreatePole(Transform parent, Sportoteka3DProPlanItem item, Color color)
        {
            var pole = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            pole.name = "Pole";
            pole.transform.SetParent(parent, false);
            pole.transform.position = new Vector3(item.x, 0.95f, item.z);
            pole.transform.localScale = new Vector3(0.07f, 0.95f, 0.07f) * Mathf.Max(0.45f, item.scale);
            pole.GetComponent<MeshRenderer>().sharedMaterial = Mat("pole", color);
        }

        private static void CreateSpotlight(Transform parent, Sportoteka3DProPlanItem item, Color color)
        {
            float r = Mathf.Clamp(item.scale * 4f, 2.0f, 14f);
            var disc = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            disc.name = "Spotlight";
            disc.transform.SetParent(parent, false);
            disc.transform.position = new Vector3(item.x, 0.125f, item.z);
            disc.transform.localScale = new Vector3(r, 0.01f, r);
            disc.GetComponent<MeshRenderer>().sharedMaterial = TransparentMat("spotlight", new Color(color.r, color.g, color.b, 0.24f));
            CreateCircle(parent, P(item.x, item.z), r, color);
        }

        private static void CreateMatchup(Transform parent, Sportoteka3DProPlanItem item, Color color)
        {
            CreateDashedLine(parent, P(item.x, item.z), P(item.toX, item.toZ), item.width, color);
            CreateCircle(parent, P(item.x, item.z), 0.85f, color);
            CreateCircle(parent, P(item.toX, item.toZ), 0.85f, color);
        }

        private static void CreateOffside(Transform parent, Sportoteka3DProPlanItem item, Color color)
        {
            CreateDashedLine(parent, P(item.x, item.z), P(item.toX, item.toZ), Mathf.Max(0.04f, item.width), color);
            AddTextMesh(parent, "OFFSIDE", new Vector3((item.x + item.toX) * 0.5f, 0.35f, (item.z + item.toZ) * 0.5f + 1.4f), 0.14f, color, 40);
        }

        private static void CreateMeasurement(Transform parent, Sportoteka3DProPlanItem item, Color color)
        {
            Vector3 a = P(item.x, item.z);
            Vector3 b = P(item.toX, item.toZ);
            CreateLine(parent, a, b, item.width, color);
            AddTextMesh(parent, Vector3.Distance(a, b).ToString("0.0") + " м", (a + b) * 0.5f + new Vector3(0, 0.22f, 0), 0.13f, Color.white, 40);
        }

        private static void CreateTeamBadge(Transform parent, Sportoteka3DProPlanItem item, Color color)
        {
            var root = new GameObject("TeamBadge");
            root.transform.SetParent(parent, false);
            root.transform.position = new Vector3(item.x, 0.22f, item.z);
            root.transform.localScale = Vector3.one * Mathf.Max(0.55f, item.scale);
            var disc = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            disc.name = "BadgeDisc";
            disc.transform.SetParent(root.transform, false);
            disc.transform.localScale = new Vector3(2.2f, 0.05f, 2.2f);
            disc.GetComponent<MeshRenderer>().sharedMaterial = Mat("badge", color);
            AddTextMesh(root.transform, string.IsNullOrEmpty(item.text) ? "CLUB" : item.text, new Vector3(0, 0.16f, -0.15f), 0.12f, Color.white, 32);
        }

        private static void CreateCalibration(Transform parent, Sportoteka3DProPlanItem item, Color color)
        {
            float s = Mathf.Max(0.8f, item.scale);
            CreateLine(parent, new Vector3(item.x - s, 0.22f, item.z), new Vector3(item.x + s, 0.22f, item.z), 0.055f, color);
            CreateLine(parent, new Vector3(item.x, 0.22f, item.z - s), new Vector3(item.x, 0.22f, item.z + s), 0.055f, color);
            CreateCircle(parent, P(item.x, item.z), s * 0.75f, color);
        }

        private static void AddBar(Transform parent, string name, Vector3 localPos, Vector3 scale, Material mat)
        {
            var bar = GameObject.CreatePrimitive(PrimitiveType.Cube);
            bar.name = name;
            bar.transform.SetParent(parent, false);
            bar.transform.localPosition = localPos;
            bar.transform.localScale = scale;
            bar.GetComponent<MeshRenderer>().sharedMaterial = mat;
        }

        private static void AddTextMesh(Transform parent, string text, Vector3 pos, float scale, Color color, int fontSize, float rotation = 0)
        {
            var obj = new GameObject("TextMesh");
            obj.transform.SetParent(parent, false);
            obj.transform.position = pos;
            obj.transform.localRotation = Quaternion.Euler(90f, rotation, 0f);
            obj.transform.localScale = new Vector3(scale, scale, scale);
            var tm = obj.AddComponent<TextMesh>();
            tm.text = text;
            tm.anchor = TextAnchor.MiddleCenter;
            tm.alignment = TextAlignment.Center;
            tm.fontSize = fontSize;
            tm.fontStyle = FontStyle.Bold;
            tm.color = color;
        }

        private static Material Mat(string name, Color color)
        {
            Shader shader = Shader.Find("Standard") ?? Shader.Find("Legacy Shaders/Diffuse");
            var mat = new Material(shader);
            mat.name = name;
            if (mat.HasProperty("_Color")) mat.SetColor("_Color", color);
            if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", color);
            return mat;
        }

        private static Material TransparentMat(string name, Color color)
        {
            var mat = Mat(name, color);
            mat.SetFloat("_Mode", 3f);
            mat.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
            mat.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            mat.SetInt("_ZWrite", 0);
            mat.EnableKeyword("_ALPHABLEND_ON");
            mat.renderQueue = 3000;
            return mat;
        }

        private static Material TextureMat(string name, Texture2D texture)
        {
            Shader shader = Shader.Find("Unlit/Texture") ?? Shader.Find("Standard") ?? Shader.Find("Legacy Shaders/Diffuse");
            var mat = new Material(shader);
            mat.name = name;
            if (mat.HasProperty("_MainTex")) mat.SetTexture("_MainTex", texture);
            if (mat.HasProperty("_BaseMap")) mat.SetTexture("_BaseMap", texture);
            return mat;
        }

        private static Color Html(string hex)
        {
            Color color;
            if (!ColorUtility.TryParseHtmlString(hex, out color)) color = Color.white;
            return color;
        }
    }
}
