using UnityEngine;

namespace Sportoteka3DPro
{
    public static class Sportoteka3DProFieldBuilder
    {
        public const float FieldLength = 105f;
        public const float FieldWidth = 68f;

        public static GameObject Build(Transform parent)
        {
            var root = new GameObject("Sportoteka3DProField_TEXTURE_GREEN_V2");
            root.transform.SetParent(parent, false);

            // Сначала окружение, потом поле поверх него.
            Sportoteka3DProStadiumBuilder.Build(root.transform, FieldLength, FieldWidth);
            BuildPitch(root.transform);
            BuildLines(root.transform);

            Debug.Log("[Sportoteka3DPro] TEXTURED GREEN FIELD V2 created. FieldBuilder file is ACTIVE.");
            return root;
        }

        private static void BuildPitch(Transform parent)
        {
            for (int i = 0; i < 12; i++)
            {
                float stripeWidth = FieldLength / 12f;
                var stripe = GameObject.CreatePrimitive(PrimitiveType.Cube);
                stripe.name = "TEXTURED_GREEN_Stripe_" + (i + 1);
                stripe.transform.SetParent(parent, false);
                stripe.transform.localPosition = new Vector3(-FieldLength / 2f + stripeWidth * i + stripeWidth / 2f, 0.04f, 0f);
                stripe.transform.localScale = new Vector3(stripeWidth, 0.08f, FieldWidth);

                Color color = (i % 2 == 0)
                    ? new Color(0.18f, 0.58f, 0.14f, 1f)
                    : new Color(0.12f, 0.46f, 0.12f, 1f);

                stripe.GetComponent<MeshRenderer>().sharedMaterial = CreateGrassMaterial("Textured Green Grass " + i, color);
            }

            var border = GameObject.CreatePrimitive(PrimitiveType.Cube);
            border.name = "Dark Green Field Base";
            border.transform.SetParent(parent, false);
            border.transform.localPosition = new Vector3(0f, -0.04f, 0f);
            border.transform.localScale = new Vector3(FieldLength + 0.8f, 0.04f, FieldWidth + 0.8f);
            border.GetComponent<MeshRenderer>().sharedMaterial = CreateSolidMaterial("Dark Green Base", new Color(0.06f, 0.28f, 0.08f, 1f));
        }

        private static Material CreateGrassMaterial(string name, Color baseColor)
        {
            Shader shader = Shader.Find("Standard") ?? Shader.Find("Legacy Shaders/Diffuse") ?? Shader.Find("Unlit/Texture") ?? Shader.Find("Unlit/Color");
            var mat = new Material(shader);
            mat.name = name;
            SetMaterialColor(mat, baseColor);

            var tex = Resources.Load<Texture2D>("Textures/field_grass_albedo");
            if (tex != null)
            {
                if (mat.HasProperty("_MainTex")) mat.SetTexture("_MainTex", tex);
                if (mat.HasProperty("_BaseMap")) mat.SetTexture("_BaseMap", tex);
                mat.mainTextureScale = new Vector2(7f, 5f);
            }

            if (mat.HasProperty("_Metallic")) mat.SetFloat("_Metallic", 0f);
            if (mat.HasProperty("_Glossiness")) mat.SetFloat("_Glossiness", 0.04f);
            if (mat.HasProperty("_Smoothness")) mat.SetFloat("_Smoothness", 0.04f);
            return mat;
        }

        private static Material CreateSolidMaterial(string name, Color color)
        {
            Shader shader = Shader.Find("Unlit/Color") ?? Shader.Find("Standard") ?? Shader.Find("Legacy Shaders/Diffuse");
            var mat = new Material(shader);
            mat.name = name;
            SetMaterialColor(mat, color);
            if (mat.HasProperty("_Metallic")) mat.SetFloat("_Metallic", 0f);
            if (mat.HasProperty("_Glossiness")) mat.SetFloat("_Glossiness", 0f);
            if (mat.HasProperty("_Smoothness")) mat.SetFloat("_Smoothness", 0f);
            return mat;
        }

        private static void SetMaterialColor(Material mat, Color color)
        {
            if (mat == null) return;
            if (mat.HasProperty("_Color")) mat.SetColor("_Color", color);
            if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", color);
            if (mat.HasProperty("_Tint")) mat.SetColor("_Tint", color);
        }

        private static void BuildLines(Transform parent)
        {
            var lineMat = CreateSolidMaterial("TEXTURED_GREEN_WHITE_LINES", Color.white);
            AddLine(parent, "Touchline Top", 0, 0.105f, FieldWidth / 2f, FieldLength, 0.18f, lineMat);
            AddLine(parent, "Touchline Bottom", 0, 0.105f, -FieldWidth / 2f, FieldLength, 0.18f, lineMat);
            AddLine(parent, "Goal Line Left", -FieldLength / 2f, 0.105f, 0, 0.18f, FieldWidth, lineMat);
            AddLine(parent, "Goal Line Right", FieldLength / 2f, 0.105f, 0, 0.18f, FieldWidth, lineMat);
            AddLine(parent, "Middle Line", 0, 0.11f, 0, 0.18f, FieldWidth, lineMat);
            AddCircle(parent, "Center Circle", new Vector3(0f, 0.115f, 0f), 9.15f, lineMat);
            AddDisc(parent, "Center Spot", new Vector3(0f, 0.12f, 0f), 0.35f, lineMat);
            AddPenaltyArea(parent, -1, lineMat);
            AddPenaltyArea(parent, 1, lineMat);
            AddGoal(parent, -1);
            AddGoal(parent, 1);
        }

        private static void AddPenaltyArea(Transform parent, int side, Material lineMat)
        {
            float x = side * FieldLength / 2f;
            float sign = side;
            float penaltyDepth = 16.5f;
            float penaltyWidth = 40.3f;
            float smallDepth = 5.5f;
            float smallWidth = 18.3f;
            AddLine(parent, side < 0 ? "Penalty Left Back" : "Penalty Right Back", x - sign * penaltyDepth, 0.12f, 0, 0.18f, penaltyWidth, lineMat);
            AddLine(parent, side < 0 ? "Penalty Left Top" : "Penalty Right Top", x - sign * penaltyDepth / 2f, 0.12f, penaltyWidth / 2f, penaltyDepth, 0.18f, lineMat);
            AddLine(parent, side < 0 ? "Penalty Left Bottom" : "Penalty Right Bottom", x - sign * penaltyDepth / 2f, 0.12f, -penaltyWidth / 2f, penaltyDepth, 0.18f, lineMat);
            AddLine(parent, side < 0 ? "Small Left Back" : "Small Right Back", x - sign * smallDepth, 0.12f, 0, 0.18f, smallWidth, lineMat);
            AddLine(parent, side < 0 ? "Small Left Top" : "Small Right Top", x - sign * smallDepth / 2f, 0.12f, smallWidth / 2f, smallDepth, 0.18f, lineMat);
            AddLine(parent, side < 0 ? "Small Left Bottom" : "Small Right Bottom", x - sign * smallDepth / 2f, 0.12f, -smallWidth / 2f, smallDepth, 0.18f, lineMat);
        }

        private static void AddGoal(Transform parent, int side)
        {
            var mat = CreateSolidMaterial("Goal White", new Color(0.92f, 0.96f, 0.94f, 1f));
            float x = side * (FieldLength / 2f + 0.55f);
            var goal = new GameObject(side < 0 ? "Goal Left" : "Goal Right");
            goal.transform.SetParent(parent, false);
            goal.transform.localPosition = new Vector3(x, 0, 0f);
            float sign = side < 0 ? -1f : 1f;
            AddPost(goal.transform, new Vector3(0f, 1.22f, -3.66f), mat);
            AddPost(goal.transform, new Vector3(0f, 1.22f, 3.66f), mat);
            AddCrossbar(goal.transform, new Vector3(0f, 2.44f, 0f), new Vector3(0.12f, 0.12f, 7.32f), mat);
            AddCrossbar(goal.transform, new Vector3(sign * 1.8f, 2.44f, -3.66f), new Vector3(3.6f, 0.08f, 0.08f), mat);
            AddCrossbar(goal.transform, new Vector3(sign * 1.8f, 2.44f, 3.66f), new Vector3(3.6f, 0.08f, 0.08f), mat);
            AddCrossbar(goal.transform, new Vector3(sign * 3.5f, 0.08f, 0f), new Vector3(0.08f, 0.08f, 7.32f), mat);
        }

        private static void AddPost(Transform parent, Vector3 pos, Material mat)
        {
            var post = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            post.name = "Goal Post";
            post.transform.SetParent(parent, false);
            post.transform.localPosition = pos;
            post.transform.localScale = new Vector3(0.08f, 1.22f, 0.08f);
            post.GetComponent<MeshRenderer>().sharedMaterial = mat;
        }

        private static void AddCrossbar(Transform parent, Vector3 pos, Vector3 scale, Material mat)
        {
            var bar = GameObject.CreatePrimitive(PrimitiveType.Cube);
            bar.name = "Goal Frame";
            bar.transform.SetParent(parent, false);
            bar.transform.localPosition = pos;
            bar.transform.localScale = scale;
            bar.GetComponent<MeshRenderer>().sharedMaterial = mat;
        }

        public static void AddLine(Transform parent, string name, float x, float y, float z, float lengthX, float lengthZ, Material mat)
        {
            var line = GameObject.CreatePrimitive(PrimitiveType.Cube);
            line.name = name;
            line.transform.SetParent(parent, false);
            line.transform.localPosition = new Vector3(x, y, z);
            line.transform.localScale = new Vector3(lengthX, 0.018f, lengthZ);
            line.GetComponent<MeshRenderer>().sharedMaterial = mat;
        }

        public static void AddLine(Transform parent, string name, Vector3 start, Vector3 end, float width, Material mat)
        {
            var lineRoot = new GameObject(name);
            lineRoot.transform.SetParent(parent, false);
            Vector3 delta = end - start;
            if (delta.sqrMagnitude < 0.0001f) delta = Vector3.forward * 0.25f;
            var line = GameObject.CreatePrimitive(PrimitiveType.Cube);
            line.name = name + " Mesh";
            line.transform.SetParent(lineRoot.transform, false);
            line.transform.position = start + delta * 0.5f;
            line.transform.rotation = Quaternion.LookRotation(delta.normalized, Vector3.up);
            line.transform.localScale = new Vector3(Mathf.Max(0.02f, width), 0.018f, delta.magnitude);
            line.GetComponent<MeshRenderer>().sharedMaterial = mat;
        }

        public static void AddCircle(Transform parent, string name, Vector3 pos, float radius, Material mat)
        {
            AddCircle(parent, name, pos, radius, 96, 0.18f, mat);
        }

        public static void AddCircle(Transform parent, string name, Vector3 center, float radius, int segments, float width, Material mat)
        {
            var circleRoot = new GameObject(name);
            circleRoot.transform.SetParent(parent, false);
            segments = Mathf.Max(16, segments);
            radius = Mathf.Max(0.1f, radius);
            width = Mathf.Max(0.02f, width);
            for (int i = 0; i < segments; i++)
            {
                float a0 = Mathf.PI * 2f * i / segments;
                float a1 = Mathf.PI * 2f * (i + 1) / segments;
                Vector3 p0 = center + new Vector3(Mathf.Cos(a0) * radius, 0f, Mathf.Sin(a0) * radius);
                Vector3 p1 = center + new Vector3(Mathf.Cos(a1) * radius, 0f, Mathf.Sin(a1) * radius);
                AddLine(circleRoot.transform, name + " Segment " + i, p0, p1, width, mat);
            }
        }

        private static void AddDisc(Transform parent, string name, Vector3 pos, float radius, Material mat)
        {
            var disc = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            disc.name = name;
            disc.transform.SetParent(parent, false);
            disc.transform.localPosition = pos;
            disc.transform.localScale = new Vector3(radius, 0.012f, radius);
            disc.GetComponent<MeshRenderer>().sharedMaterial = mat;
        }
    }
}
