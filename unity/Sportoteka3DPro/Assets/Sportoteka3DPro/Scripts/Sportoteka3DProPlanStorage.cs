
using System;
using System.IO;
using System.Text;
using UnityEngine;

namespace Sportoteka3DPro
{
    public static class Sportoteka3DProPlanStorage
    {
        public static string DefaultPath
        {
            get { return Path.Combine(Application.persistentDataPath, "sportoteka_football_board_plan.json"); }
        }

        public static void Save(string teamName, System.Collections.Generic.List<Sportoteka3DProPlanItem> items)
        {
            var snapshot = new Sportoteka3DProPlanSnapshot
            {
                title = "Sportoteka Football Board Plan",
                teamName = teamName,
                items = items.ToArray()
            };

            string json = JsonUtility.ToJson(snapshot, true);
            File.WriteAllText(DefaultPath, json, Encoding.UTF8);
            Debug.Log("[Sportoteka3DPro] Plan saved: " + DefaultPath);
        }

        public static Sportoteka3DProPlanSnapshot Load()
        {
            if (!File.Exists(DefaultPath)) return null;
            try
            {
                var json = File.ReadAllText(DefaultPath, Encoding.UTF8);
                return JsonUtility.FromJson<Sportoteka3DProPlanSnapshot>(json);
            }
            catch (Exception e)
            {
                Debug.LogWarning("[Sportoteka3DPro] Failed to load plan: " + e.Message);
                return null;
            }
        }
    }
}
