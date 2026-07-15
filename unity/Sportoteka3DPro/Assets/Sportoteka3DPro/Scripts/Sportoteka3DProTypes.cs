using System;

namespace Sportoteka3DPro
{
    [Serializable]
    public class Sportoteka3DProScene
    {
        public string title = "Sportoteka 3D Pro";
        public Sportoteka3DProMeta meta = new Sportoteka3DProMeta();
        public Sportoteka3DProField field = new Sportoteka3DProField();
        public Sportoteka3DProCamera camera = new Sportoteka3DProCamera();
        public Sportoteka3DProLighting lighting = new Sportoteka3DProLighting();
        public Sportoteka3DProLayer[] layers = new Sportoteka3DProLayer[0];
        public Sportoteka3DProObject[] objects = new Sportoteka3DProObject[0];
    }

    [Serializable]
    public class Sportoteka3DProMeta
    {
        public string clubName = "";
        public string opponentName = "";
        public string phase = "";
        public string minute = "";
        public int matchId = 0;
        public int teamId = 0;
    }

    [Serializable]
    public class Sportoteka3DProField
    {
        public string type = "football";
        public float length = 105f;
        public float width = 68f;
        public string grassStyle = "broadcast";
        public string lineStyle = "tv";
        public string stadiumStyle = "training_arena";
    }

    [Serializable]
    public class Sportoteka3DProCamera
    {
        public string preset = "fifa";
        public float x = 0f;
        public float y = 32f;
        public float z = -78f;
        public float targetX = 0f;
        public float targetY = 0f;
        public float targetZ = 0f;
        public float fov = 35f;
    }

    [Serializable]
    public class Sportoteka3DProLighting
    {
        public string preset = "stadium_day";
        public float intensity = 0.72f;
        public bool shadows = false;
    }

    [Serializable]
    public class Sportoteka3DProLayer
    {
        public string id = "graphics";
        public string name = "Графика";
        public bool visible = true;
        public bool locked = false;
        public float opacity = 1f;
    }

    [Serializable]
    public class Sportoteka3DProObject
    {
        public string id = "object";
        public string type = "marker";
        public string layerId = "graphics";
        public string team = "home";
        public int number = 0;
        public string label = "";
        public string color = "#22C55E";
        public string secondaryColor = "#FFFFFF";
        public string kitColor = "#16A34A";
        public string backgroundColor = "#0F172A";
        public string modelKey = "";
        public string effect = "";
        public bool visible = true;
        public bool locked = false;

        public float x = 0f;
        public float y = 0f;
        public float z = 0f;
        public float toX = 0f;
        public float toY = 0f;
        public float toZ = 0f;
        public float rotationY = 0f;
        public float scale = 1f;
        public float width = 1f;
        public float length = 1f;
        public float radius = 1f;
        public float opacity = 1f;
    }
}
