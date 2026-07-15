using System.Collections.Generic;
using UnityEngine;

namespace Sportoteka3DPro
{
    public static class Sportoteka3DProPresets
    {
        private static int _idCounter;
        public static List<Sportoteka3DProPlanItem> Formation433()
        {
            var items = new List<Sportoteka3DProPlanItem>();
            // Clean TacticalPad-style formation: only the actual 11 positions, no random arrows/zones.
            AddPlayer(items, 1, "ВР", 0, 29);
            AddPlayer(items, 2, "ПЗ", 23, 17);
            AddPlayer(items, 4, "ЦЗ", 8, 19);
            AddPlayer(items, 5, "ЦЗ", -8, 19);
            AddPlayer(items, 3, "ЛЗ", -23, 17);
            AddPlayer(items, 6, "ОП", 0, 5);
            AddPlayer(items, 8, "ЦП", -13, -7);
            AddPlayer(items, 10, "АП", 13, -7);
            AddPlayer(items, 7, "ПК", 25, -22);
            AddPlayer(items, 11, "ЛК", -25, -22);
            AddPlayer(items, 9, "НП", 0, -29);
            AddPoint(items, "ball", 0, 0, "#FFFFFF");
            AddLabel(items, "4-3-3", 0, 32, "#FFFFFF");
            return items;
        }

        public static List<Sportoteka3DProPlanItem> BuildUpPatternPack()
        {
            var items = new List<Sportoteka3DProPlanItem>();
            AddPlayer(items, 1, "ВР", 0, 28);
            AddPlayer(items, 4, "ЦЗ", -9, 17);
            AddPlayer(items, 5, "ЦЗ", 9, 17);
            AddPlayer(items, 2, "ПЗ", 25, 8);
            AddPlayer(items, 3, "ЛЗ", -25, 8);
            AddPlayer(items, 6, "ОП", 0, 4);
            AddPlayer(items, 8, "ЦП", -12, -8);
            AddPlayer(items, 10, "АП", 12, -11);
            AddPlayer(items, 7, "ПК", 25, -22);
            AddPlayer(items, 11, "ЛК", -25, -22);
            AddPlayer(items, 9, "НП", 0, -27);
            AddPoint(items, "ball", 0, 28, "#FFFFFF");
            AddArrow(items, "pass", 0, 28, -9, 17, "#FDE047");
            AddArrow(items, "pass", -9, 17, 0, 4, "#FDE047");
            AddArrow(items, "pass", 0, 4, 12, -11, "#FDE047");
            AddArrow(items, "run", 25, 8, 29, -14, "#38BDF8");
            AddDrag(items, "hatched_zone", -31, 2, 31, 22, "#22C55E", 0.05f, 1f, 0.12f);
            AddLabel(items, "БИЛДАП: выход через 6-го + подключение фланга", 0, -32, "#FFFFFF");
            return items;
        }

        public static List<Sportoteka3DProPlanItem> SetPieceCornerPack()
        {
            var items = new List<Sportoteka3DProPlanItem>();
            AddPoint(items, "ball", -52, -34, "#FFFFFF");
            AddPlayer(items, 5, "ЦЗ", -8, -24);
            AddPlayer(items, 4, "ЦЗ", 3, -25);
            AddPlayer(items, 9, "НП", 10, -22);
            AddPlayer(items, 10, "АП", -18, -18);
            AddOpponent(items, 21, "DEF", 0, -27);
            AddOpponent(items, 22, "DEF", 8, -27);
            AddOpponent(items, 23, "DEF", -8, -27);
            AddArrow(items, "curve", -52, -34, 4, -27, "#FDE047");
            AddArrow(items, "run", -18, -18, -6, -27, "#38BDF8");
            AddArrow(items, "run", 10, -22, 17, -29, "#38BDF8");
            AddDrag(items, "hatched_zone", -13, -31, 16, -21, "#F97316", 0.05f, 1f, 0.14f);
            AddLabel(items, "СТАНДАРТ: угловой / блокировка / забегание", 0, -16, "#FFFFFF");
            return items;
        }

        public static List<Sportoteka3DProPlanItem> PressingTriggerPack()
        {
            var items = new List<Sportoteka3DProPlanItem>();
            AddPlayer(items, 9, "НП", 0, -18);
            AddPlayer(items, 7, "ПК", 20, -12);
            AddPlayer(items, 11, "ЛК", -20, -12);
            AddPlayer(items, 10, "АП", 0, -4);
            AddPlayer(items, 6, "ОП", 0, 9);
            AddOpponent(items, 2, "RB", 25, 12);
            AddOpponent(items, 5, "CB", 7, 18);
            AddOpponent(items, 4, "CB", -7, 18);
            AddPoint(items, "ball", 7, 18, "#FFFFFF");
            AddDrag(items, "spotlight", 7, 18, 7, 18, "#FDE047", 0.08f, 2.4f, 0.24f);
            AddArrow(items, "run", 9, -18, 7, 18, "#38BDF8");
            AddArrow(items, "run", 20, -12, 25, 12, "#38BDF8");
            AddArrow(items, "run", 0, -4, -7, 18, "#38BDF8");
            AddDrag(items, "matchup", -23, -8, 23, -8, "#FDE047", 0.06f);
            AddDrag(items, "offside", -36, 9, 36, 9, "#F43F5E", 0.055f);
            AddDrag(items, "hatched_zone", -28, 4, 28, 23, "#F97316", 0.055f, 1f, 0.14f);
            AddLabel(items, "ТРИГГЕР ПРЕССИНГА: пас на ЦЗ / закрыть фланг", 0, 28, "#FFFFFF");
            return items;
        }

        public static List<Sportoteka3DProPlanItem> FieldRadarPack()
        {
            var items = new List<Sportoteka3DProPlanItem>();
            AddPlayer(items, 4, "ЦЗ", -8, 17);
            AddPlayer(items, 5, "ЦЗ", 8, 17);
            AddPlayer(items, 6, "ОП", 0, 5);
            AddPlayer(items, 8, "ЦП", -12, -8);
            AddPlayer(items, 10, "АП", 12, -8);
            AddPlayer(items, 9, "НП", 0, -22);
            AddOpponent(items, 21, "ST", 0, 25);
            AddOpponent(items, 22, "AM", -14, 12);
            AddOpponent(items, 23, "AM", 14, 12);
            AddDrag(items, "hatched_zone", -26, -6, 26, 18, "#38BDF8", 0.05f, 1f, 0.13f);
            AddDrag(items, "hatched_zone", -18, -25, 18, -7, "#22C55E", 0.05f, 1f, 0.12f);
            AddDrag(items, "measurement", -22, 16, 22, 16, "#FDE047", 0.055f);
            AddDrag(items, "measurement", 0, -24, 0, 16, "#FDE047", 0.055f);
            AddLabel(items, "FIELD RADAR: компактность / глубина / ширина блока", 0, 28, "#FFFFFF");
            return items;
        }

        public static List<Sportoteka3DProPlanItem> CounterAttack3v2Pack()
        {
            var items = new List<Sportoteka3DProPlanItem>();
            AddPlayer(items, 6, "ОП", -8, 8);
            AddPlayer(items, 10, "АП", 0, -6);
            AddPlayer(items, 7, "ПК", 22, -16);
            AddPlayer(items, 9, "НП", 6, -25);
            AddOpponent(items, 4, "ЦЗ", 6, -12);
            AddOpponent(items, 5, "ЦЗ", 18, -10);
            AddPoint(items, "ball", -8, 8, "#FFFFFF");
            AddArrow(items, "pass", -8, 8, 0, -6, "#FDE047");
            AddArrow(items, "pass", 0, -6, 22, -16, "#FDE047");
            AddArrow(items, "run", 6, -25, 24, -29, "#38BDF8");
            AddDrag(items, "hatched_zone", 0, -30, 30, -8, "#22C55E", 0.05f, 1f, 0.13f);
            AddDrag(items, "measurement", 0, -6, 22, -16, "#FDE047", 0.055f);
            AddLabel(items, "КОНТРАТАКА 3v2: первый пас вперёд / ширина / забегание", 0, 24, "#FFFFFF");
            return items;
        }

        public static List<Sportoteka3DProPlanItem> Rondo5v2Pack()
        {
            var items = new List<Sportoteka3DProPlanItem>();
            AddDrag(items, "circle", -12, 0, 12, 0, "#FDE047", 0.05f, 12f, 0.55f);
            AddPlayer(items, 1, "A", -12, 0);
            AddPlayer(items, 2, "A", -4, 10);
            AddPlayer(items, 3, "A", 8, 8);
            AddPlayer(items, 4, "A", 12, -4);
            AddPlayer(items, 5, "A", -4, -10);
            AddOpponent(items, 6, "D", 0, 2);
            AddOpponent(items, 7, "D", 4, -4);
            AddPoint(items, "ball", -12, 0, "#FFFFFF");
            AddArrow(items, "pass", -12, 0, -4, 10, "#FDE047");
            AddArrow(items, "pass", -4, 10, 8, 8, "#FDE047");
            AddArrow(items, "pass", 8, 8, 12, -4, "#FDE047");
            AddPoint(items, "cone", -15, 12, "#F97316");
            AddPoint(items, "cone", 15, 12, "#F97316");
            AddPoint(items, "cone", -15, -12, "#F97316");
            AddPoint(items, "cone", 15, -12, "#F97316");
            AddLabel(items, "РОНДО 5v2: скорость паса / угол поддержки / игра в 1-2 касания", 0, -22, "#FFFFFF");
            return items;
        }

        public static List<Sportoteka3DProPlanItem> SpeedStationsPack()
        {
            var items = new List<Sportoteka3DProPlanItem>();
            AddPoint(items, "cone", -28, 18, "#F97316");
            AddPoint(items, "cone", -12, 18, "#F97316");
            AddPoint(items, "ladder", 2, 18, "#F97316");
            AddPoint(items, "hurdle", 16, 18, "#F43F5E");
            AddPoint(items, "gate", 30, 18, "#F97316");
            AddPoint(items, "mannequin", -12, -2, "#F59E0B");
            AddPoint(items, "mannequin", 8, -2, "#F59E0B");
            AddPoint(items, "mini_goal", 30, -16, "#FFFFFF");
            AddPoint(items, "ball", -28, 18, "#FFFFFF");
            AddArrow(items, "run", -28, 18, -12, 18, "#38BDF8");
            AddArrow(items, "run", -12, 18, 2, 18, "#38BDF8");
            AddArrow(items, "run", 2, 18, 16, 18, "#38BDF8");
            AddArrow(items, "pass", 16, 18, 30, -16, "#FDE047");
            AddLabel(items, "СКОРОСТНЫЕ СТАНЦИИ: координация → ускорение → завершение", 0, -28, "#FFFFFF");
            return items;
        }

        public static List<Sportoteka3DProPlanItem> DrillPack()
        {
            var items = new List<Sportoteka3DProPlanItem>();
            AddPoint(items, "cone", -28, 16, "#F97316");
            AddPoint(items, "cone", -8, 0, "#F97316");
            AddPoint(items, "cone", 16, -10, "#F97316");
            AddPoint(items, "ladder", -24, -14, "#F97316");
            AddPoint(items, "gate", -8, -14, "#F97316");
            AddPoint(items, "hurdle", 6, -14, "#F43F5E");
            AddPoint(items, "mini_goal", 28, -16, "#FFFFFF");
            AddPoint(items, "mannequin", 0, 10, "#F59E0B");
            AddPoint(items, "ball", -28, 16, "#FFFFFF");
            AddArrow(items, "run", -28, 16, -8, 0, "#38BDF8");
            AddArrow(items, "pass", -8, 0, 16, -10, "#FDE047");
            AddArrow(items, "run", 16, -10, 28, -16, "#38BDF8");
            AddLabel(items, "УПРАЖНЕНИЕ: пас → открывание → завершение", 2, -28, "#FFFFFF");
            return items;
        }

        public static List<Sportoteka3DProPlanItem> CalibrationPack()
        {
            var items = new List<Sportoteka3DProPlanItem>();
            AddPoint(items, "calibration", -52.5f, -34f, "#38BDF8");
            AddPoint(items, "calibration", 52.5f, -34f, "#38BDF8");
            AddPoint(items, "calibration", -52.5f, 34f, "#38BDF8");
            AddPoint(items, "calibration", 52.5f, 34f, "#38BDF8");
            AddDrag(items, "measurement", -52.5f, -34f, 52.5f, -34f, "#FDE047", 0.055f);
            AddDrag(items, "measurement", -52.5f, -34f, -52.5f, 34f, "#FDE047", 0.055f);
            AddLabel(items, "КАЛИБРОВКА ФУТБОЛЬНОГО ПОЛЯ 105 × 68 м", 0, 0, "#FFFFFF");
            return items;
        }

        public static List<Sportoteka3DProPlanItem> BrandingPack(string teamName)
        {
            var items = new List<Sportoteka3DProPlanItem>();
            AddBadge(items, string.IsNullOrEmpty(teamName) ? "SPORTOTEKA" : teamName, -42, 28, "#00A750");
            AddBadge(items, "СОПЕРНИК", 42, 28, "#2563EB");
            AddLabel(items, string.IsNullOrEmpty(teamName) ? "SPORTOTEKA" : teamName, -28, 24, "#FFFFFF");
            AddLabel(items, "СОПЕРНИК", 28, 24, "#FFFFFF");
            return items;
        }

        public static List<Sportoteka3DProPlanItem> ShowcasePack(string teamName)
        {
            var items = BrandingPack(teamName);
            AddDrag(items, "hatched_zone", -34, -29, 34, -18, "#111827", 0.045f, 1f, 0.20f);
            AddLabel(items, "SHOWCASE / БРИФИНГ ДЛЯ КОМАНДЫ", 0, -24, "#FFFFFF");
            AddLabel(items, "Тактическая доска • анализ • упражнение • экспорт PNG/JSON", 0, -29, "#FDE047");
            return items;
        }

        private static void AddPlayer(List<Sportoteka3DProPlanItem> items, int number, string pos, float x, float z)
        {
            items.Add(new Sportoteka3DProPlanItem
            {
                id = NewId(), type = "player", number = number, name = "Игрок №" + number, position = pos,
                initials = number.ToString(), x = x, z = z, color = "#00A750", scale = 1f
            });
        }

        private static void AddOpponent(List<Sportoteka3DProPlanItem> items, int number, string pos, float x, float z)
        {
            items.Add(new Sportoteka3DProPlanItem
            {
                id = NewId(), type = "opponent", number = number, name = "Соперник №" + number, position = pos,
                initials = number.ToString(), x = x, z = z, color = "#EF4444", scale = 1f
            });
        }

        private static void AddArrow(List<Sportoteka3DProPlanItem> items, string type, float x, float z, float toX, float toZ, string color)
        {
            AddDrag(items, type, x, z, toX, toZ, color, 0.08f);
        }

        private static void AddDrag(List<Sportoteka3DProPlanItem> items, string type, float x, float z, float toX, float toZ, string color, float width, float scale = 1f, float alpha = 1f)
        {
            items.Add(new Sportoteka3DProPlanItem
            {
                id = NewId(), type = type, x = x, z = z, toX = toX, toZ = toZ,
                controlX = (x + toX) * 0.5f,
                controlZ = (z + toZ) * 0.5f + Mathf.Clamp(Mathf.Abs(toX - x) * 0.12f + 4f, 4f, 12f),
                color = color, width = width, scale = scale, alpha = alpha
            });
        }

        private static void AddPoint(List<Sportoteka3DProPlanItem> items, string type, float x, float z, string color)
        {
            items.Add(new Sportoteka3DProPlanItem { id = NewId(), type = type, x = x, z = z, color = color, scale = 1f });
        }

        private static void AddLabel(List<Sportoteka3DProPlanItem> items, string text, float x, float z, string color)
        {
            items.Add(new Sportoteka3DProPlanItem { id = NewId(), type = "text", x = x, z = z, text = text, color = color, scale = 0.9f });
        }

        private static void AddBadge(List<Sportoteka3DProPlanItem> items, string text, float x, float z, string color)
        {
            items.Add(new Sportoteka3DProPlanItem { id = NewId(), type = "team_badge", x = x, z = z, text = text, color = color, scale = 1f });
        }

        private static string NewId()
        {
            _idCounter++;
            return "preset_" + _idCounter.ToString();
        }
    }
}
