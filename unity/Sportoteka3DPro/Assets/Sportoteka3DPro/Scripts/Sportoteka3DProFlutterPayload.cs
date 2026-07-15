using System;

namespace Sportoteka3DPro
{
    [Serializable]
    public sealed class Sportoteka3DProFlutterPayload
    {
        public int clubId;
        public string clubName;
        public int teamId;
        public string teamName;
        public string teamLogo;
        public Sportoteka3DProFlutterPlayer[] players;
    }

    [Serializable]
    public sealed class Sportoteka3DProFlutterPlayer
    {
        public int id;
        public int number;
        public string name;
        public string position;
        public string role;
        public string avatarUrl;
        public string avatarPath;
        public string teamColor;
        public string initials;
    }
}
