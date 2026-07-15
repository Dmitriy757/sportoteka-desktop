using UnityEngine;

namespace Sportoteka3DPro
{
    public static class Sportoteka3DProMeshFactory
    {
        public static Mesh Cone(float radius, float height, int segments)
        {
            if (segments < 8) segments = 8;
            Mesh mesh = new Mesh();
            Vector3[] vertices = new Vector3[segments + 2];
            int[] triangles = new int[segments * 6];

            vertices[0] = new Vector3(0f, height, 0f);
            vertices[1] = Vector3.zero;

            for (int i = 0; i < segments; i++)
            {
                float a = (Mathf.PI * 2f * i) / segments;
                vertices[i + 2] = new Vector3(Mathf.Cos(a) * radius, 0f, Mathf.Sin(a) * radius);
            }

            int t = 0;
            for (int i = 0; i < segments; i++)
            {
                int next = (i + 1) % segments;
                triangles[t++] = 0;
                triangles[t++] = i + 2;
                triangles[t++] = next + 2;

                triangles[t++] = 1;
                triangles[t++] = next + 2;
                triangles[t++] = i + 2;
            }

            mesh.vertices = vertices;
            mesh.triangles = triangles;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            return mesh;
        }

        public static Mesh Quad(float width, float length)
        {
            Mesh mesh = new Mesh();
            float hw = width * 0.5f;
            float hl = length * 0.5f;
            mesh.vertices = new[]
            {
                new Vector3(-hw, 0f, -hl),
                new Vector3(hw, 0f, -hl),
                new Vector3(hw, 0f, hl),
                new Vector3(-hw, 0f, hl),
            };
            mesh.uv = new[]
            {
                new Vector2(0f, 0f),
                new Vector2(1f, 0f),
                new Vector2(1f, 1f),
                new Vector2(0f, 1f),
            };
            mesh.triangles = new[] {0, 2, 1, 0, 3, 2};
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            return mesh;
        }
    }
}
