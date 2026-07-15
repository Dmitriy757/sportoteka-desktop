using UnityEngine;

namespace Sportoteka3DPro
{
    public static class Sportoteka3DProObjectFactory
    {
        public static GameObject Create(Sportoteka3DProObject item, Transform parent)
        {
            if (item == null || !item.visible) return null;
            string type = string.IsNullOrEmpty(item.type) ? "marker" : item.type.Trim().ToLowerInvariant();

            if (type == "player") return CreatePlayer(item, parent);
            if (type == "ball") return CreateBall(item, parent);
            if (type == "cone") return CreateCone(item, parent);
            if (type == "arrow" || type == "pass" || type == "run") return CreateArrow(item, parent, type == "run" || item.effect == "dash");
            if (type == "line") return CreateLine(item, parent, false);
            if (type == "dash" || type == "dashed_line") return CreateLine(item, parent, true);
            if (type == "zone" || type == "rectangle") return CreateZone(item, parent);
            if (type == "circle") return CreateCircle(item, parent);
            if (type == "offside" || type == "offside_line") return CreateOffsideLine(item, parent);
            if (type == "label") return CreateLabel(item, parent);
            if (type == "pressing" || type == "press") return CreatePressingShape(item, parent);
            if (type == "block") return CreateTeamBlock(item, parent);
            return CreateMarker(item, parent);
        }

        private static GameObject CreatePlayer(Sportoteka3DProObject item, Transform parent)
        {
            GameObject prefab = ResolvePrefab(item.modelKey, item.team == "away" ? "player_away" : "player_home");
            GameObject root;
            if (prefab != null)
            {
                root = Object.Instantiate(prefab, parent);
                root.name = "Player_" + SafeName(item.id);
                TintModel(root, Sportoteka3DProMaterialFactory.ParseColor(item.kitColor));
            }
            else
            {
                root = BuildProceduralPlayer(item, parent);
            }

            root.transform.localPosition = new Vector3(item.x, 0f, item.z);
            root.transform.localRotation = Quaternion.Euler(0f, item.rotationY, 0f);
            root.transform.localScale = Vector3.one * Mathf.Max(0.65f, item.scale);
            AddSelectionDisc(root.transform, item.team == "away" ? "#CBD5E1" : item.kitColor, 0.62f);

            if (item.number > 0 || !string.IsNullOrEmpty(item.label))
            {
                string label = !string.IsNullOrEmpty(item.label) ? item.label : item.number.ToString();
                AddBillboardText(root.transform, label, new Vector3(0f, 2.45f, 0f), 0.46f, "#F8FAFC");
            }

            return root;
        }

        private static GameObject BuildProceduralPlayer(Sportoteka3DProObject item, Transform parent)
        {
            GameObject root = new GameObject("Player_" + SafeName(item.id));
            root.transform.SetParent(parent, false);

            Material kit = Sportoteka3DProMaterialFactory.Solid("Kit " + item.team, string.IsNullOrEmpty(item.kitColor) ? "#16A34A" : item.kitColor);
            Material shorts = Sportoteka3DProMaterialFactory.Solid("Shorts", item.team == "away" ? "#F8FAFC" : "#102A1D");
            Material skin = Sportoteka3DProMaterialFactory.Solid("Skin", "#F1C9A5");
            Material socks = Sportoteka3DProMaterialFactory.Solid("Socks", item.team == "away" ? "#111827" : "#F8FAFC");

            AddCapsule(root.transform, "Body", new Vector3(0f, 1.35f, 0f), new Vector3(0.42f, 0.92f, 0.28f), kit);
            AddSphere(root.transform, "Head", new Vector3(0f, 2.08f, 0f), 0.22f, skin);
            AddCapsule(root.transform, "Arm L", new Vector3(-0.35f, 1.34f, 0f), new Vector3(0.12f, 0.54f, 0.12f), skin, new Vector3(0f, 0f, -16f));
            AddCapsule(root.transform, "Arm R", new Vector3(0.35f, 1.34f, 0f), new Vector3(0.12f, 0.54f, 0.12f), skin, new Vector3(0f, 0f, 16f));
            AddCapsule(root.transform, "Leg L", new Vector3(-0.13f, 0.55f, 0f), new Vector3(0.13f, 0.72f, 0.13f), socks);
            AddCapsule(root.transform, "Leg R", new Vector3(0.13f, 0.55f, 0f), new Vector3(0.13f, 0.72f, 0.13f), socks);
            AddCube(root.transform, "Shorts", new Vector3(0f, 0.95f, 0f), new Vector3(0.48f, 0.23f, 0.34f), shorts);
            return root;
        }

        private static GameObject CreateBall(Sportoteka3DProObject item, Transform parent)
        {
            GameObject prefab = ResolvePrefab(item.modelKey, "ball");
            GameObject root = prefab != null ? Object.Instantiate(prefab, parent) : GameObject.CreatePrimitive(PrimitiveType.Sphere);
            root.name = "Ball_" + SafeName(item.id);
            root.transform.SetParent(parent, false);
            root.transform.localPosition = new Vector3(item.x, 0.32f, item.z);
            root.transform.localScale = Vector3.one * (0.52f * Mathf.Max(0.75f, item.scale));

            if (prefab == null)
            {
                root.GetComponent<Renderer>().sharedMaterial = Sportoteka3DProMaterialFactory.Solid("Ball White", "#F8FAFC");
                AddBallPatches(root.transform);
            }

            return root;
        }

        private static void AddBallPatches(Transform parent)
        {
            Material black = Sportoteka3DProMaterialFactory.Solid("Ball Patches", "#111827");
            for (int i = 0; i < 5; i++)
            {
                GameObject patch = GameObject.CreatePrimitive(PrimitiveType.Cube);
                patch.name = "Ball Patch";
                patch.transform.SetParent(parent, false);
                float angle = i / 5f * Mathf.PI * 2f;
                patch.transform.localPosition = new Vector3(Mathf.Cos(angle) * 0.52f, Mathf.Sin(angle) * 0.08f, Mathf.Sin(angle) * 0.52f);
                patch.transform.localScale = new Vector3(0.16f, 0.02f, 0.16f);
                patch.transform.localRotation = Quaternion.Euler(0f, i * 72f, 0f);
                patch.GetComponent<Renderer>().sharedMaterial = black;
            }
        }

        private static GameObject CreateCone(Sportoteka3DProObject item, Transform parent)
        {
            GameObject prefab = ResolvePrefab(item.modelKey, "cone");
            if (prefab != null)
            {
                GameObject instance = Object.Instantiate(prefab, parent);
                instance.name = "Cone_" + SafeName(item.id);
                instance.transform.localPosition = new Vector3(item.x, 0f, item.z);
                instance.transform.localScale = Vector3.one * Mathf.Max(0.7f, item.scale);
                return instance;
            }

            GameObject root = new GameObject("Cone_" + SafeName(item.id));
            root.transform.SetParent(parent, false);
            root.transform.localPosition = new Vector3(item.x, 0f, item.z);

            Material mat = Sportoteka3DProMaterialFactory.Solid("Cone", string.IsNullOrEmpty(item.color) ? "#FF7A00" : item.color);
            MeshFilter mf = root.AddComponent<MeshFilter>();
            mf.sharedMesh = Sportoteka3DProMeshFactory.Cone(0.42f, 0.82f, 24);
            MeshRenderer mr = root.AddComponent<MeshRenderer>();
            mr.sharedMaterial = mat;

            AddCylinder(root.transform, "Cone Base", new Vector3(0f, 0.04f, 0f), new Vector3(0.52f, 0.04f, 0.52f), mat);
            return root;
        }

        private static GameObject CreateArrow(Sportoteka3DProObject item, Transform parent, bool dashed)
        {
            GameObject root = new GameObject("Arrow_" + SafeName(item.id));
            root.transform.SetParent(parent, false);

            Vector3 a = new Vector3(item.x, 0.18f, item.z);
            Vector3 b = new Vector3(item.toX, 0.18f, item.toZ);
            if (Vector3.Distance(a, b) < 0.25f) b = a + Vector3.forward * 5f;

            Material mat = Sportoteka3DProMaterialFactory.Solid("Arrow " + item.id, string.IsNullOrEmpty(item.color) ? "#FDE047" : item.color);
            float width = Mathf.Clamp(item.width <= 0f ? 0.55f : item.width * 0.45f, 0.18f, 1.4f);

            if (dashed)
            {
                AddDashedLine(root.transform, a, b, width, mat);
            }
            else
            {
                Sportoteka3DProFieldBuilder.AddLine(root.transform, "Arrow Body", a, b, width, mat);
            }

            AddArrowHead(root.transform, a, b, mat, width);
            return root;
        }

        private static GameObject CreateLine(Sportoteka3DProObject item, Transform parent, bool dashed)
        {
            GameObject root = new GameObject((dashed ? "DashedLine_" : "Line_") + SafeName(item.id));
            root.transform.SetParent(parent, false);
            Vector3 a = new Vector3(item.x, 0.17f, item.z);
            Vector3 b = new Vector3(item.toX, 0.17f, item.toZ);
            Material mat = Sportoteka3DProMaterialFactory.Solid("Line " + item.id, string.IsNullOrEmpty(item.color) ? "#38BDF8" : item.color);
            float width = Mathf.Clamp(item.width <= 0f ? 0.28f : item.width * 0.28f, 0.08f, 0.9f);
            if (dashed) AddDashedLine(root.transform, a, b, width, mat);
            else Sportoteka3DProFieldBuilder.AddLine(root.transform, "Line Body", a, b, width, mat);
            return root;
        }

        private static GameObject CreateZone(Sportoteka3DProObject item, Transform parent)
        {
            GameObject root = new GameObject("Zone_" + SafeName(item.id));
            root.transform.SetParent(parent, false);
            root.transform.localPosition = new Vector3(item.x, 0.11f, item.z);
            root.transform.localRotation = Quaternion.Euler(0f, item.rotationY, 0f);

            float width = Mathf.Max(1f, item.width);
            float length = Mathf.Max(1f, item.length);

            MeshFilter mf = root.AddComponent<MeshFilter>();
            mf.sharedMesh = Sportoteka3DProMeshFactory.Quad(width, length);
            MeshRenderer mr = root.AddComponent<MeshRenderer>();
            mr.sharedMaterial = Sportoteka3DProMaterialFactory.Solid("Zone Fill", item.color, true, item.opacity > 0 ? item.opacity : 0.28f);

            Material borderMat = Sportoteka3DProMaterialFactory.Solid("Zone Border", item.color);
            Vector3 p1 = new Vector3(-width / 2, 0.04f, -length / 2);
            Vector3 p2 = new Vector3(width / 2, 0.04f, -length / 2);
            Vector3 p3 = new Vector3(width / 2, 0.04f, length / 2);
            Vector3 p4 = new Vector3(-width / 2, 0.04f, length / 2);
            Sportoteka3DProFieldBuilder.AddLine(root.transform, "Zone Border 1", p1, p2, 0.12f, borderMat);
            Sportoteka3DProFieldBuilder.AddLine(root.transform, "Zone Border 2", p2, p3, 0.12f, borderMat);
            Sportoteka3DProFieldBuilder.AddLine(root.transform, "Zone Border 3", p3, p4, 0.12f, borderMat);
            Sportoteka3DProFieldBuilder.AddLine(root.transform, "Zone Border 4", p4, p1, 0.12f, borderMat);
            return root;
        }

        private static GameObject CreateCircle(Sportoteka3DProObject item, Transform parent)
        {
            GameObject root = new GameObject("Circle_" + SafeName(item.id));
            root.transform.SetParent(parent, false);
            Material mat = Sportoteka3DProMaterialFactory.Solid("Circle", string.IsNullOrEmpty(item.color) ? "#38BDF8" : item.color);
            Sportoteka3DProFieldBuilder.AddCircle(root.transform, "Circle", new Vector3(item.x, 0.16f, item.z), Mathf.Max(0.5f, item.radius), 72, Mathf.Max(0.12f, item.width * 0.2f), mat);
            return root;
        }

        private static GameObject CreateOffsideLine(Sportoteka3DProObject item, Transform parent)
        {
            GameObject root = new GameObject("OffsideLine_" + SafeName(item.id));
            root.transform.SetParent(parent, false);
            Material mat = Sportoteka3DProMaterialFactory.Solid("Offside Line", string.IsNullOrEmpty(item.color) ? "#F43F5E" : item.color);
            Sportoteka3DProFieldBuilder.AddLine(root.transform, "Offside Across", new Vector3(item.x, 0.19f, -34f), new Vector3(item.x, 0.19f, 34f), 0.20f, mat);
            AddBillboardText(root.transform, "ОФСАЙД", new Vector3(item.x, 1.6f, 30f), 0.62f, "#F43F5E");
            return root;
        }

        private static GameObject CreatePressingShape(Sportoteka3DProObject item, Transform parent)
        {
            GameObject root = new GameObject("Pressing_" + SafeName(item.id));
            root.transform.SetParent(parent, false);

            Material mat = Sportoteka3DProMaterialFactory.Solid("Pressing", string.IsNullOrEmpty(item.color) ? "#F97316" : item.color);
            Vector3 c = new Vector3(item.x, 0.2f, item.z);
            Sportoteka3DProFieldBuilder.AddCircle(root.transform, "Press Circle", c, Mathf.Max(3.5f, item.radius), 64, 0.22f, mat);
            AddArrowHead(root.transform, c + new Vector3(-2f, 0, -2f), c, mat, 0.35f);
            AddArrowHead(root.transform, c + new Vector3(2f, 0, -2f), c, mat, 0.35f);
            AddArrowHead(root.transform, c + new Vector3(0f, 0, 2.8f), c, mat, 0.35f);
            return root;
        }

        private static GameObject CreateTeamBlock(Sportoteka3DProObject item, Transform parent)
        {
            item.width = item.width <= 0 ? 32f : item.width;
            item.length = item.length <= 0 ? 20f : item.length;
            item.opacity = item.opacity <= 0 ? 0.14f : item.opacity;
            item.color = string.IsNullOrEmpty(item.color) ? "#0EA5E9" : item.color;
            GameObject root = CreateZone(item, parent);
            root.name = "TeamBlock_" + SafeName(item.id);
            AddBillboardText(root.transform, "КОМПАКТНЫЙ БЛОК", new Vector3(0f, 2.2f, item.length / 2 + 1.2f), 0.52f, "#E0F2FE");
            return root;
        }

        private static GameObject CreateLabel(Sportoteka3DProObject item, Transform parent)
        {
            GameObject root = new GameObject("Label_" + SafeName(item.id));
            root.transform.SetParent(parent, false);
            root.transform.localPosition = new Vector3(item.x, item.y <= 0 ? 1.6f : item.y, item.z);
            AddBillboardText(root.transform, item.label, Vector3.zero, Mathf.Max(0.32f, item.scale * 0.46f), string.IsNullOrEmpty(item.color) ? "#FFFFFF" : item.color);
            return root;
        }

        private static GameObject CreateMarker(Sportoteka3DProObject item, Transform parent)
        {
            GameObject root = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            root.name = "Marker_" + SafeName(item.id);
            root.transform.SetParent(parent, false);
            root.transform.localPosition = new Vector3(item.x, 0.18f, item.z);
            root.transform.localScale = Vector3.one * Mathf.Max(0.4f, item.scale);
            root.GetComponent<Renderer>().sharedMaterial = Sportoteka3DProMaterialFactory.Solid("Marker", string.IsNullOrEmpty(item.color) ? "#00A870" : item.color);
            return root;
        }

        private static void AddDashedLine(Transform parent, Vector3 a, Vector3 b, float width, Material mat)
        {
            float distance = Vector3.Distance(a, b);
            if (distance <= 0.01f) return;
            Vector3 dir = (b - a).normalized;
            float dash = 2.0f;
            float gap = 1.0f;
            int count = Mathf.CeilToInt(distance / (dash + gap));
            for (int i = 0; i < count; i++)
            {
                float start = i * (dash + gap);
                float end = Mathf.Min(start + dash, distance);
                if (start >= distance) break;
                Sportoteka3DProFieldBuilder.AddLine(parent, "Dash " + i, a + dir * start, a + dir * end, width, mat);
            }
        }

        private static void AddArrowHead(Transform parent, Vector3 a, Vector3 b, Material mat, float width)
        {
            Vector3 dir = b - a;
            if (dir.sqrMagnitude < 0.01f) dir = Vector3.forward;
            Quaternion rot = Quaternion.LookRotation(dir.normalized, Vector3.up) * Quaternion.Euler(90f, 0f, 0f);

            GameObject head = new GameObject("Arrow Head");
            head.transform.SetParent(parent, false);
            head.transform.localPosition = b;
            head.transform.localRotation = rot;
            head.transform.localScale = Vector3.one * Mathf.Max(0.85f, width * 1.7f);

            MeshFilter mf = head.AddComponent<MeshFilter>();
            mf.sharedMesh = Sportoteka3DProMeshFactory.Cone(0.42f, 1.0f, 24);
            MeshRenderer mr = head.AddComponent<MeshRenderer>();
            mr.sharedMaterial = mat;
        }

        private static void AddSelectionDisc(Transform parent, string color, float radius)
        {
            GameObject disc = new GameObject("Selection Disc");
            disc.transform.SetParent(parent, false);
            disc.transform.localPosition = new Vector3(0f, 0.03f, 0f);
            MeshFilter mf = disc.AddComponent<MeshFilter>();
            mf.sharedMesh = Sportoteka3DProMeshFactory.Quad(radius * 2f, radius * 2f);
            MeshRenderer mr = disc.AddComponent<MeshRenderer>();
            mr.sharedMaterial = Sportoteka3DProMaterialFactory.Solid("Selection Disc", color, true, 0.55f);
        }

        private static void AddBillboardText(Transform parent, string text, Vector3 localPos, float size, string color)
        {
            if (string.IsNullOrEmpty(text)) return;
            GameObject go = new GameObject("Billboard Text");
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;

            TextMesh tm = go.AddComponent<TextMesh>();
            tm.text = text;
            tm.fontSize = 42;
            tm.characterSize = size * 0.08f;
            tm.anchor = TextAnchor.MiddleCenter;
            tm.alignment = TextAlignment.Center;
            tm.color = Sportoteka3DProMaterialFactory.ParseColor(color);
            go.AddComponent<Sportoteka3DProBillboard>();
        }

        private static GameObject ResolvePrefab(string modelKey, string fallbackKey)
        {
            string key = string.IsNullOrEmpty(modelKey) ? fallbackKey : modelKey;
            if (string.IsNullOrEmpty(key)) return null;
            string[] paths =
            {
                "Models/" + key,
                "Sportoteka3DProModels/" + key,
                "Sportoteka3DPro/Models/" + key
            };

            for (int i = 0; i < paths.Length; i++)
            {
                GameObject prefab = Resources.Load<GameObject>(paths[i]);
                if (prefab != null) return prefab;
            }
            return null;
        }

        private static void TintModel(GameObject root, Color kit)
        {
            if (root == null) return;
            Renderer[] renderers = root.GetComponentsInChildren<Renderer>(true);
            for (int i = 0; i < renderers.Length; i++)
            {
                string n = renderers[i].gameObject.name.ToLowerInvariant();
                if (n.Contains("shirt") || n.Contains("body") || n.Contains("kit") || n.Contains("jersey"))
                {
                    renderers[i].sharedMaterial = Sportoteka3DProMaterialFactory.Solid("Model Kit", "#" + ColorUtility.ToHtmlStringRGB(kit));
                }
            }
        }

        private static GameObject AddCapsule(Transform parent, string name, Vector3 pos, Vector3 scale, Material mat)
        {
            GameObject go = GameObject.CreatePrimitive(PrimitiveType.Capsule);
            go.name = name;
            go.transform.SetParent(parent, false);
            go.transform.localPosition = pos;
            go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = mat;
            return go;
        }

        private static GameObject AddCapsule(Transform parent, string name, Vector3 pos, Vector3 scale, Material mat, Vector3 rot)
        {
            GameObject go = AddCapsule(parent, name, pos, scale, mat);
            go.transform.localRotation = Quaternion.Euler(rot);
            return go;
        }

        private static GameObject AddSphere(Transform parent, string name, Vector3 pos, float scale, Material mat)
        {
            GameObject go = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            go.name = name;
            go.transform.SetParent(parent, false);
            go.transform.localPosition = pos;
            go.transform.localScale = Vector3.one * scale;
            go.GetComponent<Renderer>().sharedMaterial = mat;
            return go;
        }

        private static GameObject AddCylinder(Transform parent, string name, Vector3 pos, Vector3 scale, Material mat)
        {
            GameObject go = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            go.name = name;
            go.transform.SetParent(parent, false);
            go.transform.localPosition = pos;
            go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = mat;
            return go;
        }

        private static GameObject AddCube(Transform parent, string name, Vector3 pos, Vector3 scale, Material mat)
        {
            GameObject go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.name = name;
            go.transform.SetParent(parent, false);
            go.transform.localPosition = pos;
            go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = mat;
            return go;
        }

        private static string SafeName(string value)
        {
            return string.IsNullOrEmpty(value) ? "object" : value.Replace(" ", "_").Replace("/", "_");
        }
    }
}
