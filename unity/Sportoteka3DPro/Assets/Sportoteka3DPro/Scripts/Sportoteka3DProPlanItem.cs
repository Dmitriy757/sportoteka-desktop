
using System;
using UnityEngine;

namespace Sportoteka3DPro
{
    public enum Sportoteka3DProMode
    {
        Tactics,
        Analysis,
        Drill,
        Animation,
        Calibration,
        Branding
    }

    public enum Sportoteka3DProTool
    {
        Select,
        Player,
        Opponent,
        PassArrow,
        RunArrow,
        CurveArrow,
        Line,
        DashedLine,
        Freehand,
        Zone,
        HatchedZone,
        Circle,
        Text,
        Cone,
        Ball,
        MiniGoal,
        BigGoal,
        Mannequin,
        Ladder,
        Hurdle,
        Gate,
        Pole,
        Spotlight,
        Matchup,
        Offside,
        Measurement,
        TeamBadge,
        CalibrationMarker
    }

    [Serializable]
    public sealed class Sportoteka3DProPlayerData
    {
        public int id;
        public int number;
        public string name;
        public string position;
        public string role;
        public string avatarUrl;
        public string avatarPath;
        public string initials;
        public string teamColor = "#00A750";
        [NonSerialized] public Texture2D avatarTexture;

        public Sportoteka3DProPlayerData() {}

        public Sportoteka3DProPlayerData(int number, string name, string position)
        {
            this.id = number;
            this.number = number;
            this.name = name;
            this.position = position;
            this.role = RoleFromPosition(position);
            this.teamColor = "#00A750";
            this.initials = MakeInitials(name, number);
            this.avatarUrl = "";
            this.avatarPath = "";
        }

        public Sportoteka3DProPlayerData(int number, string name, string position, string role)
        {
            this.id = number;
            this.number = number;
            this.name = name;
            this.position = position;
            this.role = string.IsNullOrEmpty(role) ? RoleFromPosition(position) : role;
            this.teamColor = "#00A750";
            this.initials = MakeInitials(name, number);
            this.avatarUrl = "";
            this.avatarPath = "";
        }


        public static string RoleFromPosition(string position)
        {
            if (string.IsNullOrEmpty(position)) return "Состав";

            string p = position.ToLowerInvariant();

            if (p.Contains("вр") || p.Contains("врат") || p.Contains("gk") || p.Contains("goal")) return "Вратари";
            if (p.Contains("защ") || p.Contains("цз") || p.Contains("пз") || p.Contains("лз") || p.Contains("def")) return "Защита";
            if (p.Contains("полу") || p.Contains("оп") || p.Contains("цп") || p.Contains("ап") || p.Contains("mid")) return "Полузащита";
            if (p.Contains("нап") || p.Contains("нп") || p.Contains("ата") || p.Contains("wing") || p.Contains("forw")) return "Атака";

            return "Состав";
        }

        public static string MakeInitials(string name, int number)
        {
            if (string.IsNullOrEmpty(name)) return number.ToString();
            var parts = name.Trim().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length >= 2) return (parts[0][0].ToString() + parts[1][0].ToString()).ToUpperInvariant();
            if (parts.Length == 1 && parts[0].Length >= 2) return parts[0].Substring(0, 2).ToUpperInvariant();
            return number.ToString();
        }
    }

    [Serializable]
    public sealed class Sportoteka3DProPlanItem
    {
        public string id = "";
        public string type = "";
        public string color = "#00A750";
        public string text = "";

        public float x;
        public float z;
        public float toX;
        public float toZ;
        public float controlX;
        public float controlZ;

        public float width = 0.08f;
        public float alpha = 1.0f;
        public float scale = 1.0f;
        public float rotation = 0.0f;

        public bool visible = true;
        public bool locked = false;

        public int number;
        public string name = "";
        public string position = "";
        public string role = "";
        public string initials = "";
        public string avatarUrl = "";
        public string avatarPath = "";

        public Sportoteka3DProPlanItem Clone()
        {
            return new Sportoteka3DProPlanItem
            {
                id = id,
                type = type,
                color = color,
                text = text,
                x = x,
                z = z,
                toX = toX,
                toZ = toZ,
                controlX = controlX,
                controlZ = controlZ,
                width = width,
                alpha = alpha,
                scale = scale,
                rotation = rotation,
                visible = visible,
                locked = locked,
                number = number,
                name = name,
                position = position,
                role = role,
                initials = initials,
                avatarUrl = avatarUrl,
                avatarPath = avatarPath
            };
        }
    }

    [Serializable]
    public sealed class Sportoteka3DProPlanSnapshot
    {
        public string title = "Sportoteka 3D Pro Plan";
        public string teamName = "";
        public Sportoteka3DProPlanItem[] items;
    }

    [Serializable]
    public sealed class Sportoteka3DProFrameSnapshot
    {
        public int frameIndex;
        public Sportoteka3DProPlanItem[] items;
    }
}
