
using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.UI;
#endif

namespace Sportoteka3DPro
{
    public sealed class Sportoteka3DProEditorController : MonoBehaviour
    {
        private const string Green = "#00A750";
        private const string GreenDark = "#007A3D";
        private const string Graphite = "#111827";
        private const string Muted = "#667085";
        private const string Border = "#E5E7EB";
        private const string Red = "#F43F5E";

        private Canvas _canvas;
        private Transform _drawingRoot;
        private Transform _previewRoot;
        private Transform _selectionRoot;
        private Transform _popupRoot;

        private readonly List<Sportoteka3DProPlanItem> _items = new List<Sportoteka3DProPlanItem>();
        private readonly List<Sportoteka3DProPlayerData> _players = new List<Sportoteka3DProPlayerData>();
        private readonly List<Sportoteka3DProFrameSnapshot> _frames = new List<Sportoteka3DProFrameSnapshot>();
        private readonly List<Sportoteka3DProPlanItem[]> _undoStack = new List<Sportoteka3DProPlanItem[]>();
        private readonly List<Sportoteka3DProPlanItem[]> _redoStack = new List<Sportoteka3DProPlanItem[]>();
        private bool _historyLocked;

        private Sportoteka3DProMode _mode = Sportoteka3DProMode.Tactics;
        private Sportoteka3DProTool _tool = Sportoteka3DProTool.Select;
        private Sportoteka3DProPlayerData _selectedPlayer;

        private string _teamName = "ФК «Гомель» U13";
        private string _selectedItemId = "";
        private int _counter;
        private bool _dragging;
        private Vector3 _dragStart;
        private bool _movingSelected;
        private string _movingSelectedId = "";
        private Vector3 _moveStartPoint;
        private Sportoteka3DProPlanItem _moveOriginalItem;
        private Color _activeColor = ParseColor(Green);
        private float _activeWidth = 0.055f;
        private float _activeAlpha = 1.0f;

        private Text _statusText;
        private Text _modeText;
        private Text _toolText;
        private Text _selectedText;
        private UnityEngine.UI.Slider _widthSlider;
        private UnityEngine.UI.Slider _alphaSlider;
        private Transform _modePanelRoot;
        private Transform _compactRailRoot;
        private Transform _compactDockRoot;
        private Transform _compactInspectorRoot;
        private Transform _layersRoot;
        private string _rightPanelTab = "properties";
        private Transform _miniMapRoot;
        private string _cameraPreset = "top";
        private bool _compactLayout;
        private bool _cameraLocked;
        private bool _drawingsVisible = true;
        private static Sprite _roundedSprite;
        private static Sprite _circleSprite;

        private void Awake()
        {
            DontDestroyOnLoad(gameObject);
            EnsureRoots();
            LoadFlutterPayloadIfAny();
            SeedPlayers();
            BuildInterface();
            SeedProfessionalDemoIfEmpty();
            SetMode(Sportoteka3DProMode.Tactics);
            SetTool(Sportoteka3DProTool.Player);
            SetCameraPreset("top");
            Debug.Log("[Sportoteka3DPro] V16_PRO_INSPECTOR_LIBRARY_HOTFIX active");
        }

        private void Update()
        {
            HandleShortcuts();
            HandleCameraInput();
            HandleDrawingInput();
        }

        private void EnsureRoots()
        {
            _drawingRoot = FindOrCreateRoot("Sportoteka3DProProfessionalDrawings");
            _previewRoot = FindOrCreateRoot("Sportoteka3DProProfessionalPreview");
            _selectionRoot = FindOrCreateRoot("Sportoteka3DProProfessionalSelection");
        }

        private Transform FindOrCreateRoot(string name)
        {
            var found = GameObject.Find(name);
            if (found == null) found = new GameObject(name);
            return found.transform;
        }


        private void LoadFlutterPayloadIfAny()
        {
            try
            {
                var args = System.Environment.GetCommandLineArgs();
                string path = "";

                for (int i = 0; i < args.Length; i++)
                {
                    if (args[i] == "--sportoteka-team-json" && i + 1 < args.Length)
                    {
                        path = args[i + 1];
                        break;
                    }

                    if (args[i].StartsWith("--sportoteka-team-json="))
                    {
                        path = args[i].Substring("--sportoteka-team-json=".Length);
                        break;
                    }
                }

                if (string.IsNullOrEmpty(path) || !File.Exists(path))
                {
                    Debug.Log("[Sportoteka3DPro] Flutter payload not found, using fallback players.");
                    return;
                }

                var json = File.ReadAllText(path);
                var payload = JsonUtility.FromJson<Sportoteka3DProFlutterPayload>(json);
                if (payload == null)
                {
                    Debug.LogWarning("[Sportoteka3DPro] Flutter payload is empty.");
                    return;
                }

                if (!string.IsNullOrEmpty(payload.teamName)) _teamName = payload.teamName;

                _players.Clear();
                if (payload.players != null)
                {
                    foreach (var p in payload.players)
                    {
                        if (p == null) continue;
                        var player = new Sportoteka3DProPlayerData
                        {
                            id = p.id,
                            number = p.number,
                            name = string.IsNullOrEmpty(p.name) ? ("Игрок " + p.number) : p.name,
                            position = string.IsNullOrEmpty(p.position) ? "Игрок" : p.position,
                            role = string.IsNullOrEmpty(p.role) ? "Состав" : p.role,
                            avatarUrl = p.avatarUrl ?? "",
                            avatarPath = p.avatarPath ?? "",
                            initials = string.IsNullOrEmpty(p.initials) ? Sportoteka3DProPlayerData.MakeInitials(p.name, p.number) : p.initials,
                            teamColor = string.IsNullOrEmpty(p.teamColor) ? "#00A750" : p.teamColor
                        };
                        _players.Add(player);
                    }
                }

                Debug.Log("[Sportoteka3DPro] Flutter payload loaded: team=" + _teamName + ", players=" + _players.Count);
            }
            catch (System.Exception e)
            {
                Debug.LogWarning("[Sportoteka3DPro] Failed to load Flutter payload: " + e.Message);
            }
        }

        private void SeedPlayers()
        {
            if (_players.Count > 0) return;

            _players.Add(new Sportoteka3DProPlayerData(1, "Вратарь", "ВР"));
            _players.Add(new Sportoteka3DProPlayerData(2, "Правый защитник", "ПЗ"));
            _players.Add(new Sportoteka3DProPlayerData(3, "Левый защитник", "ЛЗ"));
            _players.Add(new Sportoteka3DProPlayerData(4, "Центральный защитник", "ЦЗ"));
            _players.Add(new Sportoteka3DProPlayerData(5, "Центральный защитник", "ЦЗ"));
            _players.Add(new Sportoteka3DProPlayerData(6, "Опорный полузащитник", "ОП"));
            _players.Add(new Sportoteka3DProPlayerData(8, "Центральный полузащитник", "ЦП"));
            _players.Add(new Sportoteka3DProPlayerData(10, "Атакующий полузащитник", "АП"));
            _players.Add(new Sportoteka3DProPlayerData(7, "Правый крайний", "ПК"));
            _players.Add(new Sportoteka3DProPlayerData(11, "Левый крайний", "ЛК"));
            _players.Add(new Sportoteka3DProPlayerData(9, "Нападающий", "НП"));
            _selectedPlayer = _players[0];
        }

        private void BuildInterface()
        {
            EnsureEventSystem();

            var canvasObj = new GameObject("Sportoteka Football Board Canvas — Premium UI V9");
            canvasObj.transform.SetParent(transform, false);
            _canvas = canvasObj.AddComponent<Canvas>();
            _canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            _canvas.sortingOrder = 1400;

            var scaler = canvasObj.AddComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1672, 941);
            scaler.matchWidthOrHeight = 0.45f;

            canvasObj.AddComponent<GraphicRaycaster>();

            _compactLayout = IsCompactLayout();

            BuildPremiumLeftToolbar(canvasObj.transform);
            BuildPremiumTopBar(canvasObj.transform);
            BuildPremiumBottomDock(canvasObj.transform);

            if (!_compactLayout)
            {
                BuildPremiumInspector(canvasObj.transform);
                BuildPremiumLayersPanel(canvasObj.transform);
                BuildPremiumMiniMap(canvasObj.transform);
            }
            else
            {
                BuildPremiumMobileDock(canvasObj.transform);
            }

            BuildPopupRoot(canvasObj.transform);
        }

        private bool IsCompactLayout()
        {
            return Screen.width > 0 && (Screen.width < 900 || Screen.height > Screen.width);
        }

        private void BuildCleanLeftToolbar(Transform parent)
        {
            var rail = Panel(parent, "Clean Left Toolbar", Color.white, 0, ParseColor("#F0F2F4"));
            Place(rail, Vector2.zero, new Vector2(0, 0), new Vector2(0, 1), new Vector2(58, 0), new Vector2(0, 0.5f));
            _compactRailRoot = rail.transform;
            RefreshCleanLeftToolbar();
        }

        private void RefreshCleanLeftToolbar()
        {
            if (_compactRailRoot == null) return;
            ClearChildren(_compactRailRoot);

            var brand = Panel(_compactRailRoot, "Brand Mark", ParseColor("#FAFBFC"), 14, ParseColor("#F0F2F4"));
            Place(brand, new Vector2(10, -10), new Vector2(0, 1), new Vector2(0, 1), new Vector2(38, 38));
            var bt = Text(brand.transform, "ST", 12, FontStyle.Bold, ParseColor(GreenDark), TextAnchor.MiddleCenter);
            Place(bt.gameObject, Vector2.zero, new Vector2(0, 0), new Vector2(1, 1), Vector2.zero, new Vector2(0.5f, 0.5f), true);

            MiniButton(_compactRailRoot, "×", _compactLayout ? RequestClose : RequestClose, false, new Vector2(10, -54), ParseColor("#FFF1F2"), ParseColor(Red));

            var modeGroup = CleanGroup(_compactRailRoot, "Modes", 10, -104, 38 + 6 * 40);
            MiniButton(modeGroup.transform, "С", () => SetMode(Sportoteka3DProMode.Tactics), _mode == Sportoteka3DProMode.Tactics, new Vector2(5, -8));
            MiniButton(modeGroup.transform, "А", () => SetMode(Sportoteka3DProMode.Analysis), _mode == Sportoteka3DProMode.Analysis, new Vector2(5, -48));
            MiniButton(modeGroup.transform, "У", () => SetMode(Sportoteka3DProMode.Drill), _mode == Sportoteka3DProMode.Drill, new Vector2(5, -88));
            MiniButton(modeGroup.transform, "▶", () => SetMode(Sportoteka3DProMode.Animation), _mode == Sportoteka3DProMode.Animation, new Vector2(5, -128));
            MiniButton(modeGroup.transform, "К", () => SetMode(Sportoteka3DProMode.Calibration), _mode == Sportoteka3DProMode.Calibration, new Vector2(5, -168));
            MiniButton(modeGroup.transform, "Б", () => SetMode(Sportoteka3DProMode.Branding), _mode == Sportoteka3DProMode.Branding, new Vector2(5, -208));

            var toolsTop = _compactLayout ? -372 : -382;
            var toolGroup = CleanGroup(_compactRailRoot, "Tools", 10, toolsTop, 14 + 9 * 40);
            MiniButton(toolGroup.transform, "↖", () => SetTool(Sportoteka3DProTool.Select), _tool == Sportoteka3DProTool.Select, new Vector2(5, -8));
            MiniButton(toolGroup.transform, "●", () => SetTool(Sportoteka3DProTool.Player), _tool == Sportoteka3DProTool.Player, new Vector2(5, -48));
            MiniButton(toolGroup.transform, "○", () => SetTool(Sportoteka3DProTool.Opponent), _tool == Sportoteka3DProTool.Opponent, new Vector2(5, -88));
            MiniButton(toolGroup.transform, "⚽", () => SetTool(Sportoteka3DProTool.Ball), _tool == Sportoteka3DProTool.Ball, new Vector2(5, -128), ParseColor("#F8FAFC"), ParseColor(Graphite), 13);
            MiniButton(toolGroup.transform, "→", () => SetTool(Sportoteka3DProTool.PassArrow), _tool == Sportoteka3DProTool.PassArrow, new Vector2(5, -168));
            MiniButton(toolGroup.transform, "≋", () => SetTool(Sportoteka3DProTool.RunArrow), _tool == Sportoteka3DProTool.RunArrow, new Vector2(5, -208));
            MiniButton(toolGroup.transform, "▧", () => SetTool(Sportoteka3DProTool.HatchedZone), _tool == Sportoteka3DProTool.HatchedZone, new Vector2(5, -248));
            MiniButton(toolGroup.transform, "▲", () => SetTool(Sportoteka3DProTool.Cone), _tool == Sportoteka3DProTool.Cone, new Vector2(5, -288));
            MiniButton(toolGroup.transform, "T", () => SetTool(Sportoteka3DProTool.Text), _tool == Sportoteka3DProTool.Text, new Vector2(5, -328));

            if (!_compactLayout)
            {
                var bottomGroup = CleanGroup(_compactRailRoot, "View", 10, -740, 94);
                MiniButton(bottomGroup.transform, "2D", () => SetCameraPreset("top"), false, new Vector2(5, -8), ParseColor("#F8FAFC"), ParseColor(Graphite), 10);
                MiniButton(bottomGroup.transform, "3D", () => SetCameraPreset("tactical"), false, new Vector2(5, -48), ParseColor("#F8FAFC"), ParseColor(Graphite), 10);
            }
        }

        private GameObject CleanGroup(Transform parent, string name, float x, float y, float height)
        {
            var group = Panel(parent, name, ParseColor("#FAFBFC"), 18, ParseColor("#F0F2F4"));
            Place(group, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1), new Vector2(38, height));
            return group;
        }

        private Button MiniButton(Transform parent, string label, UnityEngine.Events.UnityAction action, bool active, Vector2 pos)
        {
            return MiniButton(parent, label, action, active, pos, active ? ParseColor("#F3FBF7") : Color.clear, active ? ParseColor(Green) : ParseColor("#6B7280"));
        }

        private Button MiniButton(Transform parent, string label, UnityEngine.Events.UnityAction action, bool active, Vector2 pos, Color bg, Color fg, int fontSize = 15)
        {
            var obj = Panel(parent, "Mini " + label, bg, 13, active ? ParseColor("#BFEBD5") : (Color?)null);
            Place(obj, pos, new Vector2(0, 1), new Vector2(0, 1), new Vector2(28, 32));
            var btn = obj.AddComponent<Button>();
            btn.targetGraphic = obj.GetComponent<Image>();
            btn.onClick.AddListener(action);

            if (active)
            {
                var mark = Panel(obj.transform, "Active Mark", ParseColor(Green), 2);
                Place(mark, new Vector2(3, -11), new Vector2(0, 1), new Vector2(0, 1), new Vector2(3, 10));
            }

            var text = Text(obj.transform, label, fontSize, FontStyle.Bold, fg, TextAnchor.MiddleCenter);
            Place(text.gameObject, Vector2.zero, new Vector2(0, 0), new Vector2(1, 1), Vector2.zero, new Vector2(0.5f, 0.5f), true);
            return btn;
        }

        private void BuildCleanTopBar(Transform parent)
        {
            var w = _compactLayout ? 390f : 760f;
            var h = _compactLayout ? 48f : 54f;
            var bar = Panel(parent, "Clean Top Bar", WithAlpha(Color.white, 0.94f), 18, ParseColor("#F0F2F4"));
            Place(bar, new Vector2(72, -10), new Vector2(0, 1), new Vector2(0, 1), new Vector2(w, h));

            var title = Text(bar.transform, _compactLayout ? "Football Board" : "Sportoteka Football Board", _compactLayout ? 15 : 17, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(title.gameObject, new Vector2(16, -8), new Vector2(0, 1), new Vector2(0, 1), new Vector2(260, 22));
            _modeText = title;

            var sub = Text(bar.transform, ModeTitle(_mode) + " • " + _teamName, _compactLayout ? 9 : 10, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
            Place(sub.gameObject, new Vector2(16, -29), new Vector2(0, 1), new Vector2(0, 1), new Vector2(w - 32, 16));

            if (!_compactLayout)
            {
                var close = TextButton(bar.transform, "Закрыть", RequestClose, ParseColor("#FFF1F2"), ParseColor(Red), 82, 32, 10);
                Place(close.gameObject, new Vector2(w - 94, -11), new Vector2(0, 1), new Vector2(0, 1));
                var save = TextButton(bar.transform, "Сохранить", SavePlan, ParseColor(Graphite), Color.white, 96, 32, 10);
                Place(save.gameObject, new Vector2(w - 198, -11), new Vector2(0, 1), new Vector2(0, 1));
                var png = TextButton(bar.transform, "PNG", ExportPng, ParseColor("#ECFDF5"), ParseColor(GreenDark), 54, 32, 10);
                Place(png.gameObject, new Vector2(w - 260, -11), new Vector2(0, 1), new Vector2(0, 1));
                var top = TextButton(bar.transform, "2D", () => SetCameraPreset("top"), ParseColor("#F8FAFC"), ParseColor(Graphite), 48, 32, 10);
                Place(top.gameObject, new Vector2(w - 316, -11), new Vector2(0, 1), new Vector2(0, 1));
                var tactical = TextButton(bar.transform, "3D", () => SetCameraPreset("tactical"), ParseColor("#F8FAFC"), ParseColor(Graphite), 48, 32, 10);
                Place(tactical.gameObject, new Vector2(w - 372, -11), new Vector2(0, 1), new Vector2(0, 1));
            }
        }

        private void BuildCleanModeChips(Transform parent)
        {
            var w = _compactLayout ? 390f : 850f;
            var h = _compactLayout ? 44f : 52f;
            var panel = Panel(parent, "Clean Mode Chips", WithAlpha(Color.white, 0.92f), 18, ParseColor("#F0F2F4"));
            Place(panel, new Vector2(72, _compactLayout ? -64 : -74), new Vector2(0, 1), new Vector2(0, 1), new Vector2(w, h));
            _modePanelRoot = panel.transform;
            RefreshModeActionPanel();
        }

        private void BuildCleanToolDock(Transform parent)
        {
            if (_compactLayout) return;
            var dock = Panel(parent, "Clean Tool Dock", WithAlpha(ParseColor("#080C13"), 0.86f), 20);
            Place(dock, new Vector2(76, 24), new Vector2(0, 0), new Vector2(0, 0), new Vector2(860, 64));
            _compactDockRoot = dock.transform;

            DockButton(dock.transform, "↖", "Выбор", () => SetTool(Sportoteka3DProTool.Select), 14);
            DockButton(dock.transform, "●", "Игрок", () => SetTool(Sportoteka3DProTool.Player), 74);
            DockButton(dock.transform, "○", "Сопер.", () => SetTool(Sportoteka3DProTool.Opponent), 134);
            DockButton(dock.transform, "⚽", "Мяч", () => SetTool(Sportoteka3DProTool.Ball), 194);
            DockButton(dock.transform, "→", "Пас", () => SetTool(Sportoteka3DProTool.PassArrow), 254);
            DockButton(dock.transform, "≋", "Рывок", () => SetTool(Sportoteka3DProTool.RunArrow), 314);
            DockButton(dock.transform, "⌒", "Кривая", () => SetTool(Sportoteka3DProTool.CurveArrow), 374);
            DockButton(dock.transform, "▧", "Зона", () => SetTool(Sportoteka3DProTool.HatchedZone), 434);
            DockButton(dock.transform, "◉", "Фокус", () => SetTool(Sportoteka3DProTool.Spotlight), 494);
            DockButton(dock.transform, "↔", "Связь", () => SetTool(Sportoteka3DProTool.Matchup), 554);
            DockButton(dock.transform, "m", "Метры", () => SetTool(Sportoteka3DProTool.Measurement), 614);
            DockButton(dock.transform, "▲", "Конус", () => SetTool(Sportoteka3DProTool.Cone), 674);
            DockButton(dock.transform, "T", "Текст", () => SetTool(Sportoteka3DProTool.Text), 734);
        }

        private void DockButton(Transform parent, string icon, string title, UnityEngine.Events.UnityAction action, float x)
        {
            var b = TextButton(parent, icon, action, ParseColor("#111827"), Color.white, 40, 34, icon.Length > 1 ? 10 : 14);
            Place(b.gameObject, new Vector2(x, -8), new Vector2(0, 1), new Vector2(0, 1));
            var t = Text(parent, title, 8, FontStyle.Bold, Color.white, TextAnchor.MiddleCenter);
            Place(t.gameObject, new Vector2(x - 6, -44), new Vector2(0, 1), new Vector2(0, 1), new Vector2(52, 12));
        }

        private void BuildCleanPlayerBench(Transform parent)
        {
            if (_compactLayout) return;
            var strip = Panel(parent, "Clean Player Bench", WithAlpha(Color.white, 0.92f), 18, ParseColor("#F0F2F4"));
            Place(strip, new Vector2(76, 96), new Vector2(0, 0), new Vector2(0, 0), new Vector2(700, 50));

            int max = Mathf.Min(10, _players.Count);
            for (int i = 0; i < max; i++)
            {
                var player = _players[i];
                var btn = TextButton(strip.transform, player.initials, () => SelectPlayer(player), player == _selectedPlayer ? ParseColor(Green) : ParseColor("#F8FAFC"), player == _selectedPlayer ? Color.white : ParseColor(Graphite), 54, 34, 10);
                Place(btn.gameObject, new Vector2(12 + i * 66, -8), new Vector2(0, 1), new Vector2(0, 1));
            }
        }

        private void BuildCleanInspector(Transform parent)
        {
            var panel = Panel(parent, "Clean Inspector", WithAlpha(Color.white, 0.94f), 18, ParseColor("#F0F2F4"));
            Place(panel, new Vector2(-20, -86), new Vector2(1, 1), new Vector2(1, 1), new Vector2(250, 184), new Vector2(1, 1));
            _compactInspectorRoot = panel.transform;

            var title = Text(panel.transform, "Инспектор", 13, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(title.gameObject, new Vector2(14, -10), new Vector2(0, 1), new Vector2(0, 1), new Vector2(190, 20));
            _selectedText = title;

            var colors = new[] { Green, "#FDE047", "#38BDF8", "#F97316", "#F43F5E", "#FFFFFF", "#111827" };
            for (int i = 0; i < colors.Length; i++) ColorDot(panel.transform, colors[i], 14 + i * 30, -42);

            _widthSlider = Slider(panel.transform, "Толщина", 0.035f, 0.30f, _activeWidth, SetLineWidth);
            Place(_widthSlider.gameObject, new Vector2(14, -78), new Vector2(0, 1), new Vector2(0, 1), new Vector2(220, 20));
            _alphaSlider = Slider(panel.transform, "Прозрачность", 0.10f, 1.0f, _activeAlpha, SetAlpha);
            Place(_alphaSlider.gameObject, new Vector2(14, -104), new Vector2(0, 1), new Vector2(0, 1), new Vector2(220, 20));

            var del = TextButton(panel.transform, "Удалить", DeleteSelected, ParseColor("#FFF1F2"), ParseColor(Red), 74, 28, 10);
            Place(del.gameObject, new Vector2(14, -138), new Vector2(0, 1), new Vector2(0, 1));
            var copy = TextButton(panel.transform, "Копия", DuplicateSelected, ParseColor("#F8FAFC"), ParseColor(Graphite), 64, 28, 10);
            Place(copy.gameObject, new Vector2(96, -138), new Vector2(0, 1), new Vector2(0, 1));
            var apply = TextButton(panel.transform, "Стиль", ApplyStyleToSelected, ParseColor("#ECFDF5"), ParseColor(GreenDark), 64, 28, 10);
            Place(apply.gameObject, new Vector2(168, -138), new Vector2(0, 1), new Vector2(0, 1));
        }

        private void BuildCleanCameraPad(Transform parent)
        {
            var panel = Panel(parent, "Clean Camera", WithAlpha(Color.white, 0.92f), 18, ParseColor("#F0F2F4"));
            Place(panel, new Vector2(-20, 24), new Vector2(1, 0), new Vector2(1, 0), new Vector2(214, 88), new Vector2(1, 0));
            Analog(panel.transform, "↑", () => PanCamera(0, 1.5f), 86, -12);
            Analog(panel.transform, "←", () => PanCamera(-1.5f, 0), 48, -42);
            Analog(panel.transform, "•", () => SetCameraPreset("tactical"), 86, -42);
            Analog(panel.transform, "→", () => PanCamera(1.5f, 0), 124, -42);
            Analog(panel.transform, "+", () => ZoomCamera(3.0f), 164, -12);
            Analog(panel.transform, "−", () => ZoomCamera(-3.0f), 164, -50);
        }

        private void BuildCleanTimeline(Transform parent)
        {
            var panel = Panel(parent, "Clean Timeline", WithAlpha(Color.white, 0.92f), 18, ParseColor("#F0F2F4"));
            Place(panel, new Vector2(792, 24), new Vector2(0, 0), new Vector2(0, 0), new Vector2(326, 50));
            var save = TextButton(panel.transform, "+ Кадр", SaveFrame, ParseColor("#F8FAFC"), ParseColor(Graphite), 66, 30, 10);
            Place(save.gameObject, new Vector2(12, -10), new Vector2(0, 1), new Vector2(0, 1));
            var play = TextButton(panel.transform, "Пуск", PlayFrames, ParseColor(Graphite), Color.white, 58, 30, 10);
            Place(play.gameObject, new Vector2(86, -10), new Vector2(0, 1), new Vector2(0, 1));
            var preset = TextButton(panel.transform, "Шаблон", ApplyModePreset, ParseColor("#ECFDF5"), ParseColor(GreenDark), 76, 30, 10);
            Place(preset.gameObject, new Vector2(152, -10), new Vector2(0, 1), new Vector2(0, 1));
            var json = TextButton(panel.transform, "JSON", ExportJson, ParseColor("#F8FAFC"), ParseColor(Graphite), 58, 30, 10);
            Place(json.gameObject, new Vector2(236, -10), new Vector2(0, 1), new Vector2(0, 1));
        }

        private void BuildCleanStatus(Transform parent)
        {
            var panel = Panel(parent, "Clean Status", WithAlpha(ParseColor("#080C13"), _compactLayout ? 0.78f : 0.70f), 14);
            if (_compactLayout)
                Place(panel, new Vector2(72, 18), new Vector2(0, 0), new Vector2(0, 0), new Vector2(390, 34));
            else
                Place(panel, new Vector2(76, 164), new Vector2(0, 0), new Vector2(0, 0), new Vector2(700, 34));

            _statusText = Text(panel.transform, "Готово: выбери режим слева и инструмент.", 10, FontStyle.Bold, Color.white, TextAnchor.MiddleLeft);
            Place(_statusText.gameObject, new Vector2(14, 0), new Vector2(0, 0.5f), new Vector2(0, 0.5f), new Vector2(_compactLayout ? 360 : 670, 24), new Vector2(0, 0.5f));
        }

        private void BuildTopBar(Transform parent)
        {
            var bar = Panel(parent, "Top Bar", Color.white, 0);
            Place(bar, Vector2.zero, new Vector2(0, 1), new Vector2(1, 1), new Vector2(0, 62), new Vector2(0.5f, 1));

            var accent = Panel(bar.transform, "Football Accent", ParseColor(Green), 0);
            Place(accent, Vector2.zero, new Vector2(0, 0), new Vector2(1, 0), new Vector2(0, 3), new Vector2(0.5f, 0));

            var close = TextButton(bar.transform, "Закрыть", RequestClose, ParseColor("#FFF1F2"), ParseColor(Red), 104, 38);
            Place(close.gameObject, new Vector2(18, -12), new Vector2(0, 1), new Vector2(0, 1));

            _modeText = Text(bar.transform, "Sportoteka Football Board • " + _teamName, 16, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(_modeText.gameObject, new Vector2(142, -9), new Vector2(0, 1), new Vector2(0, 1), new Vector2(610, 24));

            var sub = Text(bar.transform, "Только футбол: 2D/3D тактика, упражнения, прессинг, стандарты, Field Radar, калибровка и экспорт", 11, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
            Place(sub.gameObject, new Vector2(142, -34), new Vector2(0, 1), new Vector2(0, 1), new Vector2(780, 18));

            var save = TextButton(bar.transform, "Сохранить", SavePlan, ParseColor(Graphite), Color.white, 118, 40);
            Place(save.gameObject, new Vector2(-14, -10), new Vector2(1, 1), new Vector2(1, 1));

            var png = TextButton(bar.transform, "PNG", ExportPng, ParseColor("#ECFDF5"), ParseColor(GreenDark), 64, 36, 11);
            Place(png.gameObject, new Vector2(-140, -12), new Vector2(1, 1), new Vector2(1, 1));

            var json = TextButton(bar.transform, "JSON", ExportJson, ParseColor("#F8FAFC"), ParseColor(Graphite), 68, 36, 11);
            Place(json.gameObject, new Vector2(-212, -12), new Vector2(1, 1), new Vector2(1, 1));

            var load = TextButton(bar.transform, "Открыть", LoadPlan, ParseColor("#F8FAFC"), ParseColor(Graphite), 82, 36, 10);
            Place(load.gameObject, new Vector2(-290, -12), new Vector2(1, 1), new Vector2(1, 1));

            var top = TextButton(bar.transform, "2D", () => SetCameraPreset("top"), ParseColor("#F8FAFC"), ParseColor(Graphite), 54, 36, 11);
            Place(top.gameObject, new Vector2(-380, -12), new Vector2(1, 1), new Vector2(1, 1));

            var tactical = TextButton(bar.transform, "3D", () => SetCameraPreset("tactical"), ParseColor("#F8FAFC"), ParseColor(Graphite), 54, 36, 11);
            Place(tactical.gameObject, new Vector2(-440, -12), new Vector2(1, 1), new Vector2(1, 1));

            var roster = TextButton(bar.transform, "Состав", ShowPlayerPicker, ParseColor("#ECFDF5"), ParseColor(GreenDark), 82, 36, 10);
            Place(roster.gameObject, new Vector2(-502, -12), new Vector2(1, 1), new Vector2(1, 1));
        }

        private void BuildModeActionPanel(Transform parent)
        {
            var panel = Panel(parent, "Mode Action Panel", Color.white, 18, ParseColor(Border));
            Place(panel, new Vector2(-120, -74), new Vector2(0.5f, 1), new Vector2(0.5f, 1), new Vector2(860, 96), new Vector2(0.5f, 1));
            _modePanelRoot = panel.transform;
            RefreshModeActionPanel();
        }

        private void RefreshModeActionPanel()
        {
            if (_modePanelRoot == null) return;
            ClearChildren(_modePanelRoot);

            var title = Text(_modePanelRoot, ModeTitle(_mode), _compactLayout ? 11 : 12, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(title.gameObject, new Vector2(14, -6), new Vector2(0, 1), new Vector2(0, 1), new Vector2(_compactLayout ? 100 : 150, 18));

            float x = _compactLayout ? 104f : 170f;
            float y = _compactLayout ? -9f : -12f;
            float gap = _compactLayout ? 54f : 72f;

            if (_mode == Sportoteka3DProMode.Tactics)
            {
                Chip("4-3-3", ApplyModePreset, x, y, 58); x += 64;
                Chip("Билдап", ApplyBuildUpPreset, x, y, 70); x += 76;
                Chip("Контр.", () => AddPresetList(Sportoteka3DProPresets.CounterAttack3v2Pack(), "Добавлена контратака 3v2"), x, y, 68); x += 74;
                Chip("Угл.", ApplySetPiecePreset, x, y, 52); x += 58;
                Chip("PRO", ShowProLibrary, x, y, 52);
            }
            else if (_mode == Sportoteka3DProMode.Analysis)
            {
                Chip("Пресс", ApplyPressingPreset, x, y, 62); x += 68;
                Chip("Radar", ApplyFieldRadarPreset, x, y, 62); x += 68;
                Chip("Офсайд", () => SetTool(Sportoteka3DProTool.Offside), x, y, 70); x += 76;
                Chip("Метры", () => SetTool(Sportoteka3DProTool.Measurement), x, y, 62); x += 68;
                Chip("PRO", ShowProLibrary, x, y, 52);
            }
            else if (_mode == Sportoteka3DProMode.Drill)
            {
                Chip("Рондо", () => AddPresetList(Sportoteka3DProPresets.Rondo5v2Pack(), "Добавлено рондо 5v2"), x, y, 62); x += 68;
                Chip("Станции", () => AddPresetList(Sportoteka3DProPresets.SpeedStationsPack(), "Добавлены скоростные станции"), x, y, 78); x += 84;
                Chip("Конус", () => SetTool(Sportoteka3DProTool.Cone), x, y, 64); x += 70;
                Chip("Манек.", () => SetTool(Sportoteka3DProTool.Mannequin), x, y, 70); x += 76;
                Chip("PRO", ShowProLibrary, x, y, 52);
            }
            else if (_mode == Sportoteka3DProMode.Animation)
            {
                Chip("+ кадр", SaveFrame, x, y, 66); x += 72;
                Chip("Пуск", PlayFrames, x, y, 58); x += 64;
                Chip("Пример", AddAnimationExample, x, y, 70); x += 76;
                Chip("Шаблон", ApplyModePreset, x, y, 78);
            }
            else if (_mode == Sportoteka3DProMode.Calibration)
            {
                Chip("4 точки", ApplyModePreset, x, y, 72); x += 78;
                Chip("Точка", () => SetTool(Sportoteka3DProTool.CalibrationMarker), x, y, 62); x += 68;
                Chip("Метры", () => SetTool(Sportoteka3DProTool.Measurement), x, y, 62); x += 68;
                Chip("2D", () => SetCameraPreset("top"), x, y, 48);
            }
            else if (_mode == Sportoteka3DProMode.Branding)
            {
                Chip("Show", ApplyShowcasePreset, x, y, 58); x += 64;
                Chip("Текст", () => SetTool(Sportoteka3DProTool.Text), x, y, 58); x += 64;
                Chip("PNG", ExportPng, x, y, 50); x += 56;
                Chip("JSON", ExportJson, x, y, 58);
            }
        }

        private void Chip(string title, UnityEngine.Events.UnityAction action, float x, float y, float width)
        {
            if (_modePanelRoot == null) return;
            var btn = TextButton(_modePanelRoot, title, action, ParseColor("#F8FAFC"), ParseColor(Graphite), width, _compactLayout ? 26 : 28, 9);
            Place(btn.gameObject, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1));
        }

        private string ModeHint(Sportoteka3DProMode mode)
        {
            switch (mode)
            {
                case Sportoteka3DProMode.Tactics:
                    return "Тактическая доска футбольного тренера: расстановка, билдап, стандарты, пасы, рывки и зоны.";
                case Sportoteka3DProMode.Analysis:
                    return "Видеоаналитический слой без импорта видео: прессинг, офсайд, связи, дистанции, Field Radar и зоны давления.";
                case Sportoteka3DProMode.Drill:
                    return "Дизайн футбольных упражнений: конусы, манекены, лестницы, барьеры, гейты, мячи и мини-ворота.";
                case Sportoteka3DProMode.Animation:
                    return "Анимированные тактические последовательности: сохраняй кадры, двигай игроков и проигрывай сценарий.";
                case Sportoteka3DProMode.Calibration:
                    return "Футбольная калибровка 105×68: точки поля, реальные расстояния в метрах и 2D-вид сверху.";
                case Sportoteka3DProMode.Branding:
                    return "Презентационный слой: клубный стиль, подписи, брифинг для команды, PNG/JSON экспорт.";
                default:
                    return "";
            }
        }

        private void ModeAction(string title, UnityEngine.Events.UnityAction action, float x, float y, float width = 72)
        {
            var button = TextButton(_modePanelRoot, title, action, ParseColor("#F8FAFC"), ParseColor(Graphite), width, 24, 9);
            Place(button.gameObject, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1));
        }

        private void BuildModeRail(Transform parent)
        {
            var rail = Panel(parent, "Mode Rail", Color.white, 0, ParseColor("#EEF1F4"));
            Place(rail, Vector2.zero, new Vector2(0, 0), new Vector2(0, 1), new Vector2(96, 0), new Vector2(0, 0.5f));

            var brand = Text(rail.transform, "FOOTBALL", 9, FontStyle.Bold, ParseColor(GreenDark), TextAnchor.MiddleCenter);
            Place(brand.gameObject, new Vector2(8, -72), new Vector2(0, 1), new Vector2(0, 1), new Vector2(80, 16));

            ModeButton(rail.transform, "Схема", () => SetMode(Sportoteka3DProMode.Tactics), 96);
            ModeButton(rail.transform, "Анализ", () => SetMode(Sportoteka3DProMode.Analysis), 150);
            ModeButton(rail.transform, "Упр.", () => SetMode(Sportoteka3DProMode.Drill), 204);
            ModeButton(rail.transform, "Аним.", () => SetMode(Sportoteka3DProMode.Animation), 258);
            ModeButton(rail.transform, "Калибр.", () => SetMode(Sportoteka3DProMode.Calibration), 312);
            ModeButton(rail.transform, "Брифинг", () => SetMode(Sportoteka3DProMode.Branding), 366);
            ModeButton(rail.transform, "Очистить", ClearPlan, 760);
        }

        private void ModeButton(Transform parent, string title, UnityEngine.Events.UnityAction action, float y)
        {
            var btn = TextButton(parent, title, action, ParseColor("#F8FAFC"), ParseColor(Graphite), 86, 40);
            Place(btn.gameObject, new Vector2(5, -y), new Vector2(0, 1), new Vector2(0, 1));
        }

        private void BuildProfessionalToolbar(Transform parent)
        {
            var bar = Panel(parent, "Professional Toolbar", WithAlpha(ParseColor("#080C13"), 0.92f), 18);
            Place(bar, new Vector2(-120, 72), new Vector2(0.5f, 0), new Vector2(0.5f, 0), new Vector2(1030, 76), new Vector2(0.5f, 0));

            ToolbarButton(bar.transform, "↖", "Выбор", () => SetTool(Sportoteka3DProTool.Select), 14);
            ToolbarButton(bar.transform, "●", "Игрок", () => SetTool(Sportoteka3DProTool.Player), 78);
            ToolbarButton(bar.transform, "○", "Сопер.", () => SetTool(Sportoteka3DProTool.Opponent), 142);
            ToolbarButton(bar.transform, "⚽", "Мяч", () => SetTool(Sportoteka3DProTool.Ball), 206);
            ToolbarButton(bar.transform, "→", "Пас", () => SetTool(Sportoteka3DProTool.PassArrow), 270);
            ToolbarButton(bar.transform, "≋", "Рывок", () => SetTool(Sportoteka3DProTool.RunArrow), 334);
            ToolbarButton(bar.transform, "⌒", "Кривая", () => SetTool(Sportoteka3DProTool.CurveArrow), 398);
            ToolbarButton(bar.transform, "—", "Линия", () => SetTool(Sportoteka3DProTool.Line), 462);
            ToolbarButton(bar.transform, "▧", "Зона", () => SetTool(Sportoteka3DProTool.HatchedZone), 526);
            ToolbarButton(bar.transform, "◉", "Фокус", () => SetTool(Sportoteka3DProTool.Spotlight), 590);
            ToolbarButton(bar.transform, "↔", "Связь", () => SetTool(Sportoteka3DProTool.Matchup), 654);
            ToolbarButton(bar.transform, "OFF", "Офсайд", () => SetTool(Sportoteka3DProTool.Offside), 718);
            ToolbarButton(bar.transform, "m", "Метры", () => SetTool(Sportoteka3DProTool.Measurement), 782);
            ToolbarButton(bar.transform, "▲", "Конус", () => SetTool(Sportoteka3DProTool.Cone), 846);
            ToolbarButton(bar.transform, "▥", "Манек.", () => SetTool(Sportoteka3DProTool.Mannequin), 910);
            ToolbarButton(bar.transform, "Т", "Текст", () => SetTool(Sportoteka3DProTool.Text), 974);
        }

        private void ToolbarButton(Transform parent, string icon, string title, UnityEngine.Events.UnityAction action, float x)
        {
            var b = TextButton(parent, icon, action, ParseColor("#111827"), Color.white, 46, 42, 14);
            Place(b.gameObject, new Vector2(x, -8), new Vector2(0, 1), new Vector2(0, 1));
            var t = Text(parent, title, 8, FontStyle.Bold, Color.white, TextAnchor.MiddleCenter);
            Place(t.gameObject, new Vector2(x - 4, -52), new Vector2(0, 1), new Vector2(0, 1), new Vector2(54, 12));
        }

        private void BuildPlayerBench(Transform parent)
        {
            var strip = Panel(parent, "Player Bench", WithAlpha(ParseColor("#080C13"), 0.78f), 18);
            Place(strip, new Vector2(-120, 148), new Vector2(0.5f, 0), new Vector2(0.5f, 0), new Vector2(780, 56), new Vector2(0.5f, 0));

            int max = Mathf.Min(10, _players.Count);
            for (int i = 0; i < max; i++)
            {
                var player = _players[i];
                var btn = TextButton(strip.transform, player.initials, () => SelectPlayer(player), player == _selectedPlayer ? ParseColor(GreenDark) : ParseColor("#111827"), Color.white, 58, 40);
                Place(btn.gameObject, new Vector2(12 + i * 70, -8), new Vector2(0, 1), new Vector2(0, 1));
            }
        }

        private void BuildStylePanel(Transform parent)
        {
            var panel = Panel(parent, "Style Panel", Color.white, 16, ParseColor(Border));
            Place(panel, new Vector2(-20, -74), new Vector2(1, 1), new Vector2(1, 1), new Vector2(240, 122), new Vector2(1, 1));

            var title = Text(panel.transform, "Цвет / толщина / прозрачность", 12, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(title.gameObject, new Vector2(12, -8), new Vector2(0, 1), new Vector2(0, 1), new Vector2(160, 18));

            string[] colors = { Green, "#FDE047", "#38BDF8", "#F97316", "#F43F5E", "#FFFFFF", "#111827" };
            for (int i = 0; i < colors.Length; i++)
            {
                ColorDot(panel.transform, colors[i], 12 + i * 30, -34);
            }

            _widthSlider = Slider(panel.transform, "Толщина", 0.035f, 0.30f, _activeWidth, SetLineWidth);
            Place(_widthSlider.gameObject, new Vector2(12, -68), new Vector2(0, 1), new Vector2(0, 1), new Vector2(205, 20));

            _alphaSlider = Slider(panel.transform, "Прозрачность", 0.10f, 1.0f, _activeAlpha, SetAlpha);
            Place(_alphaSlider.gameObject, new Vector2(12, -94), new Vector2(0, 1), new Vector2(0, 1), new Vector2(205, 20));
        }

        private void BuildSelectionInspector(Transform parent)
        {
            var panel = Panel(parent, "Object Inspector", Color.white, 16, ParseColor(Border));
            Place(panel, new Vector2(-20, -210), new Vector2(1, 1), new Vector2(1, 1), new Vector2(240, 138), new Vector2(1, 1));

            _selectedText = Text(panel.transform, "Редактирование объекта", 12, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(_selectedText.gameObject, new Vector2(12, -8), new Vector2(0, 1), new Vector2(0, 1), new Vector2(205, 18));

            var del = TextButton(panel.transform, "Удалить", DeleteSelected, ParseColor("#FFF1F2"), ParseColor(Red), 70, 26, 10);
            Place(del.gameObject, new Vector2(12, -38), new Vector2(0, 1), new Vector2(0, 1));
            var copy = TextButton(panel.transform, "Копия", DuplicateSelected, ParseColor("#F8FAFC"), ParseColor(Graphite), 58, 26, 10);
            Place(copy.gameObject, new Vector2(88, -38), new Vector2(0, 1), new Vector2(0, 1));
            var plus = TextButton(panel.transform, "+", () => ScaleSelected(1.12f), ParseColor("#F8FAFC"), ParseColor(Graphite), 32, 26, 12);
            Place(plus.gameObject, new Vector2(152, -38), new Vector2(0, 1), new Vector2(0, 1));
            var minus = TextButton(panel.transform, "−", () => ScaleSelected(0.90f), ParseColor("#F8FAFC"), ParseColor(Graphite), 32, 26, 12);
            Place(minus.gameObject, new Vector2(190, -38), new Vector2(0, 1), new Vector2(0, 1));

            var rl = TextButton(panel.transform, "⟲", () => RotateSelected(-10), ParseColor("#F8FAFC"), ParseColor(Graphite), 44, 26, 12);
            Place(rl.gameObject, new Vector2(12, -72), new Vector2(0, 1), new Vector2(0, 1));
            var rr = TextButton(panel.transform, "⟳", () => RotateSelected(10), ParseColor("#F8FAFC"), ParseColor(Graphite), 44, 26, 12);
            Place(rr.gameObject, new Vector2(62, -72), new Vector2(0, 1), new Vector2(0, 1));
            var front = TextButton(panel.transform, "Поверх", BringSelectedToFront, ParseColor("#F8FAFC"), ParseColor(Graphite), 66, 26, 10);
            Place(front.gameObject, new Vector2(112, -72), new Vector2(0, 1), new Vector2(0, 1));
            var reset = TextButton(panel.transform, "Сброс", ResetSelected, ParseColor("#F8FAFC"), ParseColor(Graphite), 54, 26, 10);
            Place(reset.gameObject, new Vector2(184, -72), new Vector2(0, 1), new Vector2(0, 1));

            var apply = TextButton(panel.transform, "Применить стиль к объекту", ApplyStyleToSelected, ParseColor("#ECFDF5"), ParseColor(GreenDark), 210, 26, 10);
            Place(apply.gameObject, new Vector2(12, -104), new Vector2(0, 1), new Vector2(0, 1));
        }

        private void BuildHelpPanel(Transform parent)
        {
            var panel = Panel(parent, "Help Panel", Color.white, 16, ParseColor(Border));
            Place(panel, new Vector2(-20, -360), new Vector2(1, 1), new Vector2(1, 1), new Vector2(240, 128), new Vector2(1, 1));

            var title = Text(panel.transform, "Как работать", 12, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(title.gameObject, new Vector2(12, -8), new Vector2(0, 1), new Vector2(0, 1), new Vector2(205, 18));

            var t1 = Text(panel.transform, "1. Слева: Схема / Анализ / Упражнение", 9, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
            Place(t1.gameObject, new Vector2(12, -34), new Vector2(0, 1), new Vector2(0, 1), new Vector2(214, 16));

            var t2 = Text(panel.transform, "2. Снизу: игроки, мяч, пас, рывок, зона", 9, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
            Place(t2.gameObject, new Vector2(12, -54), new Vector2(0, 1), new Vector2(0, 1), new Vector2(214, 16));

            var t3 = Text(panel.transform, "3. ЛКМ — поставить или начертить", 9, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
            Place(t3.gameObject, new Vector2(12, -74), new Vector2(0, 1), new Vector2(0, 1), new Vector2(214, 16));

            var t4 = Text(panel.transform, "4. Выбор → объект → стиль/удаление", 9, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
            Place(t4.gameObject, new Vector2(12, -94), new Vector2(0, 1), new Vector2(0, 1), new Vector2(214, 16));
        }

        private void BuildCameraPad(Transform parent)
        {
            var panel = Panel(parent, "Camera Pad", Color.white, 16, ParseColor(Border));
            Place(panel, new Vector2(-270, 16), new Vector2(1, 0), new Vector2(1, 0), new Vector2(214, 128), new Vector2(1, 0));
            var title = Text(panel.transform, "Камера", 11, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(title.gameObject, new Vector2(12, -8), new Vector2(0, 1), new Vector2(0, 1), new Vector2(90, 16));
            Analog(panel.transform, "↑", () => PanCamera(0, 3), 68, -32);
            Analog(panel.transform, "←", () => RotateCamera(-10), 30, -66);
            Analog(panel.transform, "●", () => SetCameraPreset("tactical"), 68, -66);
            Analog(panel.transform, "→", () => RotateCamera(10), 106, -66);
            Analog(panel.transform, "↓", () => PanCamera(0, -3), 68, -100);
            Analog(panel.transform, "+", () => ZoomCamera(-6), 158, -38);
            Analog(panel.transform, "−", () => ZoomCamera(6), 158, -78);
        }

        private void BuildTimeline(Transform parent)
        {
            var panel = Panel(parent, "Timeline", WithAlpha(ParseColor("#080C13"), 0.76f), 16);
            Place(panel, new Vector2(-120, 218), new Vector2(0.5f, 0), new Vector2(0.5f, 0), new Vector2(610, 42), new Vector2(0.5f, 0));
            var save = TextButton(panel.transform, "+ Кадр", SaveFrame, ParseColor("#111827"), Color.white, 62, 28, 10);
            Place(save.gameObject, new Vector2(12, -7), new Vector2(0, 1), new Vector2(0, 1));
            var play = TextButton(panel.transform, "Пуск", PlayFrames, ParseColor("#111827"), Color.white, 56, 28, 10);
            Place(play.gameObject, new Vector2(80, -7), new Vector2(0, 1), new Vector2(0, 1));
            for (int i = 1; i <= 5; i++)
            {
                int frame = i;
                var b = TextButton(panel.transform, frame.ToString(), () => LoadFrame(frame), ParseColor("#111827"), Color.white, 32, 28, 10);
                Place(b.gameObject, new Vector2(150 + (i - 1) * 38, -7), new Vector2(0, 1), new Vector2(0, 1));
            }
            var preset = TextButton(panel.transform, "Шаблон режима", ApplyModePreset, ParseColor("#111827"), Color.white, 110, 28, 10);
            Place(preset.gameObject, new Vector2(360, -7), new Vector2(0, 1), new Vector2(0, 1));
        }

        private void BuildStatus(Transform parent)
        {
            var panel = Panel(parent, "Status", WithAlpha(ParseColor("#080C13"), 0.72f), 14);
            Place(panel, new Vector2(-120, 16), new Vector2(0.5f, 0), new Vector2(0.5f, 0), new Vector2(800, 36), new Vector2(0.5f, 0));
            _statusText = Text(panel.transform, "Готово: выбери футбольный режим слева, инструмент снизу, затем ЛКМ по полю", 11, FontStyle.Bold, Color.white, TextAnchor.MiddleCenter);
            Place(_statusText.gameObject, Vector2.zero, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), new Vector2(760, 24));
            _toolText = _statusText;
        }


        private void BuildPopupRoot(Transform parent)
        {
            var root = new GameObject("Sportoteka V6 Popup Root");
            root.transform.SetParent(parent, false);
            var rect = root.AddComponent<RectTransform>();
            rect.anchorMin = Vector2.zero;
            rect.anchorMax = Vector2.one;
            rect.offsetMin = Vector2.zero;
            rect.offsetMax = Vector2.zero;
            _popupRoot = root.transform;
        }

        private void ShowPlayerPicker()
        {
            if (_popupRoot == null) return;
            ClearChildren(_popupRoot);

            var shade = Panel(_popupRoot, "Затемнение", new Color(0f, 0f, 0f, 0.22f), 0);
            Place(shade, Vector2.zero, Vector2.zero, Vector2.one, Vector2.zero, new Vector2(0.5f, 0.5f), true);

            var card = Panel(_popupRoot, "Выбор состава", Color.white, 24, ParseColor(Border));
            Place(card, new Vector2(0, 0), new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), new Vector2(650, 530), new Vector2(0.5f, 0.5f));

            var title = Text(card.transform, "Выбор игрока", 20, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(title.gameObject, new Vector2(28, -22), new Vector2(0, 1), new Vector2(0, 1), new Vector2(300, 30));

            var subtitle = Text(card.transform, "Выбери игрока — затем кликни по полю, чтобы поставить его на карту.", 11, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
            Place(subtitle.gameObject, new Vector2(28, -56), new Vector2(0, 1), new Vector2(0, 1), new Vector2(560, 20));

            var close = TextButton(card.transform, "×", HidePopup, ParseColor("#FFF1F2"), ParseColor(Red), 40, 34, 14);
            Place(close.gameObject, new Vector2(-24, -22), new Vector2(1, 1), new Vector2(1, 1));

            PlayerFilterButton(card.transform, "Все", 28, -92);
            PlayerFilterButton(card.transform, "Защита", 100, -92);
            PlayerFilterButton(card.transform, "Полузащита", 196, -92, 116);
            PlayerFilterButton(card.transform, "Атака", 322, -92);
            PlayerFilterButton(card.transform, "Вратари", 406, -92, 86);

            int max = Mathf.Min(_players.Count, 12);
            for (int i = 0; i < max; i++)
            {
                float x = 28 + (i % 2) * 296;
                float y = -136 - (i / 2) * 62;
                BuildPlayerPopupCard(card.transform, _players[i], x, y);
            }
        }

        private void PlayerFilterButton(Transform parent, string title, float x, float y, float width = 66)
        {
            var button = TextButton(parent, title, () => SetStatus("Фильтр: " + title + ". Сейчас показан общий состав."), ParseColor("#F8FAFC"), ParseColor(Graphite), width, 28, 10);
            Place(button.gameObject, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1));
        }

        private void BuildPlayerPopupCard(Transform parent, Sportoteka3DProPlayerData player, float x, float y)
        {
            var bg = player == _selectedPlayer ? ParseColor("#ECFDF5") : Color.white;
            var border = player == _selectedPlayer ? ParseColor(Green) : ParseColor(Border);
            var card = Panel(parent, "Игрок " + player.number, bg, 16, border);
            Place(card, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1), new Vector2(278, 52));

            var button = card.AddComponent<Button>();
            button.targetGraphic = card.GetComponent<Image>();
            button.onClick.AddListener(() => { SelectPlayer(player); HidePopup(); });

            var avatar = Panel(card.transform, "Аватар", ParseColor("#F8FAFC"), 14, ParseColor(Border));
            Place(avatar, new Vector2(12, -9), new Vector2(0, 1), new Vector2(0, 1), new Vector2(34, 34));
            var num = Text(avatar.transform, player.number.ToString(), 11, FontStyle.Bold, ParseColor(GreenDark), TextAnchor.MiddleCenter);
            Place(num.gameObject, Vector2.zero, new Vector2(0, 0), new Vector2(1, 1), Vector2.zero, new Vector2(0.5f, 0.5f), true);

            var name = Text(card.transform, player.name, 12, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(name.gameObject, new Vector2(58, -8), new Vector2(0, 1), new Vector2(0, 1), new Vector2(180, 18));

            var role = Text(card.transform, "№" + player.number + " • " + player.position, 9, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
            Place(role.gameObject, new Vector2(58, -29), new Vector2(0, 1), new Vector2(0, 1), new Vector2(190, 16));

            var mark = Text(card.transform, player == _selectedPlayer ? "✓" : "+", 16, FontStyle.Bold, player == _selectedPlayer ? ParseColor(Green) : ParseColor(Muted), TextAnchor.MiddleCenter);
            Place(mark.gameObject, new Vector2(-24, -15), new Vector2(1, 1), new Vector2(1, 1), new Vector2(24, 24));
        }

        private void HidePopup()
        {
            if (_popupRoot == null) return;
            ClearChildren(_popupRoot);
        }

        private void HandleShortcuts()
        {
            if (KeyDown("escape")) { if (_popupRoot != null && _popupRoot.childCount > 0) HidePopup(); else RequestClose(); }
            if (KeyDown("delete") || KeyDown("backspace")) DeleteSelected();
            if (KeyDown("plus")) ScaleSelected(1.12f);
            if (KeyDown("minus")) ScaleSelected(0.90f);
            if (KeyDown("leftBracket")) RotateSelected(-10);
            if (KeyDown("rightBracket")) RotateSelected(10);
            if (KeyDown("c")) ClearPlan();
            if (KeyDown("s")) SavePlan();
            if (KeyDown("z")) UndoLastAction();
            if (KeyDown("y")) RedoLastAction();
        }


        // ------------------------------------------------------------------
        // PREMIUM UI V9: exact clean football-board layout from the approved mockup.
        // Field/stadium stay untouched. Only the Unity overlay, tools and minimap are rebuilt.
        // ------------------------------------------------------------------

        private void BuildPremiumTopBar(Transform parent)
        {
            // FIFA/TacticalPad style: light floating command strip, no heavy framed header.
            var bar = PremiumCard(parent, "FIFA Floating Top Command", WithAlpha(Color.white, 0.88f), 22, null, new Vector2(0, -3));
            PlaceStretch(bar, new Vector2(_compactLayout ? 76 : 116, -82), new Vector2(_compactLayout ? -12 : -24, -18), new Vector2(0, 1), new Vector2(1, 1));

            var brand = CirclePanel(bar.transform, "Brand Orb", ParseColor(Green), null, true);
            Place(brand, new Vector2(16, -12), new Vector2(0, 1), new Vector2(0, 1), new Vector2(42, 42));
            AddIcon(brand.transform, "tg_sport", Color.white, new Vector2(10, -10), new Vector2(22, 22));

            var title = Text(bar.transform, _compactLayout ? "Sportoteka 3D Pro" : "Sportoteka 3D Pro • Tactical Board", _compactLayout ? 15 : 18, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(title.gameObject, new Vector2(68, -10), new Vector2(0, 1), new Vector2(0, 1), new Vector2(_compactLayout ? 245 : 440, 22));

            var sub = Text(bar.transform, ModeTitle(_mode) + " • " + ToolTitle(_tool) + " • " + _teamName, _compactLayout ? 10 : 12, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
            Place(sub.gameObject, new Vector2(68, -35), new Vector2(0, 1), new Vector2(0, 1), new Vector2(_compactLayout ? 260 : 620, 18));
            _modeText = sub;

            float right = -16f;
            FloatingTopAction(bar.transform, "✕", "tg_close", RequestClose, ParseColor("#FFF1F2"), ParseColor("#EF4444"), ref right);
            FloatingTopAction(bar.transform, "✓", "tg_save", SavePlan, ParseColor(Graphite), Color.white, ref right);
            FloatingTopAction(bar.transform, _cameraPreset == "tactical" ? "2D" : "3D", "tg_camera", () => SetCameraPreset(_cameraPreset == "tactical" ? "top" : "tactical"), ParseColor("#EAF8F1"), ParseColor(GreenDark), ref right);
            if (!_compactLayout)
            {
                FloatingTopAction(bar.transform, "⚡", "tg_magic", ApplyModePreset, ParseColor("#EAF8F1"), ParseColor(GreenDark), ref right);
                FloatingTopAction(bar.transform, "PNG", "tg_download", ExportPng, Color.white, ParseColor(GreenDark), ref right);
                FloatingTopAction(bar.transform, "↶", "tg_rotate_left", UndoLastAction, Color.white, ParseColor(Graphite), ref right);
                FloatingTopAction(bar.transform, "↷", "tg_rotate_right", RedoLastAction, Color.white, ParseColor(Graphite), ref right);
                FloatingTopAction(bar.transform, "🧹", "tg_clear", ClearPlan, Color.white, ParseColor("#EF4444"), ref right);
            }
        }


        private void FloatingTopAction(Transform parent, string label, string iconKey, UnityEngine.Events.UnityAction action, Color bg, Color fg, ref float right)
        {
            var orb = CirclePanel(parent, "Top Action " + label, bg, null, true);
            Place(orb, new Vector2(right - 48, -10), new Vector2(1, 1), new Vector2(1, 1), new Vector2(44, 44), new Vector2(1, 1));
            var btn = orb.AddComponent<Button>();
            btn.targetGraphic = orb.GetComponent<Image>();
            btn.onClick.AddListener(action);

            if (!string.IsNullOrEmpty(iconKey) && label.Length <= 1)
            {
                AddIcon(orb.transform, iconKey, fg, new Vector2(11, -11), new Vector2(22, 22));
            }
            else
            {
                var t = Text(orb.transform, label, label.Length > 2 ? 10 : 12, FontStyle.Bold, fg, TextAnchor.MiddleCenter);
                Place(t.gameObject, Vector2.zero, new Vector2(0, 0), new Vector2(1, 1), Vector2.zero, new Vector2(0.5f, 0.5f), true);
            }
            right -= 54f;
        }

        private void BuildPremiumLeftToolbar(Transform parent)
        {
            // No rear side menu: only floating circular mode buttons.
            var rail = new GameObject("FIFA Floating Mode Orbs");
            rail.transform.SetParent(parent, false);
            rail.AddComponent<RectTransform>();
            PlaceStretch(rail, new Vector2(14, 92), new Vector2(94, -120), new Vector2(0, 0), new Vector2(0, 1));
            _compactRailRoot = rail.transform;
            RefreshPremiumLeftToolbar();
        }

        private void RefreshPremiumLeftToolbar()
        {
            if (_compactRailRoot == null) return;
            ClearChildren(_compactRailRoot);

            var logo = CirclePanel(_compactRailRoot, "Logo Floating Orb", WithAlpha(Color.white, 0.94f), null, true);
            Place(logo, new Vector2(12, -8), new Vector2(0, 1), new Vector2(0, 1), new Vector2(62, 62));
            AddIcon(logo.transform, "tg_sport", ParseColor(GreenDark), new Vector2(15, -15), new Vector2(32, 32));

            float y = 86f;
            PremiumRailButton(_compactRailRoot, "Доска", "tg_grid", () => SetMode(Sportoteka3DProMode.Tactics), _mode == Sportoteka3DProMode.Tactics, y); y += 68;
            PremiumRailButton(_compactRailRoot, "Анализ", "tg_analysis", () => SetMode(Sportoteka3DProMode.Analysis), _mode == Sportoteka3DProMode.Analysis, y); y += 68;
            PremiumRailButton(_compactRailRoot, "Упр.", "tg_drill", () => SetMode(Sportoteka3DProMode.Drill), _mode == Sportoteka3DProMode.Drill, y); y += 68;
            PremiumRailButton(_compactRailRoot, "Анимация", "tg_play", () => SetMode(Sportoteka3DProMode.Animation), _mode == Sportoteka3DProMode.Animation, y); y += 68;
            PremiumRailButton(_compactRailRoot, "Калибр.", "tg_calibration", () => SetMode(Sportoteka3DProMode.Calibration), _mode == Sportoteka3DProMode.Calibration, y); y += 68;
            PremiumRailButton(_compactRailRoot, "Брифинг", "tg_folder", () => SetMode(Sportoteka3DProMode.Branding), _mode == Sportoteka3DProMode.Branding, y);

            if (!_compactLayout)
            {
                var eye = CirclePanel(_compactRailRoot, "Toggle Drawings Orb", WithAlpha(Color.white, 0.92f), null, true);
                Place(eye, new Vector2(19, -548), new Vector2(0, 1), new Vector2(0, 1), new Vector2(48, 48));
                var eyeBtn = eye.AddComponent<Button>();
                eyeBtn.targetGraphic = eye.GetComponent<Image>();
                eyeBtn.onClick.AddListener(ToggleDrawingsVisible);
                var eyeText = Text(eye.transform, _drawingsVisible ? "◉" : "◎", 18, FontStyle.Bold, ParseColor(GreenDark), TextAnchor.MiddleCenter);
                Place(eyeText.gameObject, Vector2.zero, new Vector2(0, 0), new Vector2(1, 1), Vector2.zero, new Vector2(0.5f, 0.5f), true);

                var lockOrb = CirclePanel(_compactRailRoot, "Camera Lock Orb", WithAlpha(Color.white, 0.92f), null, true);
                Place(lockOrb, new Vector2(19, -604), new Vector2(0, 1), new Vector2(0, 1), new Vector2(48, 48));
                var lockBtn = lockOrb.AddComponent<Button>();
                lockBtn.targetGraphic = lockOrb.GetComponent<Image>();
                lockBtn.onClick.AddListener(ToggleCameraLock);
                var lockText = Text(lockOrb.transform, _cameraLocked ? "🔒" : "⌖", 15, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleCenter);
                Place(lockText.gameObject, Vector2.zero, new Vector2(0, 0), new Vector2(1, 1), Vector2.zero, new Vector2(0.5f, 0.5f), true);
            }
        }

        private void PremiumRailButton(Transform parent, string label, string iconKey, UnityEngine.Events.UnityAction action, bool active, float y)
        {
            Color bg = active ? ParseColor(Green) : WithAlpha(Color.white, 0.94f);
            Color fg = active ? Color.white : ParseColor(Graphite);
            var item = CirclePanel(parent, "Mode Orb " + label, bg, null, true);
            Place(item, new Vector2(14, -y), new Vector2(0, 1), new Vector2(0, 1), new Vector2(active ? 64 : 56, active ? 64 : 56));
            var btn = item.AddComponent<Button>();
            btn.targetGraphic = item.GetComponent<Image>();
            btn.onClick.AddListener(action);
            AddIcon(item.transform, iconKey, fg, new Vector2(active ? 17 : 15, active ? -15 : -14), new Vector2(active ? 30 : 26, active ? 30 : 26));

            if (active && !_compactLayout)
            {
                var tag = PremiumCard(parent, "Mode Active Label " + label, WithAlpha(ParseColor(Graphite), 0.84f), 16, null, new Vector2(0, -1));
                Place(tag, new Vector2(84, -y - 2), new Vector2(0, 1), new Vector2(0, 1), new Vector2(104, 30));
                var t = Text(tag.transform, label, 11, FontStyle.Bold, Color.white, TextAnchor.MiddleCenter);
                Place(t.gameObject, Vector2.zero, new Vector2(0, 0), new Vector2(1, 1), Vector2.zero, new Vector2(0.5f, 0.5f), true);
            }
        }

        private void BuildPremiumBottomDock(Transform parent)
        {
            if (_compactLayout) return;
            // Strict TacticalPad-like toolbar: one clean white tray, round icons, labels and predictable hit areas.
            var dock = PremiumCard(parent, "TacticalPad Bottom Toolbar", WithAlpha(Color.white, 0.97f), 24, ParseColor("#E2E8F0"), new Vector2(0, -4));
            Place(dock, new Vector2(0, 16), new Vector2(0.5f, 0), new Vector2(0.5f, 0), new Vector2(1180, 94), new Vector2(0.5f, 0));
            _compactDockRoot = dock.transform;
            RefreshPremiumBottomDock();
        }

        private void RefreshPremiumBottomDock()
        {
            if (_compactDockRoot == null) return;
            ClearChildren(_compactDockRoot);

            if (_compactLayout)
            {
                float cx = 10f;
                PremiumDockTool(_compactDockRoot, "Выбор", "tg_select", () => SetTool(Sportoteka3DProTool.Select), _tool == Sportoteka3DProTool.Select, cx); cx += 58;
                PremiumDockTool(_compactDockRoot, "Игрок", "tg_player", () => SetTool(Sportoteka3DProTool.Player), _tool == Sportoteka3DProTool.Player, cx); cx += 58;
                PremiumDockTool(_compactDockRoot, "Мяч", "tg_ball", () => SetTool(Sportoteka3DProTool.Ball), _tool == Sportoteka3DProTool.Ball, cx); cx += 58;
                PremiumDockTool(_compactDockRoot, "Пас", "tg_pass", () => SetTool(Sportoteka3DProTool.PassArrow), _tool == Sportoteka3DProTool.PassArrow, cx); cx += 58;
                PremiumDockTool(_compactDockRoot, "Рывок", "tg_run", () => SetTool(Sportoteka3DProTool.RunArrow), _tool == Sportoteka3DProTool.RunArrow, cx); cx += 58;
                PremiumDockTool(_compactDockRoot, "Зона", "tg_zone", () => SetTool(Sportoteka3DProTool.HatchedZone), _tool == Sportoteka3DProTool.HatchedZone || _tool == Sportoteka3DProTool.Zone, cx); cx += 58;
                PremiumDockTool(_compactDockRoot, "Ещё", "tg_layers", ShowPlayerPicker, false, cx);
                return;
            }

            float x = 12f;
            float step = 74f;
            PremiumDockTool(_compactDockRoot, "Выбор", "tg_select", () => SetTool(Sportoteka3DProTool.Select), _tool == Sportoteka3DProTool.Select, x); x += step;
            PremiumDockTool(_compactDockRoot, "Игрок", "tg_player", () => SetTool(Sportoteka3DProTool.Player), _tool == Sportoteka3DProTool.Player, x); x += step;
            PremiumDockTool(_compactDockRoot, "Соперник", "tg_opponent", () => SetTool(Sportoteka3DProTool.Opponent), _tool == Sportoteka3DProTool.Opponent, x); x += step;
            PremiumDockTool(_compactDockRoot, "Мяч", "tg_ball", () => SetTool(Sportoteka3DProTool.Ball), _tool == Sportoteka3DProTool.Ball, x); x += step;
            PremiumDockTool(_compactDockRoot, "Пас", "tg_pass", () => SetTool(Sportoteka3DProTool.PassArrow), _tool == Sportoteka3DProTool.PassArrow, x); x += step;
            PremiumDockTool(_compactDockRoot, "Рывок", "tg_run", () => SetTool(Sportoteka3DProTool.RunArrow), _tool == Sportoteka3DProTool.RunArrow, x); x += step;
            PremiumDockTool(_compactDockRoot, "Кривая", "tg_curve", () => SetTool(Sportoteka3DProTool.CurveArrow), _tool == Sportoteka3DProTool.CurveArrow, x); x += step;
            PremiumDockTool(_compactDockRoot, "Зона", "tg_zone", () => SetTool(Sportoteka3DProTool.HatchedZone), _tool == Sportoteka3DProTool.HatchedZone || _tool == Sportoteka3DProTool.Zone, x); x += step;
            PremiumDockTool(_compactDockRoot, "Конус", "tg_cone", () => SetTool(Sportoteka3DProTool.Cone), _tool == Sportoteka3DProTool.Cone, x); x += step;
            PremiumDockTool(_compactDockRoot, "Манекен", "tg_mannequin", () => SetTool(Sportoteka3DProTool.Mannequin), _tool == Sportoteka3DProTool.Mannequin, x); x += step;
            PremiumDockTool(_compactDockRoot, "Ворота", "tg_goal", () => SetTool(Sportoteka3DProTool.MiniGoal), _tool == Sportoteka3DProTool.MiniGoal, x); x += step;
            PremiumDockTool(_compactDockRoot, "Текст", "tg_text", () => SetTool(Sportoteka3DProTool.Text), _tool == Sportoteka3DProTool.Text, x); x += step;
            PremiumDockTool(_compactDockRoot, "Линейка", "tg_measure", () => SetTool(Sportoteka3DProTool.Measurement), _tool == Sportoteka3DProTool.Measurement, x); x += step;
            PremiumDockTool(_compactDockRoot, "Слои", "tg_layers", () => { SetRightPanelTab("layers"); SetStatus("Открыт профессиональный менеджер слоёв."); }, _rightPanelTab == "layers", x); x += step;
            PremiumDockTool(_compactDockRoot, "Удалить", "tg_clear", DeleteSelected, false, x);
        }

        private void PremiumDockTool(Transform parent, string label, string iconKey, UnityEngine.Events.UnityAction action, bool active, float x)
        {
            float size = _compactLayout ? (active ? 48f : 44f) : (active ? 58f : 52f);
            float icon = _compactLayout ? (active ? 24f : 22f) : (active ? 30f : 27f);
            Color bg = active ? ParseColor(Green) : WithAlpha(Color.white, 0.96f);
            Color fg = active ? Color.white : ParseColor(Graphite);
            var item = CirclePanel(parent, "Tool Orb " + label, bg, null, true);
            Place(item, new Vector2(x + (active ? -2 : 0), active ? -8 : -10), new Vector2(0, 1), new Vector2(0, 1), new Vector2(size, size));
            var btn = item.AddComponent<Button>();
            btn.targetGraphic = item.GetComponent<Image>();
            btn.onClick.AddListener(action);
            AddIcon(item.transform, iconKey, fg, new Vector2((size - icon) * 0.5f, -(size - icon) * 0.5f), new Vector2(icon, icon));

            var caption = Text(parent, label, _compactLayout ? 7 : 8, FontStyle.Bold, active ? ParseColor(GreenDark) : ParseColor(Muted), TextAnchor.MiddleCenter);
            Place(caption.gameObject, new Vector2(x - 9, _compactLayout ? -60 : -68), new Vector2(0, 1), new Vector2(0, 1), new Vector2(_compactLayout ? 62 : 72, 16));
        }

        private void BuildPremiumMobileDock(Transform parent)
        {
            var dock = PremiumCard(parent, "TacticalPad Mobile Toolbar", WithAlpha(Color.white, 0.97f), 22, ParseColor("#E2E8F0"), new Vector2(0, -3));
            PlaceStretch(dock, new Vector2(84, 12), new Vector2(-14, 82), new Vector2(0, 0), new Vector2(1, 0));
            _compactDockRoot = dock.transform;
            RefreshPremiumBottomDock();
        }

        private void SelectGoalkeeper()
        {
            for (int i = 0; i < _players.Count; i++)
            {
                if (_players[i].position == "ВР" || _players[i].number == 1)
                {
                    SelectPlayer(_players[i]);
                    return;
                }
            }
            if (_players.Count > 0) SelectPlayer(_players[0]);
        }

        private void BuildPremiumInspector(Transform parent)
        {
            // V16: one professional right panel instead of stacked technical cards.
            // The panel works like a real tactical editor: contextual object inspector,
            // layer manager, style tab and animation tab in one place.
            var panel = PremiumCard(parent, "Sportoteka V16 Pro Right Inspector", WithAlpha(Color.white, 0.965f), 24, null, new Vector2(0, -5));
            Place(panel, new Vector2(-24, -128), new Vector2(1, 1), new Vector2(1, 1), new Vector2(360, 520), new Vector2(1, 1));
            _compactInspectorRoot = panel.transform;
            _layersRoot = panel.transform;
            RefreshPremiumInspector();
        }

        private void SetRightPanelTab(string tab)
        {
            _rightPanelTab = string.IsNullOrEmpty(tab) ? "properties" : tab;
            RefreshPremiumInspector();
        }

        private void RefreshPremiumInspector()
        {
            if (_compactInspectorRoot == null) return;
            ClearChildren(_compactInspectorRoot);

            var item = FindItem(_selectedItemId);
            string title = item == null ? ToolTitle(_tool) : ObjectDisplayName(item);
            string subtitle = item == null ? "Инструмент выбран — кликни по полю" : ObjectSubtitle(item);

            var header = PremiumCard(_compactInspectorRoot, "V16 Inspector Header", ParseColor("#F8FAFC"), 20, ParseColor("#E2E8F0"), Vector2.zero);
            Place(header, new Vector2(16, -14), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-32, 72), new Vector2(0.5f, 1));

            var iconBg = CirclePanel(header.transform, "Object Icon Circle", item == null ? ParseColor("#EEF2F7") : WithAlpha(HtmlOrDefault(item.color, ParseColor(Green)), 0.16f), ParseColor("#E2E8F0"), false);
            Place(iconBg, new Vector2(14, -14), new Vector2(0, 1), new Vector2(0, 1), new Vector2(44, 44));
            AddIcon(iconBg.transform, item == null ? ToolToIconKey(_tool) : TypeToIconKey(item.type), item == null ? ParseColor(Graphite) : HtmlOrDefault(item.color, ParseColor(GreenDark)), new Vector2(10, -10), new Vector2(24, 24));

            _selectedText = Text(header.transform, title, 15, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(_selectedText.gameObject, new Vector2(68, -12), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-112, 24), new Vector2(0.5f, 1));
            var sub = Text(header.transform, subtitle, 10, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
            Place(sub.gameObject, new Vector2(68, -38), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-112, 18), new Vector2(0.5f, 1));

            var close = PremiumTextButton(header.transform, "×", () => SelectItem(""), Color.white, ParseColor(Graphite), ParseColor("#E2E8F0"), 30, 30, 15);
            Place(close.gameObject, new Vector2(-16, -20), new Vector2(1, 1), new Vector2(1, 1), new Vector2(30, 30), new Vector2(1, 1));

            RightPanelTabButton("properties", "Свойства", 16, -96, 82);
            RightPanelTabButton("layers", "Слои", 106, -96, 60);
            RightPanelTabButton("style", "Стиль", 174, -96, 64);
            RightPanelTabButton("animation", "Анимация", 246, -96, 98);

            if (_rightPanelTab == "layers") RenderRightPanelLayers(_compactInspectorRoot);
            else if (_rightPanelTab == "style") RenderRightPanelStyle(_compactInspectorRoot, item);
            else if (_rightPanelTab == "animation") RenderRightPanelAnimation(_compactInspectorRoot, item);
            else RenderRightPanelProperties(_compactInspectorRoot, item);
        }

        private void RightPanelTabButton(string key, string title, float x, float y, float w)
        {
            bool active = _rightPanelTab == key;
            var btn = PremiumTextButton(_compactInspectorRoot, title, () => SetRightPanelTab(key), active ? ParseColor("#ECFDF5") : Color.white, active ? ParseColor(GreenDark) : ParseColor(Graphite), active ? ParseColor("#BFEBD5") : ParseColor("#E2E8F0"), w, 32, 10);
            Place(btn.gameObject, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1));
        }

        private void RenderRightPanelProperties(Transform root, Sportoteka3DProPlanItem item)
        {
            var body = PremiumCard(root, "V16 Properties Body", WithAlpha(ParseColor("#FFFFFF"), 0.99f), 18, ParseColor("#E2E8F0"), Vector2.zero);
            Place(body, new Vector2(16, -138), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-32, 270), new Vector2(0.5f, 1));

            if (item == null)
            {
                AddSectionTitle(body.transform, "Быстрый старт", 16, -12);
                AddInfoRow(body.transform, "Активный инструмент", ToolTitle(_tool), 16, -44);
                AddInfoRow(body.transform, "Режим", ModeTitle(_mode), 16, -74);
                AddInfoRow(body.transform, "Команда", _teamName, 16, -104);
                AddHintBox(body.transform, "Выбери объект на поле или открой вкладку «Слои». Для построения схемы добавь игроков, мяч, передачи и зоны.", 16, -142, 300, 72);
                var preset = PremiumTextButton(body.transform, "Открыть PRO-библиотеку", ShowProLibrary, ParseColor("#0F172A"), Color.white, null, 190, 34, 10);
                Place(preset.gameObject, new Vector2(16, -224), new Vector2(0, 1), new Vector2(0, 1));
                return;
            }

            AddSectionTitle(body.transform, "Контекст объекта", 16, -12);
            AddInfoRow(body.transform, "Тип", TypeTitle(item.type), 16, -44);
            AddInfoRow(body.transform, "Позиция", item.x.ToString("0.0") + " / " + item.z.ToString("0.0") + " м", 16, -74);

            if (item.type == "player" || item.type == "opponent")
            {
                AddInfoRow(body.transform, "Игрок", (item.number > 0 ? "№" + item.number + " · " : "") + (string.IsNullOrEmpty(item.name) ? item.position : item.name), 16, -104);
                AddInfoRow(body.transform, "Амплуа", string.IsNullOrEmpty(item.position) ? "не задано" : item.position, 16, -134);
                AddHintBox(body.transform, "Игрока можно масштабировать, повернуть, поднять поверх и включить в анимационные кадры.", 16, -170, 300, 48);
            }
            else if (IsLineLike(item.type))
            {
                AddInfoRow(body.transform, "Длина", DistanceText(item), 16, -104);
                AddInfoRow(body.transform, "Стиль", TypeTitle(item.type), 16, -134);
                AddHintBox(body.transform, "Для пасов и рывков доступны сплошная линия, пунктир и стрелка. Толщина меняется во вкладке «Стиль».", 16, -170, 300, 52);
            }
            else if (IsZoneLike(item.type))
            {
                AddInfoRow(body.transform, "Размер", Mathf.Abs(item.toX - item.x).ToString("0") + " × " + Mathf.Abs(item.toZ - item.z).ToString("0") + " м", 16, -104);
                AddInfoRow(body.transform, "Прозрачность", Mathf.RoundToInt(item.alpha * 100f) + "%", 16, -134);
                AddHintBox(body.transform, "Зона используется для компактности, прессинга, пространства между линиями и тренировочных квадратов.", 16, -170, 300, 52);
            }
            else
            {
                AddInfoRow(body.transform, "Масштаб", item.scale.ToString("0.00"), 16, -104);
                AddInfoRow(body.transform, "Поворот", item.rotation.ToString("0") + "°", 16, -134);
                AddHintBox(body.transform, "Это инвентарь/точечный объект. Используй масштаб, поворот и порядок слоя.", 16, -170, 300, 52);
            }

            InspectorActionRow(root, -424, item);
        }

        private void RenderRightPanelStyle(Transform root, Sportoteka3DProPlanItem item)
        {
            var body = PremiumCard(root, "V16 Style Body", WithAlpha(ParseColor("#FFFFFF"), 0.99f), 18, ParseColor("#E2E8F0"), Vector2.zero);
            Place(body, new Vector2(16, -138), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-32, 270), new Vector2(0.5f, 1));

            AddSectionTitle(body.transform, "Цвет и стиль", 16, -12);
            string[] colors = { Green, "#FCD34D", "#38BDF8", "#F97316", "#F43F5E", "#FFFFFF", "#111827" };
            for (int i = 0; i < colors.Length; i++)
                PremiumColorDot(body.transform, colors[i], 16 + i * 40, -46, ColorToHex(_activeColor).ToUpperInvariant() == colors[i].ToUpperInvariant());

            var label = Text(body.transform, IsLineLike(item == null ? "pass" : item.type) ? "Толщина линии" : "Размер / толщина", 11, FontStyle.Bold, ParseColor("#475467"), TextAnchor.MiddleLeft);
            Place(label.gameObject, new Vector2(16, -88), new Vector2(0, 1), new Vector2(0, 1), new Vector2(160, 18));
            var value = Text(body.transform, LineWidthPx(_activeWidth) + " px", 11, FontStyle.Bold, ParseColor("#667085"), TextAnchor.MiddleRight);
            Place(value.gameObject, new Vector2(-18, -88), new Vector2(1, 1), new Vector2(1, 1), new Vector2(54, 18), new Vector2(1, 1));
            _widthSlider = PremiumSlider(body.transform, "V16 Width Slider", 0.025f, 0.16f, _activeWidth, SetLineWidth);
            Place(_widthSlider.gameObject, new Vector2(16, -112), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-32, 22), new Vector2(0.5f, 1));

            var alphaText = Text(body.transform, "Прозрачность", 11, FontStyle.Bold, ParseColor("#475467"), TextAnchor.MiddleLeft);
            Place(alphaText.gameObject, new Vector2(16, -148), new Vector2(0, 1), new Vector2(0, 1), new Vector2(160, 18));
            _alphaSlider = PremiumSlider(body.transform, "V16 Alpha Slider", 0.10f, 1.0f, _activeAlpha, SetAlpha);
            Place(_alphaSlider.gameObject, new Vector2(16, -172), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-32, 22), new Vector2(0.5f, 1));

            if (item == null || IsLineLike(item.type))
            {
                var preview = PremiumCard(body.transform, "V16 Line Preview", Color.white, 14, ParseColor("#E2E8F0"), Vector2.zero);
                Place(preview, new Vector2(16, -208), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-32, 38), new Vector2(0.5f, 1));
                DrawInspectorStylePreview(preview.transform, item == null ? "pass" : item.type);
                var solid = PremiumTextButton(body.transform, "Линия", () => SetLineStyle("solid"), Color.white, ParseColor(Graphite), ParseColor("#E2E8F0"), 82, 30, 10);
                Place(solid.gameObject, new Vector2(16, -252), new Vector2(0, 1), new Vector2(0, 1));
                var dashed = PremiumTextButton(body.transform, "Пунктир", () => SetLineStyle("dashed"), Color.white, ParseColor(Graphite), ParseColor("#E2E8F0"), 90, 30, 10);
                Place(dashed.gameObject, new Vector2(106, -252), new Vector2(0, 1), new Vector2(0, 1));
                var arrow = PremiumTextButton(body.transform, "Стрелка", () => SetLineStyle("arrow"), ParseColor("#ECFDF5"), ParseColor(GreenDark), ParseColor("#BFEBD5"), 92, 30, 10);
                Place(arrow.gameObject, new Vector2(204, -252), new Vector2(0, 1), new Vector2(0, 1));
            }

            InspectorActionRow(root, -424, item);
        }

        private void RenderRightPanelAnimation(Transform root, Sportoteka3DProPlanItem item)
        {
            var body = PremiumCard(root, "V16 Animation Body", WithAlpha(ParseColor("#FFFFFF"), 0.99f), 18, ParseColor("#E2E8F0"), Vector2.zero);
            Place(body, new Vector2(16, -138), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-32, 270), new Vector2(0.5f, 1));
            AddSectionTitle(body.transform, "Анимация и брифинг", 16, -12);
            AddInfoRow(body.transform, "Кадров", _frames.Count.ToString(), 16, -44);
            AddInfoRow(body.transform, "Выбран", item == null ? "нет объекта" : TypeTitle(item.type), 16, -74);
            AddHintBox(body.transform, "Сохраняй ключевые кадры: игроки, мяч, линии и зоны будут воспроизведены как тактическая последовательность.", 16, -108, 300, 58);
            var add = PremiumTextButton(body.transform, "+ Сохранить кадр", SaveFrame, ParseColor("#0F172A"), Color.white, null, 138, 34, 10);
            Place(add.gameObject, new Vector2(16, -178), new Vector2(0, 1), new Vector2(0, 1));
            var play = PremiumTextButton(body.transform, "▶ Проиграть", PlayFrames, ParseColor("#ECFDF5"), ParseColor(GreenDark), ParseColor("#BFEBD5"), 120, 34, 10);
            Place(play.gameObject, new Vector2(164, -178), new Vector2(0, 1), new Vector2(0, 1));
            var example = PremiumTextButton(body.transform, "Пример атаки", AddAnimationExample, Color.white, ParseColor(Graphite), ParseColor("#E2E8F0"), 128, 32, 10);
            Place(example.gameObject, new Vector2(16, -224), new Vector2(0, 1), new Vector2(0, 1));
            var clear = PremiumTextButton(body.transform, "Очистить кадры", ClearFrames, Color.white, ParseColor("#EF4444"), ParseColor("#FECACA"), 132, 32, 10);
            Place(clear.gameObject, new Vector2(154, -224), new Vector2(0, 1), new Vector2(0, 1));
        }

        private void RenderRightPanelLayers(Transform root)
        {
            var body = PremiumCard(root, "V16 Layers Body", WithAlpha(ParseColor("#FFFFFF"), 0.99f), 18, ParseColor("#E2E8F0"), Vector2.zero);
            Place(body, new Vector2(16, -138), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-32, 334), new Vector2(0.5f, 1));
            AddSectionTitle(body.transform, "Объекты на поле", 16, -12);
            var count = Text(body.transform, _items.Count + " объектов", 11, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleRight);
            Place(count.gameObject, new Vector2(-16, -14), new Vector2(1, 1), new Vector2(1, 1), new Vector2(92, 18), new Vector2(1, 1));

            if (_items.Count == 0)
            {
                AddHintBox(body.transform, "Поле чистое. Добавь объект снизу или нажми «PRO-библиотека», чтобы загрузить готовую сцену.", 16, -54, 300, 70);
                var lib = PremiumTextButton(body.transform, "PRO-библиотека", ShowProLibrary, ParseColor("#0F172A"), Color.white, null, 144, 34, 10);
                Place(lib.gameObject, new Vector2(16, -140), new Vector2(0, 1), new Vector2(0, 1));
            }
            else
            {
                int visible = Mathf.Min(8, _items.Count);
                for (int rowIndex = 0; rowIndex < visible; rowIndex++)
                {
                    int itemIndex = _items.Count - 1 - rowIndex;
                    AddLayerRow(body.transform, _items[itemIndex], itemIndex + 1, rowIndex);
                }
                if (_items.Count > visible)
                {
                    var more = Text(body.transform, "+ ещё " + (_items.Count - visible) + " объектов ниже", 10, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
                    Place(more.gameObject, new Vector2(16, -292), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-32, 18), new Vector2(0.5f, 1));
                }
            }

            var select = PremiumTextButton(root, "Выбор", () => SetTool(Sportoteka3DProTool.Select), ParseColor("#ECFDF5"), ParseColor(GreenDark), ParseColor("#BFEBD5"), 78, 34, 10);
            Place(select.gameObject, new Vector2(16, -486), new Vector2(0, 1), new Vector2(0, 1));
            var top = PremiumTextButton(root, "Поверх", BringSelectedToFront, Color.white, ParseColor(Graphite), ParseColor("#E2E8F0"), 82, 34, 10);
            Place(top.gameObject, new Vector2(104, -486), new Vector2(0, 1), new Vector2(0, 1));
            var back = PremiumTextButton(root, "Назад", SendSelectedToBack, Color.white, ParseColor(Graphite), ParseColor("#E2E8F0"), 72, 34, 10);
            Place(back.gameObject, new Vector2(196, -486), new Vector2(0, 1), new Vector2(0, 1));
            var clear = PremiumTextButton(root, "Очистить", ClearPlan, Color.white, ParseColor("#EF4444"), ParseColor("#FECACA"), 84, 34, 10);
            Place(clear.gameObject, new Vector2(276, -486), new Vector2(0, 1), new Vector2(0, 1));
        }

        private void InspectorActionRow(Transform root, float y, Sportoteka3DProPlanItem item)
        {
            var del = PremiumTextButton(root, "Удалить", DeleteSelected, Color.white, ParseColor("#EF4444"), ParseColor("#FECACA"), 86, 34, 10);
            Place(del.gameObject, new Vector2(16, y), new Vector2(0, 1), new Vector2(0, 1));
            var copy = PremiumTextButton(root, "Копия", DuplicateSelected, Color.white, ParseColor(Graphite), ParseColor("#E2E8F0"), 74, 34, 10);
            Place(copy.gameObject, new Vector2(110, y), new Vector2(0, 1), new Vector2(0, 1));
            var plus = PremiumTextButton(root, "+", () => ScaleSelected(1.12f), Color.white, ParseColor(Graphite), ParseColor("#E2E8F0"), 36, 34, 13);
            Place(plus.gameObject, new Vector2(192, y), new Vector2(0, 1), new Vector2(0, 1));
            var minus = PremiumTextButton(root, "−", () => ScaleSelected(0.90f), Color.white, ParseColor(Graphite), ParseColor("#E2E8F0"), 36, 34, 13);
            Place(minus.gameObject, new Vector2(236, y), new Vector2(0, 1), new Vector2(0, 1));
            var rotate = PremiumTextButton(root, "Поворот", () => RotateSelected(15f), Color.white, ParseColor(Graphite), ParseColor("#E2E8F0"), 78, 34, 10);
            Place(rotate.gameObject, new Vector2(280, y), new Vector2(0, 1), new Vector2(0, 1));
        }

        private void BuildPremiumLayersPanel(Transform parent)
        {
            // V16: layers are now a tab inside the single right inspector.
            _layersRoot = _compactInspectorRoot;
        }

        private void RefreshPremiumLayersPanel()
        {
            if (_rightPanelTab == "layers") RefreshPremiumInspector();
        }

        private void AddLayerRow(Transform parent, Sportoteka3DProPlanItem item, int number, int rowIndex)
        {
            bool active = item != null && item.id == _selectedItemId;
            Color bg = active ? ParseColor("#ECFDF5") : WithAlpha(ParseColor("#F8FAFC"), 0.96f);
            Color border = active ? ParseColor("#BFEBD5") : ParseColor("#E2E8F0");
            var row = PremiumCard(parent, "Layer Row " + item.id, bg, 15, border, Vector2.zero);
            Place(row, new Vector2(16, -50 - rowIndex * 30), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-32, 26), new Vector2(0.5f, 1));

            var btn = row.AddComponent<Button>();
            btn.targetGraphic = row.GetComponent<Image>();
            string id = item.id;
            btn.onClick.AddListener(() => { SetTool(Sportoteka3DProTool.Select); SelectItem(id); SetStatus("Выбран слой: " + LayerItemTitle(item, number)); });

            AddIcon(row.transform, TypeToIconKey(item.type), active ? ParseColor(GreenDark) : ParseColor(Graphite), new Vector2(9, -5), new Vector2(16, 16));
            var name = Text(row.transform, LayerItemTitle(item, number), 9, FontStyle.Bold, active ? ParseColor(GreenDark) : ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(name.gameObject, new Vector2(31, -4), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-128, 18), new Vector2(0.5f, 1));

            var eye = PremiumTextButton(row.transform, item.visible ? "◉" : "◎", () => ToggleItemVisible(id), Color.clear, item.visible ? ParseColor(GreenDark) : ParseColor("#94A3B8"), null, 22, 22, 10);
            Place(eye.gameObject, new Vector2(-88, -2), new Vector2(1, 1), new Vector2(1, 1), new Vector2(22, 22), new Vector2(1, 1));
            var lockButton = PremiumTextButton(row.transform, item.locked ? "■" : "□", () => ToggleItemLocked(id), Color.clear, item.locked ? ParseColor("#EF4444") : ParseColor(Muted), null, 22, 22, 10);
            Place(lockButton.gameObject, new Vector2(-64, -2), new Vector2(1, 1), new Vector2(1, 1), new Vector2(22, 22), new Vector2(1, 1));
            var duplicate = PremiumTextButton(row.transform, "▣", () => { SelectItem(id); DuplicateSelected(); }, Color.clear, ParseColor(Muted), null, 22, 22, 10);
            Place(duplicate.gameObject, new Vector2(-40, -2), new Vector2(1, 1), new Vector2(1, 1), new Vector2(22, 22), new Vector2(1, 1));
            var remove = PremiumTextButton(row.transform, "×", () => DeleteItem(id), Color.clear, ParseColor("#EF4444"), null, 22, 22, 13);
            Place(remove.gameObject, new Vector2(-18, -2), new Vector2(1, 1), new Vector2(1, 1), new Vector2(22, 22), new Vector2(1, 1));
        }

        private void AddSectionTitle(Transform parent, string title, float x, float y)
        {
            var t = Text(parent, title, 12, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(t.gameObject, new Vector2(x, y), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-32, 20), new Vector2(0.5f, 1));
        }

        private void AddInfoRow(Transform parent, string label, string value, float x, float y)
        {
            var l = Text(parent, label, 10, FontStyle.Bold, ParseColor("#667085"), TextAnchor.MiddleLeft);
            Place(l.gameObject, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1), new Vector2(102, 18));
            var v = Text(parent, value, 10, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleRight);
            Place(v.gameObject, new Vector2(-16, y), new Vector2(1, 1), new Vector2(1, 1), new Vector2(186, 18), new Vector2(1, 1));
        }

        private void AddHintBox(Transform parent, string text, float x, float y, float w, float h)
        {
            var box = PremiumCard(parent, "Hint Box", ParseColor("#F8FAFC"), 14, ParseColor("#E2E8F0"), Vector2.zero);
            Place(box, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1), new Vector2(w, h));
            var t = Text(box.transform, text, 9, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
            Place(t.gameObject, new Vector2(12, -8), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-24, h - 14), new Vector2(0.5f, 1));
        }

        private bool IsLineLike(string type)
        {
            return type == "pass" || type == "run" || type == "curve" || type == "line" || type == "dashed" || type == "measurement" || type == "offside" || type == "matchup";
        }

        private bool IsZoneLike(string type)
        {
            return type == "zone" || type == "hatched_zone" || type == "circle" || type == "spotlight";
        }

        private string ObjectDisplayName(Sportoteka3DProPlanItem item)
        {
            if (item == null) return "Объект";
            if (item.type == "player" || item.type == "opponent")
            {
                string who = item.type == "opponent" ? "Соперник" : "Игрок";
                string num = item.number > 0 ? " №" + item.number : "";
                return who + num;
            }
            return TypeTitle(item.type);
        }

        private string ObjectSubtitle(Sportoteka3DProPlanItem item)
        {
            if (item == null) return "";
            if (item.locked) return "Заблокирован · " + item.id;
            if (!item.visible) return "Скрыт · " + item.id;
            return "Слой " + Mathf.Max(1, _items.IndexOf(item) + 1) + " · " + item.id;
        }

        private string ToolToIconKey(Sportoteka3DProTool tool)
        {
            switch (tool)
            {
                case Sportoteka3DProTool.Select: return "tg_select";
                case Sportoteka3DProTool.Player: return "tg_player";
                case Sportoteka3DProTool.Opponent: return "tg_opponent";
                case Sportoteka3DProTool.Ball: return "tg_ball";
                case Sportoteka3DProTool.PassArrow: return "tg_pass";
                case Sportoteka3DProTool.RunArrow: return "tg_run";
                case Sportoteka3DProTool.CurveArrow: return "tg_curve";
                case Sportoteka3DProTool.Line: return "tg_line";
                case Sportoteka3DProTool.DashedLine: return "tg_line";
                case Sportoteka3DProTool.Zone:
                case Sportoteka3DProTool.HatchedZone: return "tg_zone";
                case Sportoteka3DProTool.Text: return "tg_text";
                case Sportoteka3DProTool.Cone: return "tg_cone";
                case Sportoteka3DProTool.MiniGoal:
                case Sportoteka3DProTool.BigGoal: return "tg_goal";
                case Sportoteka3DProTool.Mannequin: return "tg_mannequin";
                case Sportoteka3DProTool.Measurement: return "tg_measure";
                case Sportoteka3DProTool.Offside: return "tg_offside";
                case Sportoteka3DProTool.Spotlight: return "tg_spotlight";
                case Sportoteka3DProTool.Matchup: return "tg_matchup";
                case Sportoteka3DProTool.CalibrationMarker: return "tg_calibration";
                case Sportoteka3DProTool.TeamBadge: return "tg_brand";
                default: return "tg_layers";
            }
        }

        private string LayerItemTitle(Sportoteka3DProPlanItem item, int number)
        {
            if (item == null) return "Объект";
            string prefix = number.ToString("00") + " • ";

            if (item.type == "player" || item.type == "opponent")
            {
                string who = item.type == "opponent" ? "Соперник" : "Игрок";
                string n = item.number > 0 ? " №" + item.number : "";
                string nm = string.IsNullOrEmpty(item.name) ? item.position : item.name;
                return prefix + who + n + (string.IsNullOrEmpty(nm) ? "" : " — " + nm);
            }

            if (item.type == "pass") return prefix + "Пас " + DistanceText(item);
            if (item.type == "run") return prefix + "Рывок " + DistanceText(item);
            if (item.type == "curve") return prefix + "Кривая стрелка";
            if (item.type == "hatched_zone" || item.type == "zone") return prefix + "Зона анализа";
            if (item.type == "text") return prefix + "Текст: " + (string.IsNullOrEmpty(item.text) ? "подпись" : item.text);

            return prefix + TypeTitle(item.type);
        }

        private string DistanceText(Sportoteka3DProPlanItem item)
        {
            if (item == null) return "0 м";
            float d = Vector3.Distance(new Vector3(item.x, 0, item.z), new Vector3(item.toX, 0, item.toZ));
            return d.ToString("0") + " м";
        }

        private string TypeTitle(string type)
        {
            switch (type)
            {
                case "player": return "Игрок";
                case "opponent": return "Соперник";
                case "pass": return "Пас";
                case "run": return "Рывок";
                case "curve": return "Кривая стрелка";
                case "zone": return "Зона";
                case "hatched_zone": return "Зона анализа";
                case "ball": return "Мяч";
                case "line": return "Линия";
                case "dashed": return "Пунктир";
                case "circle": return "Круг";
                case "cone": return "Конус";
                case "mini_goal": return "Мини-ворота";
                case "big_goal": return "Ворота";
                case "mannequin": return "Манекен";
                case "ladder": return "Лестница";
                case "hurdle": return "Барьер";
                case "gate": return "Ворота/гейт";
                case "pole": return "Стойка";
                case "spotlight": return "Подсветка";
                case "matchup": return "Связь игроков";
                case "offside": return "Офсайд";
                case "measurement": return "Дистанция";
                case "team_badge": return "Логотип команды";
                case "calibration": return "Калибровка";
                case "freehand": return "Свободная линия";
                default: return string.IsNullOrEmpty(type) ? "Объект" : type;
            }
        }

        private string TypeToIconKey(string type)
        {
            switch (type)
            {
                case "player": return "tg_player";
                case "opponent": return "tg_opponent";
                case "ball": return "tg_ball";
                case "pass": return "tg_pass";
                case "run": return "tg_run";
                case "curve": return "tg_curve";
                case "line":
                case "dashed":
                case "freehand": return "tg_line";
                case "zone":
                case "hatched_zone":
                case "circle": return "tg_zone";
                case "text": return "tg_text";
                case "cone": return "tg_cone";
                case "mini_goal":
                case "big_goal":
                case "gate": return "tg_goal";
                case "mannequin": return "tg_mannequin";
                case "ladder": return "tg_ladder";
                case "hurdle": return "tg_wall";
                case "pole": return "tg_wall";
                case "spotlight": return "tg_spotlight";
                case "matchup": return "tg_matchup";
                case "measurement": return "tg_measure";
                case "offside": return "tg_offside";
                case "team_badge": return "tg_brand";
                case "calibration": return "tg_calibration";
                default: return "tg_layers";
            }
        }

        private void DeleteItem(string id)
        {
            var item = FindItem(id);
            if (item == null) return;

            PushHistory();
            _items.Remove(item);
            if (_selectedItemId == id) _selectedItemId = "";

            Rebuild();
            RefreshPremiumInspector();
            RefreshPremiumLayersPanel();
            RefreshPremiumMiniMap();
            MarkDirty("Слой удалён: " + TypeTitle(item.type));
        }

        private void SendSelectedToBack()
        {
            var item = FindItem(_selectedItemId);
            if (item == null) { SetStatus("Сначала выбери слой."); return; }
            PushHistory();
            _items.Remove(item);
            _items.Insert(0, item);
            Rebuild();
            SelectItem(item.id);
            MarkDirty("Объект отправлен назад");
        }

        private void ToggleItemVisible(string id)
        {
            var item = FindItem(id);
            if (item == null) return;
            PushHistory();
            item.visible = !item.visible;
            Rebuild();
            SelectItem(item.id);
            MarkDirty(item.visible ? "Слой показан" : "Слой скрыт");
        }

        private void ToggleItemLocked(string id)
        {
            var item = FindItem(id);
            if (item == null) return;
            item.locked = !item.locked;
            SelectItem(item.id);
            SetStatus(item.locked ? "Слой заблокирован" : "Слой разблокирован");
        }

        private void ClearFrames()
        {
            _frames.Clear();
            RefreshPremiumInspector();
            SetStatus("Кадры анимации очищены.");
        }

        private void ShowProLibrary()
        {
            if (_popupRoot == null) return;
            ClearChildren(_popupRoot);
            var shade = Panel(_popupRoot, "PRO Library Shade", new Color(0f, 0f, 0f, 0.26f), 0);
            Place(shade, Vector2.zero, Vector2.zero, Vector2.one, Vector2.zero, new Vector2(0.5f, 0.5f), true);

            var card = PremiumCard(_popupRoot, "Sportoteka PRO Template Library", Color.white, 26, ParseColor("#E2E8F0"), new Vector2(0, -4));
            Place(card, new Vector2(0, 0), new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), new Vector2(760, 520), new Vector2(0.5f, 0.5f));

            var title = Text(card.transform, "PRO-библиотека тактики и анализа", 22, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(title.gameObject, new Vector2(30, -24), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-92, 32), new Vector2(0.5f, 1));
            var subtitle = Text(card.transform, "Готовые сцены для подписки: схемы, прессинг, упражнения, стандарты, брифинги и Field Radar.", 12, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
            Place(subtitle.gameObject, new Vector2(30, -60), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-92, 22), new Vector2(0.5f, 1));
            var close = PremiumTextButton(card.transform, "×", HidePopup, Color.white, ParseColor(Graphite), ParseColor("#E2E8F0"), 38, 34, 16);
            Place(close.gameObject, new Vector2(-30, -24), new Vector2(1, 1), new Vector2(1, 1), new Vector2(38, 34), new Vector2(1, 1));

            ProTemplateButton(card.transform, "Схема 4-3-3", "Стартовая расстановка + линии атаки", "tg_player", () => { HidePopup(); AddPresetList(Sportoteka3DProPresets.Formation433(), "Загружена схема 4-3-3"); }, 30, -112);
            ProTemplateButton(card.transform, "Билдап от ворот", "Выход через шестого и фланг", "tg_pass", () => { HidePopup(); ApplyBuildUpPreset(); }, 394, -112);
            ProTemplateButton(card.transform, "Контратака 3v2", "Быстрый переход с передачей в зону", "tg_run", () => { HidePopup(); AddPresetList(Sportoteka3DProPresets.CounterAttack3v2Pack(), "Загружена контратака 3v2"); }, 30, -196);
            ProTemplateButton(card.transform, "Высокий прессинг", "Триггеры, зона ловушки, офсайд", "tg_analysis", () => { HidePopup(); ApplyPressingPreset(); }, 394, -196);
            ProTemplateButton(card.transform, "Рондо 5v2", "Упражнение с фишками, мячом и задачей", "tg_drill", () => { HidePopup(); AddPresetList(Sportoteka3DProPresets.Rondo5v2Pack(), "Загружено упражнение Рондо 5v2"); }, 30, -280);
            ProTemplateButton(card.transform, "Скоростные станции", "Конусы, лестница, барьеры, ворота", "tg_cone", () => { HidePopup(); AddPresetList(Sportoteka3DProPresets.SpeedStationsPack(), "Загружены скоростные станции"); }, 394, -280);
            ProTemplateButton(card.transform, "Field Radar", "Компактность, ширина, глубина блока", "tg_measure", () => { HidePopup(); ApplyFieldRadarPreset(); }, 30, -364);
            ProTemplateButton(card.transform, "Брифинг клуба", "Showcase-слайд с брендированием", "tg_brand", () => { HidePopup(); ApplyShowcasePreset(); }, 394, -364);
        }

        private void ProTemplateButton(Transform parent, string title, string desc, string icon, UnityEngine.Events.UnityAction action, float x, float y)
        {
            var card = PremiumCard(parent, "Template " + title, ParseColor("#F8FAFC"), 18, ParseColor("#E2E8F0"), Vector2.zero);
            Place(card, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1), new Vector2(336, 66));
            var btn = card.AddComponent<Button>();
            btn.targetGraphic = card.GetComponent<Image>();
            btn.onClick.AddListener(action);
            var orb = CirclePanel(card.transform, "Template Icon", Color.white, ParseColor("#E2E8F0"), false);
            Place(orb, new Vector2(16, -13), new Vector2(0, 1), new Vector2(0, 1), new Vector2(40, 40));
            AddIcon(orb.transform, icon, ParseColor(GreenDark), new Vector2(9, -9), new Vector2(22, 22));
            var t = Text(card.transform, title, 13, FontStyle.Bold, ParseColor(Graphite), TextAnchor.MiddleLeft);
            Place(t.gameObject, new Vector2(68, -12), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-82, 22), new Vector2(0.5f, 1));
            var d = Text(card.transform, desc, 10, FontStyle.Bold, ParseColor(Muted), TextAnchor.MiddleLeft);
            Place(d.gameObject, new Vector2(68, -36), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-82, 18), new Vector2(0.5f, 1));
        }

        private void DrawInspectorStylePreview(Transform parent, string type)
        {
            bool dashed = type == "dashed" || type == "run";
            bool arrow = type == "pass" || type == "run" || type == "curve";
            if (dashed)
            {
                for (int i = 0; i < 6; i++)
                {
                    var dash = Panel(parent, "Preview Dash", _activeColor, 3);
                    Place(dash, new Vector2(24 + i * 38, -15), new Vector2(0, 1), new Vector2(0, 1), new Vector2(24, 4));
                }
            }
            else
            {
                var line = Panel(parent, "Preview Solid", _activeColor, 3);
                Place(line, new Vector2(24, -15), new Vector2(0, 1), new Vector2(0, 1), new Vector2(218, 4));
            }
            if (arrow)
            {
                var a1 = Panel(parent, "Preview Arrow A", _activeColor, 3);
                Place(a1, new Vector2(236, -11), new Vector2(0, 1), new Vector2(0, 1), new Vector2(24, 4));
                a1.GetComponent<RectTransform>().localRotation = Quaternion.Euler(0, 0, -32);
                var a2 = Panel(parent, "Preview Arrow B", _activeColor, 3);
                Place(a2, new Vector2(236, -19), new Vector2(0, 1), new Vector2(0, 1), new Vector2(24, 4));
                a2.GetComponent<RectTransform>().localRotation = Quaternion.Euler(0, 0, 32);
            }
        }

        private void PremiumColorDot(Transform parent, string hex, float x, float y, bool active)
        {
            var ring = Panel(parent, "Color Ring " + hex, active ? Color.white : Color.clear, 14, active ? ParseColor(Green) : (Color?)null);
            Place(ring, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1), new Vector2(32, 32));
            var dot = Panel(ring.transform, "Color " + hex, ParseColor(hex), 12, ParseColor("#E5E7EB"));
            Place(dot, new Vector2(4, -4), new Vector2(0, 1), new Vector2(0, 1), new Vector2(24, 24));
            var b = ring.AddComponent<Button>();
            b.targetGraphic = ring.GetComponent<Image>();
            b.onClick.AddListener(() => { SetActiveColor(hex); RefreshPremiumInspector(); });
        }

        private void BuildPremiumMiniMap(Transform parent)
        {
            var card = PremiumCard(parent, "Premium Field Radar V11", WithAlpha(ParseColor("#16212B"), 0.94f), 18, null, new Vector2(0, -3));
            Place(card, new Vector2(-28, 24), new Vector2(1, 0), new Vector2(1, 0), new Vector2(232, 162), new Vector2(1, 0));
            _miniMapRoot = card.transform;
            RefreshPremiumMiniMap();
        }

        private void RefreshPremiumMiniMap()
        {
            if (_miniMapRoot == null) return;
            ClearChildren(_miniMapRoot);

            PremiumMiniButton(_miniMapRoot, _drawingsVisible ? "◉" : "◎", () => ToggleDrawingsVisible(), 30);
            PremiumMiniButton(_miniMapRoot, _cameraLocked ? "🔒" : "⌑", () => ToggleCameraLock(), 106);
            PremiumMiniButton(_miniMapRoot, "⛶", () => { SetCameraPreset("top"); SetStatus("Field Radar: камера приведена к презентационному виду."); }, 186);
            var line = Panel(_miniMapRoot, "Map Header Line", ParseColor("#475569"), 0);
            Place(line, new Vector2(18, -40), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-36, 1), new Vector2(0.5f, 1));

            var pitch = Panel(_miniMapRoot, "Mini Pitch", ParseColor("#214F2A"), 8, null);
            Place(pitch, new Vector2(16, -52), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-32, 94), new Vector2(0.5f, 1));
            var input = pitch.AddComponent<Sportoteka3DProMiniMapInput>();
            input.target = pitch.GetComponent<RectTransform>();
            input.onMapClick = OnMiniMapClick;

            PremiumMapPitchLines(pitch.transform);

            int count = 0;
            foreach (var planItem in _items)
            {
                if (Sportoteka3DProDrawingFactory.IsPointType(planItem.type))
                {
                    var c = MapPoint(planItem.x, planItem.z);
                    var color = planItem.type == "opponent" ? ParseColor("#F43F5E") : HtmlOrDefault(planItem.color, ParseColor(Green));
                    PremiumMapDot(pitch.transform, c.x, c.y, color);
                    count++;
                }
                else if (HasEndPoint(planItem))
                {
                    var a = MapPoint(planItem.x, planItem.z);
                    var b = MapPoint(planItem.toX, planItem.toZ);
                    PremiumMapSegment(pitch.transform, a, b, HtmlOrDefault(planItem.color, ParseColor(Green)));
                    count++;
                }
            }

            if (count == 0)
            {
                var empty = Text(pitch.transform, "нет объектов", 10, FontStyle.Bold, WithAlpha(Color.white, 0.62f), TextAnchor.MiddleCenter);
                Place(empty.gameObject, new Vector2(8, -32), new Vector2(0, 1), new Vector2(1, 1), new Vector2(-16, 18), new Vector2(0.5f, 1));
            }
        }

        private void OnMiniMapClick(Vector2 normalized)
        {
            float x = Mathf.Lerp(-34f, 34f, Mathf.Clamp01(normalized.x));
            float z = Mathf.Lerp(-52.5f, 52.5f, Mathf.Clamp01(normalized.y));
            FocusCameraOn(new Vector3(x, 0f, z));
            SetStatus("Field Radar: фокус " + x.ToString("0") + " / " + z.ToString("0") + " м");
        }

        private void ToggleCameraLock()
        {
            _cameraLocked = !_cameraLocked;
            RefreshPremiumMiniMap();
            SetStatus(_cameraLocked ? "Камера заблокирована" : "Камера разблокирована");
        }

        private void PremiumMiniButton(Transform parent, string icon, UnityEngine.Events.UnityAction action, float x)
        {
            var b = PremiumTextButton(parent, icon, action, Color.clear, Color.white, null, 28, 24, 16);
            Place(b.gameObject, new Vector2(x, -12), new Vector2(0, 1), new Vector2(0, 1), new Vector2(28, 24));
        }

        private void ToggleDrawingsVisible()
        {
            if (_drawingRoot == null) return;
            _drawingsVisible = !_drawingsVisible;
            _drawingRoot.gameObject.SetActive(_drawingsVisible);
            RefreshPremiumMiniMap();
            SetStatus(_drawingsVisible ? "Графика включена" : "Графика скрыта");
        }

        private void PremiumMiniIcon(Transform parent, string icon, float x)
        {
            var t = Text(parent, icon, 16, FontStyle.Bold, Color.white, TextAnchor.MiddleCenter);
            Place(t.gameObject, new Vector2(x, -12), new Vector2(0, 1), new Vector2(0, 1), new Vector2(28, 24));
        }

        private void PremiumMapLine(Transform parent, float x, float y, float w, float h)
        {
            var obj = Panel(parent, "Map Line", WithAlpha(Color.white, 0.55f), 0);
            Place(obj, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1), new Vector2(Mathf.Max(1f, w), Mathf.Max(1f, h)));
        }

        private void PremiumMapBox(Transform parent, float x, float y, float w, float h)
        {
            PremiumMapLine(parent, x, y, w, 1);
            PremiumMapLine(parent, x, y - h, w, 1);
            PremiumMapLine(parent, x, y, 1, h);
            PremiumMapLine(parent, x + w, y, 1, h);
        }

        private void PremiumMapCircle(Transform parent, float cx, float cy, float r)
        {
            var ring = Panel(parent, "Map Circle", Color.clear, 20, WithAlpha(Color.white, 0.45f));
            Place(ring, new Vector2(cx - r, cy + r), new Vector2(0, 1), new Vector2(0, 1), new Vector2(r * 2f, r * 2f));
        }

        private void PremiumMapDot(Transform parent, float x, float y, Color color)
        {
            var dot = Panel(parent, "Map Dot", color, 4, Color.white);
            Place(dot, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1), new Vector2(8, 8));
        }

        private void PremiumMapPitchLines(Transform parent)
        {
            // Mini Field Radar pitch: same coordinate space as MapPoint() below.
            // Width = 176 px, height = 72 px, origin = top-left (8, -8).
            PremiumMapBox(parent, 8f, -8f, 176f, 72f);
            PremiumMapLine(parent, 96f, -8f, 1f, 72f);
            PremiumMapCircle(parent, 96f, -44f, 12f);

            // Penalty boxes and goal areas.
            PremiumMapBox(parent, 8f, -23f, 28f, 42f);
            PremiumMapBox(parent, 156f, -23f, 28f, 42f);
            PremiumMapBox(parent, 8f, -32f, 12f, 24f);
            PremiumMapBox(parent, 172f, -32f, 12f, 24f);

            // Small goals outside the pitch.
            PremiumMapBox(parent, 3f, -36f, 5f, 16f);
            PremiumMapBox(parent, 184f, -36f, 5f, 16f);

            // Center spot.
            var center = Panel(parent, "Map Center Spot", WithAlpha(Color.white, 0.82f), 2);
            Place(center, new Vector2(94f, -42f), new Vector2(0, 1), new Vector2(0, 1), new Vector2(4f, 4f));
        }

        private Vector2 MapPoint(float x, float z)
        {
            float px = 8f + Mathf.Clamp01((x + 34f) / 68f) * 176f;
            float py = -8f - Mathf.Clamp01((z + 52.5f) / 105f) * 72f;
            return new Vector2(px, py);
        }

        private bool HasEndPoint(Sportoteka3DProPlanItem item)
        {
            if (item == null) return false;
            return item.type == "pass" || item.type == "run" || item.type == "curve" || item.type == "line" ||
                   item.type == "dashed" || item.type == "measurement" || item.type == "offside" || item.type == "matchup";
        }

        private Color HtmlOrDefault(string hex, Color fallback)
        {
            Color c;
            if (!string.IsNullOrEmpty(hex) && ColorUtility.TryParseHtmlString(hex, out c)) return c;
            return fallback;
        }

        private void PremiumMapSegment(Transform parent, Vector2 a, Vector2 b, Color color)
        {
            var obj = Panel(parent, "Map Segment", WithAlpha(color, 0.86f), 2);
            Vector2 mid = (a + b) * 0.5f;
            float len = Vector2.Distance(a, b);
            Place(obj, new Vector2(mid.x - len * 0.5f, mid.y + 1f), new Vector2(0, 1), new Vector2(0, 1), new Vector2(Mathf.Max(4f, len), 2f));
            obj.GetComponent<RectTransform>().localRotation = Quaternion.Euler(0, 0, Mathf.Atan2(b.y - a.y, b.x - a.x) * Mathf.Rad2Deg);
        }

        private Button PremiumTinyButton(Transform parent, string label, UnityEngine.Events.UnityAction action, float x, float y, float w = 24, float h = 24, int size = 16)
        {
            var b = PremiumTextButton(parent, label, action, Color.clear, ParseColor(Graphite), null, w, h, size);
            Place(b.gameObject, new Vector2(x - w * 0.5f, y), new Vector2(0, 1), new Vector2(0, 1), new Vector2(w, h));
            return b;
        }

        private Button PremiumTextButton(Transform parent, string label, UnityEngine.Events.UnityAction action, Color bg, Color fg, Color? border, float width, float height, int fontSize = 13)
        {
            var obj = PremiumCard(parent, "Premium Button " + label, bg, Mathf.Min(14, height * 0.35f), border, Vector2.zero);
            var rt = obj.GetComponent<RectTransform>();
            rt.sizeDelta = new Vector2(width, height);
            var btn = obj.AddComponent<Button>();
            btn.targetGraphic = obj.GetComponent<Image>();
            btn.onClick.AddListener(action);
            var t = Text(obj.transform, label, fontSize, FontStyle.Bold, fg, TextAnchor.MiddleCenter);
            Place(t.gameObject, Vector2.zero, new Vector2(0, 0), new Vector2(1, 1), Vector2.zero, new Vector2(0.5f, 0.5f), true);
            return btn;
        }

        private UnityEngine.UI.Slider PremiumSlider(Transform parent, string name, float min, float max, float value, UnityEngine.Events.UnityAction<float> onChange)
        {
            // V11: standard Unity slider hierarchy. Thin track, small handle,
            // no oversized green slab.
            var obj = new GameObject(name);
            obj.transform.SetParent(parent, false);
            var rootRt = obj.AddComponent<RectTransform>();
            var slider = obj.AddComponent<UnityEngine.UI.Slider>();
            slider.minValue = min;
            slider.maxValue = max;
            slider.value = value;
            slider.direction = UnityEngine.UI.Slider.Direction.LeftToRight;
            slider.onValueChanged.AddListener(onChange);

            var bg = Panel(obj.transform, "Background", ParseColor("#E7EBF0"), 3);
            var bgRt = bg.GetComponent<RectTransform>();
            bgRt.anchorMin = new Vector2(0, 0.5f);
            bgRt.anchorMax = new Vector2(1, 0.5f);
            bgRt.pivot = new Vector2(0.5f, 0.5f);
            bgRt.anchoredPosition = Vector2.zero;
            bgRt.sizeDelta = new Vector2(0, 4);

            var fillArea = new GameObject("Fill Area");
            fillArea.transform.SetParent(obj.transform, false);
            var faRt = fillArea.AddComponent<RectTransform>();
            faRt.anchorMin = new Vector2(0, 0);
            faRt.anchorMax = new Vector2(1, 1);
            faRt.offsetMin = new Vector2(0, 0);
            faRt.offsetMax = new Vector2(0, 0);

            var fill = Panel(fillArea.transform, "Fill", ParseColor(Green), 3);
            var fillRt = fill.GetComponent<RectTransform>();
            fillRt.anchorMin = new Vector2(0, 0.5f);
            fillRt.anchorMax = new Vector2(1, 0.5f);
            fillRt.pivot = new Vector2(0.5f, 0.5f);
            fillRt.anchoredPosition = Vector2.zero;
            fillRt.sizeDelta = new Vector2(0, 4);
            slider.fillRect = fillRt;

            var handleArea = new GameObject("Handle Slide Area");
            handleArea.transform.SetParent(obj.transform, false);
            var haRt = handleArea.AddComponent<RectTransform>();
            haRt.anchorMin = new Vector2(0, 0);
            haRt.anchorMax = new Vector2(1, 1);
            haRt.offsetMin = new Vector2(0, 0);
            haRt.offsetMax = new Vector2(0, 0);

            var handle = Panel(handleArea.transform, "Handle", Color.white, 7, ParseColor("#CBD5E1"));
            var hRt = handle.GetComponent<RectTransform>();
            hRt.sizeDelta = new Vector2(14, 14);
            hRt.pivot = new Vector2(0.5f, 0.5f);
            hRt.anchorMin = new Vector2(0, 0.5f);
            hRt.anchorMax = new Vector2(0, 0.5f);
            hRt.anchoredPosition = Vector2.zero;
            slider.handleRect = hRt;
            slider.targetGraphic = handle.GetComponent<Image>();
            return slider;
        }

        private GameObject PremiumCard(Transform parent, string name, Color color, float radius, Color? border, Vector2 shadowOffset)
        {
            var obj = Panel(parent, name, color, radius, border);
            if (shadowOffset.sqrMagnitude > 0.01f)
            {
                var shadow = obj.AddComponent<Shadow>();
                shadow.effectColor = WithAlpha(ParseColor("#64748B"), 0.13f);
                shadow.effectDistance = shadowOffset;
                shadow.useGraphicAlpha = true;
            }
            return obj;
        }

        private void AddIcon(Transform parent, string resourceKey, Color color, Vector2 pos, Vector2 size)
        {
            var obj = new GameObject("Icon " + resourceKey);
            obj.transform.SetParent(parent, false);
            obj.AddComponent<RectTransform>();
            var img = obj.AddComponent<Image>();
            img.sprite = LoadIconSprite(resourceKey);
            img.color = color;
            img.preserveAspect = true;
            img.raycastTarget = false;
            Place(obj, pos, new Vector2(0, 1), new Vector2(0, 1), size);
        }

        private Sprite LoadIconSprite(string resourceKey)
        {
            var tex = Resources.Load<Texture2D>("Icons/" + resourceKey);
            if (tex == null) return RoundedSprite();
            return Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), new Vector2(0.5f, 0.5f), 100f);
        }


        private GameObject CirclePanel(Transform parent, string name, Color color, Color? border = null, bool shadow = false)
        {
            var obj = new GameObject(name);
            obj.transform.SetParent(parent, false);
            obj.AddComponent<RectTransform>();
            var img = obj.AddComponent<Image>();
            img.sprite = CircleSprite();
            img.type = Image.Type.Simple;
            img.color = color;
            if (border.HasValue)
            {
                var outline = obj.AddComponent<Outline>();
                outline.effectColor = border.Value;
                outline.effectDistance = new Vector2(1f, -1f);
                outline.useGraphicAlpha = false;
            }
            if (shadow)
            {
                var sh = obj.AddComponent<Shadow>();
                sh.effectColor = WithAlpha(ParseColor("#0F172A"), 0.16f);
                sh.effectDistance = new Vector2(0, -3);
                sh.useGraphicAlpha = true;
            }
            return obj;
        }

        private static Sprite CircleSprite()
        {
            if (_circleSprite != null) return _circleSprite;
            const int size = 96;
            float radius = (size - 2) * 0.5f;
            Vector2 center = new Vector2((size - 1) * 0.5f, (size - 1) * 0.5f);
            var texture = new Texture2D(size, size, TextureFormat.RGBA32, false);
            texture.name = "Sportoteka UI Circle Sprite";
            var clear = new Color(1f, 1f, 1f, 0f);
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float d = Vector2.Distance(new Vector2(x, y), center);
                    float a = Mathf.Clamp01(radius + 0.5f - d);
                    texture.SetPixel(x, y, new Color(1f, 1f, 1f, a));
                }
            }
            texture.Apply();
            _circleSprite = Sprite.Create(texture, new Rect(0, 0, size, size), new Vector2(0.5f, 0.5f), 100f);
            return _circleSprite;
        }

        private void PlaceStretch(GameObject obj, Vector2 offsetMin, Vector2 offsetMax, Vector2 anchorMin, Vector2 anchorMax)
        {
            var rt = obj.GetComponent<RectTransform>();
            rt.anchorMin = anchorMin;
            rt.anchorMax = anchorMax;
            rt.pivot = new Vector2(0.5f, 0.5f);
            rt.offsetMin = offsetMin;
            rt.offsetMax = offsetMax;
        }

        private void HandleDrawingInput()
        {
            if (IsPointerOverUI()) return;

            if (_tool == Sportoteka3DProTool.Select)
            {
                HandleSelectionMoveInput();
                return;
            }

            Vector3 hit;
            if (PointerDown())
            {
                if (!TryFieldPoint(PointerPosition(), out hit)) return;
                _dragStart = Snap(hit);

                if (IsPointTool(_tool))
                {
                    AddPointItem(_dragStart);
                    return;
                }

                _dragging = true;
                DrawPreview(_dragStart, _dragStart);
            }
            else if (_dragging && PointerHeld())
            {
                if (!TryFieldPoint(PointerPosition(), out hit)) return;
                DrawPreview(_dragStart, Snap(hit));
            }
            else if (_dragging && PointerUp())
            {
                if (!TryFieldPoint(PointerPosition(), out hit)) return;
                CommitDrag(_dragStart, Snap(hit));
                ClearChildren(_previewRoot);
                _dragging = false;
            }
        }

        private void HandleSelectionMoveInput()
        {
            Vector3 hit;

            if (PointerDown())
            {
                TrySelect();
                var item = FindItem(_selectedItemId);
                if (item == null || item.locked) return;
                if (!TryFieldPoint(PointerPosition(), out hit)) return;

                _movingSelected = true;
                _movingSelectedId = item.id;
                _moveStartPoint = Snap(hit);
                _moveOriginalItem = item.Clone();
                PushHistory();
                SetStatus("Перетаскивание: " + ObjectDisplayName(item) + ". Отпусти, чтобы зафиксировать.");
                return;
            }

            if (_movingSelected && PointerHeld())
            {
                var item = FindItem(_movingSelectedId);
                if (item == null || _moveOriginalItem == null) { StopSelectionMove(false); return; }
                if (!TryFieldPoint(PointerPosition(), out hit)) return;

                Vector3 current = Snap(hit);
                Vector3 delta = current - _moveStartPoint;
                MoveItemFromSnapshot(item, _moveOriginalItem, delta.x, delta.z);
                Rebuild();
                SelectItem(item.id);
                return;
            }

            if (_movingSelected && PointerUp())
            {
                StopSelectionMove(true);
            }
        }

        private void StopSelectionMove(bool commit)
        {
            if (commit)
            {
                var item = FindItem(_movingSelectedId);
                if (item != null)
                {
                    Rebuild();
                    SelectItem(item.id);
                    MarkDirty("Объект перемещён: " + ObjectDisplayName(item));
                }
            }

            _movingSelected = false;
            _movingSelectedId = "";
            _moveOriginalItem = null;
        }

        private void MoveItemFromSnapshot(Sportoteka3DProPlanItem target, Sportoteka3DProPlanItem source, float dx, float dz)
        {
            if (target == null || source == null) return;

            target.x = Mathf.Clamp(source.x + dx, -52.5f, 52.5f);
            target.z = Mathf.Clamp(source.z + dz, -34f, 34f);

            if (!Sportoteka3DProDrawingFactory.IsPointType(target.type))
            {
                target.toX = Mathf.Clamp(source.toX + dx, -52.5f, 52.5f);
                target.toZ = Mathf.Clamp(source.toZ + dz, -34f, 34f);
                target.controlX = Mathf.Clamp(source.controlX + dx, -52.5f, 52.5f);
                target.controlZ = Mathf.Clamp(source.controlZ + dz, -34f, 34f);
            }
        }

        private void HandleCameraInput()
        {
            if (_cameraLocked) return;
#if ENABLE_INPUT_SYSTEM
            var mouse = Mouse.current;
            if (mouse == null || IsPointerOverUI()) return;
            var delta = mouse.delta.ReadValue();
            if (mouse.rightButton.isPressed && delta.sqrMagnitude > 0.01f) RotateCamera(delta.x * 0.18f);
            if (mouse.middleButton.isPressed && delta.sqrMagnitude > 0.01f) PanCamera(-delta.x * 0.025f, -delta.y * 0.025f);
            float scroll = mouse.scroll.ReadValue().y;
            if (Mathf.Abs(scroll) > 0.01f) ZoomCamera(-scroll * 0.035f);
#else
            if (IsPointerOverUI()) return;
            if (Input.GetMouseButton(1)) RotateCamera(Input.GetAxis("Mouse X") * 2.2f);
            if (Input.GetMouseButton(2)) PanCamera(-Input.GetAxis("Mouse X") * 1.3f, -Input.GetAxis("Mouse Y") * 1.3f);
            float wheel = Input.mouseScrollDelta.y;
            if (Mathf.Abs(wheel) > 0.01f) ZoomCamera(-wheel * 2.5f);
#endif
        }

        private bool IsPointTool(Sportoteka3DProTool tool)
        {
            return tool == Sportoteka3DProTool.Player || tool == Sportoteka3DProTool.Opponent || tool == Sportoteka3DProTool.Text ||
                   tool == Sportoteka3DProTool.Cone || tool == Sportoteka3DProTool.Ball || tool == Sportoteka3DProTool.MiniGoal ||
                   tool == Sportoteka3DProTool.BigGoal || tool == Sportoteka3DProTool.Mannequin || tool == Sportoteka3DProTool.Ladder ||
                   tool == Sportoteka3DProTool.Hurdle || tool == Sportoteka3DProTool.Gate || tool == Sportoteka3DProTool.Pole ||
                   tool == Sportoteka3DProTool.Spotlight || tool == Sportoteka3DProTool.TeamBadge || tool == Sportoteka3DProTool.CalibrationMarker;
        }

        private void AddPointItem(Vector3 p)
        {
            var item = NewItem(ToolToType(_tool));
            item.x = p.x;
            item.z = p.z;

            if (_tool == Sportoteka3DProTool.Player || _tool == Sportoteka3DProTool.Opponent)
            {
                var player = _selectedPlayer ?? _players[0];
                item.number = player.number;
                item.name = player.name;
                item.position = player.position;
                item.initials = player.initials;
                item.avatarUrl = player.avatarUrl;
                item.avatarPath = player.avatarPath;
                item.color = _tool == Sportoteka3DProTool.Opponent ? "#EF4444" : Green;
            }
            else if (_tool == Sportoteka3DProTool.Text)
            {
                item.text = _selectedPlayer != null ? ("№" + _selectedPlayer.number + " " + _selectedPlayer.position) : "TEXT";
                item.color = ColorToHex(_activeColor);
            }
            else
            {
                item.color = DefaultColorForTool(_tool);
            }

            AddItem(item, true);
        }

        private void CommitDrag(Vector3 a, Vector3 b)
        {
            if ((a - b).sqrMagnitude < 0.12f) return;

            var item = NewItem(ToolToType(_tool));
            item.x = a.x;
            item.z = a.z;
            item.toX = b.x;
            item.toZ = b.z;
            item.controlX = (a.x + b.x) * 0.5f;
            item.controlZ = (a.z + b.z) * 0.5f + Mathf.Clamp(Vector3.Distance(a, b) * 0.22f, 2f, 9f);
            item.color = ColorToHex(_activeColor);
            item.width = _activeWidth;
            item.alpha = _activeAlpha;

            AddItem(item, true);
        }

        private Sportoteka3DProPlanItem NewItem(string type)
        {
            return new Sportoteka3DProPlanItem
            {
                id = "item_" + (++_counter),
                type = type,
                width = _activeWidth,
                alpha = _activeAlpha,
                scale = 1.0f,
                rotation = 0.0f,
                color = ColorToHex(_activeColor)
            };
        }

        private void AddItem(Sportoteka3DProPlanItem item, bool select)
        {
            PushHistory();
            _items.Add(item);
            CreateItem(item, _drawingRoot, false);
            if (select) SelectItem(item.id);
            RefreshPremiumLayersPanel();
            RefreshPremiumMiniMap();
            MarkDirty("Добавлен объект: " + TypeTitle(item.type));
        }

        private void DrawPreview(Vector3 a, Vector3 b)
        {
            ClearChildren(_previewRoot);
            var item = NewItem(ToolToType(_tool));
            item.x = a.x;
            item.z = a.z;
            item.toX = b.x;
            item.toZ = b.z;
            item.controlX = (a.x + b.x) * 0.5f;
            item.controlZ = (a.z + b.z) * 0.5f + 5f;
            item.color = ColorToHex(_activeColor);
            item.width = _activeWidth;
            item.alpha = _activeAlpha;
            CreateItem(item, _previewRoot, true);
        }

        private void CreateItem(Sportoteka3DProPlanItem item, Transform parent, bool preview)
        {
            if (!preview && item != null && !item.visible) return;
            Texture2D avatar = FindAvatar(item.number);
            var holder = Sportoteka3DProDrawingFactory.Create(item, parent, avatar, preview);
            if (!preview) AddSelectionProxy(holder, item);
        }

        private void AddSelectionProxy(GameObject holder, Sportoteka3DProPlanItem item)
        {
            if (holder == null || item == null) return;

            GameObject proxy;
            if (Sportoteka3DProDrawingFactory.IsPointType(item.type))
            {
                proxy = GameObject.CreatePrimitive(PrimitiveType.Sphere);
                proxy.transform.SetParent(holder.transform, false);
                proxy.transform.position = new Vector3(item.x, 0.9f, item.z);
                float r = Mathf.Clamp(item.scale * 1.65f, 1.25f, 3.2f);
                proxy.transform.localScale = new Vector3(r, 0.7f, r);
            }
            else
            {
                proxy = GameObject.CreatePrimitive(PrimitiveType.Cube);
                proxy.transform.SetParent(holder.transform, false);
                Vector3 a = new Vector3(item.x, 0.75f, item.z);
                Vector3 b = new Vector3(item.toX, 0.75f, item.toZ);
                Vector3 delta = b - a;
                proxy.transform.position = a + delta * 0.5f;

                if (item.type == "zone" || item.type == "hatched_zone")
                {
                    proxy.transform.localScale = new Vector3(Mathf.Abs(item.toX - item.x) + 1.2f, 0.9f, Mathf.Abs(item.toZ - item.z) + 1.2f);
                }
                else
                {
                    float len = Mathf.Max(1.4f, delta.magnitude);
                    proxy.transform.rotation = delta.sqrMagnitude > 0.01f ? Quaternion.LookRotation(delta.normalized, Vector3.up) : Quaternion.identity;
                    proxy.transform.localScale = new Vector3(1.25f, 0.9f, len + 1.0f);
                }
            }

            proxy.name = "PLAN_" + item.id + "_" + item.type + "_select_proxy";
            var renderer = proxy.GetComponent<MeshRenderer>();
            if (renderer != null) renderer.enabled = false;
        }

        private Texture2D FindAvatar(int number)
        {
            foreach (var p in _players)
            {
                if (p.number == number) return p.avatarTexture;
            }
            return null;
        }

        private string ToolToType(Sportoteka3DProTool tool)
        {
            switch (tool)
            {
                case Sportoteka3DProTool.Player: return "player";
                case Sportoteka3DProTool.Opponent: return "opponent";
                case Sportoteka3DProTool.PassArrow: return "pass";
                case Sportoteka3DProTool.RunArrow: return "run";
                case Sportoteka3DProTool.CurveArrow: return "curve";
                case Sportoteka3DProTool.Line: return "line";
                case Sportoteka3DProTool.DashedLine: return "dashed";
                case Sportoteka3DProTool.Zone: return "zone";
                case Sportoteka3DProTool.HatchedZone: return "hatched_zone";
                case Sportoteka3DProTool.Circle: return "circle";
                case Sportoteka3DProTool.Text: return "text";
                case Sportoteka3DProTool.Cone: return "cone";
                case Sportoteka3DProTool.Ball: return "ball";
                case Sportoteka3DProTool.MiniGoal: return "mini_goal";
                case Sportoteka3DProTool.BigGoal: return "big_goal";
                case Sportoteka3DProTool.Mannequin: return "mannequin";
                case Sportoteka3DProTool.Ladder: return "ladder";
                case Sportoteka3DProTool.Hurdle: return "hurdle";
                case Sportoteka3DProTool.Gate: return "gate";
                case Sportoteka3DProTool.Pole: return "pole";
                case Sportoteka3DProTool.Spotlight: return "spotlight";
                case Sportoteka3DProTool.Matchup: return "matchup";
                case Sportoteka3DProTool.Offside: return "offside";
                case Sportoteka3DProTool.Measurement: return "measurement";
                case Sportoteka3DProTool.TeamBadge: return "team_badge";
                case Sportoteka3DProTool.CalibrationMarker: return "calibration";
            }
            return "line";
        }

        private string DefaultColorForTool(Sportoteka3DProTool tool)
        {
            if (tool == Sportoteka3DProTool.Cone || tool == Sportoteka3DProTool.Ladder || tool == Sportoteka3DProTool.Gate) return "#F97316";
            if (tool == Sportoteka3DProTool.Mannequin) return "#F59E0B";
            if (tool == Sportoteka3DProTool.Hurdle || tool == Sportoteka3DProTool.Offside) return "#F43F5E";
            if (tool == Sportoteka3DProTool.Ball || tool == Sportoteka3DProTool.MiniGoal || tool == Sportoteka3DProTool.BigGoal) return "#FFFFFF";
            if (tool == Sportoteka3DProTool.CalibrationMarker || tool == Sportoteka3DProTool.Measurement) return "#38BDF8";
            return ColorToHex(_activeColor);
        }

        private void TrySelect()
        {
            var cam = Camera.main;
            if (cam == null) return;

            Ray ray = cam.ScreenPointToRay(PointerPosition());
            RaycastHit[] hits = Physics.RaycastAll(ray, 800f);
            if (hits == null || hits.Length == 0)
            {
                SelectItem("");
                return;
            }

            string bestId = "";
            int bestScore = -100000;
            float bestDistance = float.MaxValue;

            for (int i = 0; i < hits.Length; i++)
            {
                string id = ExtractPlanId(hits[i].collider != null ? hits[i].collider.transform : null);
                if (string.IsNullOrEmpty(id) || id == "selection") continue;

                var item = FindItem(id);
                if (item == null) continue;

                int score = SelectionPriority(item);
                if (item.id == _selectedItemId) score += 20;

                // Later objects are visually on top, so they win when priorities are close.
                int drawIndex = _items.IndexOf(item);
                score += drawIndex;

                if (score > bestScore || (score == bestScore && hits[i].distance < bestDistance))
                {
                    bestScore = score;
                    bestDistance = hits[i].distance;
                    bestId = id;
                }
            }

            SelectItem(bestId);
        }

        private string ExtractPlanId(Transform t)
        {
            while (t != null)
            {
                if (t.name.StartsWith("PLAN_"))
                {
                    string rest = t.name.Substring(5);
                    string[] known = { "_hatched_zone", "_mini_goal", "_big_goal", "_team_badge", "_calibration", "_measurement", "_mannequin", "_spotlight", "_opponent", "_player", "_pass", "_run", "_curve", "_dashed", "_zone", "_circle", "_text", "_cone", "_ball", "_ladder", "_hurdle", "_gate", "_pole", "_matchup", "_offside", "_line", "_preview" };
                    foreach (var suffix in known)
                    {
                        int idx = rest.IndexOf(suffix, StringComparison.Ordinal);
                        if (idx > 0) return rest.Substring(0, idx);
                    }

                    // Backward-compatible fallback for PLAN_item_12_type.
                    string[] parts = t.name.Split('_');
                    if (parts.Length >= 3) return parts[1] + "_" + parts[2];
                }

                t = t.parent;
            }
            return "";
        }

        private int SelectionPriority(Sportoteka3DProPlanItem item)
        {
            if (item == null) return 0;
            if (item.type == "player" || item.type == "opponent" || item.type == "ball") return 500;
            if (Sportoteka3DProDrawingFactory.IsPointType(item.type)) return 420;
            if (item.type == "pass" || item.type == "run" || item.type == "curve" || item.type == "measurement" || item.type == "offside") return 360;
            if (item.type == "text") return 340;
            if (item.type == "line" || item.type == "dashed") return 300;
            if (item.type == "zone" || item.type == "hatched_zone" || item.type == "circle") return 120;
            return 200;
        }

        private void SelectItem(string id)
        {
            _selectedItemId = id;
            ClearChildren(_selectionRoot);

            var item = FindItem(id);
            if (item == null)
            {
                if (_selectedText != null) _selectedText.text = "Выбран: объект";
                RefreshPremiumInspector();
                RefreshPremiumLayersPanel();
                return;
            }

            _activeColor = HtmlOrDefault(item.color, _activeColor);
            _activeWidth = item.width;
            _activeAlpha = item.alpha;
            if (_selectedText != null) _selectedText.text = "Выбран: " + LayerItemTitle(item, Mathf.Max(1, _items.IndexOf(item) + 1));
            RefreshPremiumInspector();
            RefreshPremiumLayersPanel();
            Sportoteka3DProDrawingFactory.Create(new Sportoteka3DProPlanItem
            {
                id = "selection",
                type = "circle",
                x = Sportoteka3DProDrawingFactory.Center(item).x,
                z = Sportoteka3DProDrawingFactory.Center(item).z,
                toX = Sportoteka3DProDrawingFactory.Center(item).x + Sportoteka3DProDrawingFactory.Radius(item),
                toZ = Sportoteka3DProDrawingFactory.Center(item).z,
                color = "#FDE047",
                width = 0.055f
            }, _selectionRoot, null, false);
        }

        private Sportoteka3DProPlanItem FindItem(string id)
        {
            if (string.IsNullOrEmpty(id)) return null;
            foreach (var item in _items)
            {
                if (item.id == id) return item;
            }
            return null;
        }

        private void DeleteSelected()
        {
            var item = FindItem(_selectedItemId);
            if (item == null) { SetStatus("Сначала выбери объект."); return; }
            PushHistory();
            _items.Remove(item);
            _selectedItemId = "";
            Rebuild();
            MarkDirty("Объект удалён");
        }

        private void DuplicateSelected()
        {
            var item = FindItem(_selectedItemId);
            if (item == null) { SetStatus("Сначала выбери объект."); return; }
            PushHistory();
            var copy = item.Clone();
            copy.id = "item_" + (++_counter);
            copy.x += 2f;
            copy.z += 2f;
            copy.toX += 2f;
            copy.toZ += 2f;
            _items.Add(copy);
            Rebuild();
            SelectItem(copy.id);
            MarkDirty("Копия создана");
        }

        private void ScaleSelected(float factor)
        {
            var item = FindItem(_selectedItemId);
            if (item == null) { SetStatus("Сначала выбери объект."); return; }
            PushHistory();

            if (Sportoteka3DProDrawingFactory.IsPointType(item.type))
            {
                item.scale = Mathf.Clamp(item.scale * factor, 0.35f, 4f);
            }
            else
            {
                Vector3 c = Sportoteka3DProDrawingFactory.Center(item);
                Vector3 a = new Vector3(item.x, 0, item.z);
                Vector3 b = new Vector3(item.toX, 0, item.toZ);
                a = c + (a - c) * factor;
                b = c + (b - c) * factor;
                item.x = a.x; item.z = a.z; item.toX = b.x; item.toZ = b.z;
                item.width = Mathf.Clamp(item.width * Mathf.Lerp(1f, factor, 0.35f), 0.035f, 0.45f);
            }

            Rebuild();
            SelectItem(item.id);
            MarkDirty("Размер изменён");
        }

        private void RotateSelected(float degrees)
        {
            var item = FindItem(_selectedItemId);
            if (item == null) { SetStatus("Сначала выбери объект."); return; }
            PushHistory();

            if (Sportoteka3DProDrawingFactory.IsPointType(item.type))
            {
                item.rotation += degrees;
            }
            else
            {
                Vector3 c = Sportoteka3DProDrawingFactory.Center(item);
                Vector3 a = Rotate(new Vector3(item.x, 0, item.z), c, degrees);
                Vector3 b = Rotate(new Vector3(item.toX, 0, item.toZ), c, degrees);
                item.x = a.x; item.z = a.z; item.toX = b.x; item.toZ = b.z;
            }

            Rebuild();
            SelectItem(item.id);
            MarkDirty("Объект повернут");
        }

        private Vector3 Rotate(Vector3 p, Vector3 center, float degrees)
        {
            return center + Quaternion.Euler(0, degrees, 0) * (p - center);
        }

        private void BringSelectedToFront()
        {
            var item = FindItem(_selectedItemId);
            if (item == null) return;
            _items.Remove(item);
            _items.Add(item);
            Rebuild();
            SelectItem(item.id);
            MarkDirty("Объект поднят выше");
        }

        private void ResetSelected()
        {
            var item = FindItem(_selectedItemId);
            if (item == null) return;
            PushHistory();
            item.scale = 1;
            item.rotation = 0;
            item.width = 0.07f;
            Rebuild();
            SelectItem(item.id);
            MarkDirty("Сброс объекта");
        }

        private void ApplyStyleToSelected()
        {
            var item = FindItem(_selectedItemId);
            if (item == null) return;
            PushHistory();
            item.color = ColorToHex(_activeColor);
            item.width = _activeWidth;
            item.alpha = _activeAlpha;
            Rebuild();
            SelectItem(item.id);
            MarkDirty("Стиль применён");
        }

        private void Rebuild()
        {
            ClearChildren(_drawingRoot);
            ClearChildren(_selectionRoot);
            foreach (var item in _items) CreateItem(item, _drawingRoot, false);
            RefreshPremiumMiniMap();
            RefreshPremiumLayersPanel();
        }

        private void ClearPlan()
        {
            PushHistory();
            _items.Clear();
            _selectedItemId = "";
            Rebuild();
            MarkDirty("План очищен");
        }

        private void SeedProfessionalDemoIfEmpty()
        {
            // V16: no automatic demo overload. A professional tactical board must
            // open cleanly; presets are available from the mode banner when the
            // coach chooses them. This avoids visual clutter and makes selection
            // predictable from the first click.
            if (_items.Count > 0) return;
            _selectedItemId = "";
            _undoStack.Clear();
            _redoStack.Clear();
        }

        private void ApplyModePreset()
        {
            if (_mode == Sportoteka3DProMode.Animation) { AddAnimationExample(); return; }

            List<Sportoteka3DProPlanItem> preset = null;
            if (_mode == Sportoteka3DProMode.Tactics) preset = Sportoteka3DProPresets.Formation433();
            else if (_mode == Sportoteka3DProMode.Analysis) preset = Sportoteka3DProPresets.PressingTriggerPack();
            else if (_mode == Sportoteka3DProMode.Drill) preset = Sportoteka3DProPresets.DrillPack();
            else if (_mode == Sportoteka3DProMode.Calibration) preset = Sportoteka3DProPresets.CalibrationPack();
            else if (_mode == Sportoteka3DProMode.Branding) preset = Sportoteka3DProPresets.BrandingPack(_teamName);

            AddPresetList(preset, "Добавлен футбольный пресет: " + ModeTitle(_mode));
        }

        private void ApplyBuildUpPreset()
        {
            AddPresetList(Sportoteka3DProPresets.BuildUpPatternPack(), "Добавлен билдап-паттерн");
        }

        private void ApplySetPiecePreset()
        {
            AddPresetList(Sportoteka3DProPresets.SetPieceCornerPack(), "Добавлен стандарт: угловой");
        }

        private void ApplyPressingPreset()
        {
            AddPresetList(Sportoteka3DProPresets.PressingTriggerPack(), "Добавлен анализ прессинга");
        }

        private void ApplyFieldRadarPreset()
        {
            AddPresetList(Sportoteka3DProPresets.FieldRadarPack(), "Добавлен Field Radar / компактность");
        }

        private void ApplyShowcasePreset()
        {
            AddPresetList(Sportoteka3DProPresets.ShowcasePack(_teamName), "Добавлен презентационный брифинг");
        }

        private void AddPresetList(List<Sportoteka3DProPlanItem> preset, string message)
        {
            if (preset == null) return;
            PushHistory();
            _items.Clear();
            _selectedItemId = "";
            foreach (var item in preset)
            {
                item.id = "item_" + (++_counter);
                HydratePresetPlayer(item);
                _items.Add(item);
            }
            Rebuild();
            if (_items.Count > 0) SelectItem(_items[0].id);
            SetTool(Sportoteka3DProTool.Select);
            RefreshPremiumInspector();
            RefreshPremiumLayersPanel();
            MarkDirty(message + ". Сцена заменена шаблоном, объекты можно выделять и переносить.");
        }

        private void HydratePresetPlayer(Sportoteka3DProPlanItem item)
        {
            if (item == null || (item.type != "player" && item.type != "opponent")) return;
            if (item.type == "opponent") return;

            Sportoteka3DProPlayerData player = null;
            for (int i = 0; i < _players.Count; i++)
            {
                if (_players[i].number == item.number) { player = _players[i]; break; }
            }

            if (player == null) return;
            item.name = player.name;
            item.position = string.IsNullOrEmpty(player.position) ? item.position : player.position;
            item.role = player.role;
            item.initials = player.initials;
            item.avatarUrl = player.avatarUrl;
            item.avatarPath = player.avatarPath;
            item.color = string.IsNullOrEmpty(player.teamColor) ? item.color : player.teamColor;
        }

        private void AddAnimationExample()
        {
            PushHistory();
            _items.Clear();
            _selectedItemId = "";
            var list = Sportoteka3DProPresets.Formation433();
            foreach (var item in list)
            {
                item.id = "item_" + (++_counter);
                HydratePresetPlayer(item);
                _items.Add(item);
            }
            Rebuild();
            if (_items.Count > 0) SelectItem(_items[0].id);
            StartCoroutine(PlayBallAnimation());
            MarkDirty("Анимационный пример запущен");
        }

        private System.Collections.IEnumerator PlayBallAnimation()
        {
            var ball = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            ball.name = "AnimationExampleBall";
            ball.transform.SetParent(_drawingRoot, false);
            ball.transform.localScale = new Vector3(0.52f, 0.52f, 0.52f);
            Vector3 a = new Vector3(0, 0.42f, 4);
            Vector3 b = new Vector3(12, 0.42f, -8);
            Vector3 c = new Vector3(0, 0.42f, -28);
            ball.transform.position = a;
            float d = 1.2f;
            float t = 0;
            while (t < d)
            {
                t += Time.deltaTime;
                ball.transform.position = Vector3.Lerp(a, b, Mathf.Clamp01(t / d));
                yield return null;
            }
            t = 0;
            while (t < d)
            {
                t += Time.deltaTime;
                ball.transform.position = Vector3.Lerp(b, c, Mathf.Clamp01(t / d));
                yield return null;
            }
            Destroy(ball, 1.0f);
        }


        private void PushHistory()
        {
            if (_historyLocked) return;
            _undoStack.Add(CloneItems().ToArray());
            if (_undoStack.Count > 40) _undoStack.RemoveAt(0);
            _redoStack.Clear();
        }

        private void RestoreSnapshot(Sportoteka3DProPlanItem[] snapshot)
        {
            _items.Clear();
            if (snapshot != null)
            {
                foreach (var item in snapshot)
                {
                    if (item != null) _items.Add(item.Clone());
                }
            }
            _selectedItemId = "";
            Rebuild();
            RefreshPremiumInspector();
            RefreshPremiumLeftToolbar();
            RefreshPremiumBottomDock();
        }

        private void UndoLastAction()
        {
            if (_undoStack.Count == 0)
            {
                SetStatus("Нет действий для отмены");
                return;
            }
            _historyLocked = true;
            _redoStack.Add(CloneItems().ToArray());
            var last = _undoStack[_undoStack.Count - 1];
            _undoStack.RemoveAt(_undoStack.Count - 1);
            RestoreSnapshot(last);
            _historyLocked = false;
            SetStatus("Действие отменено");
        }

        private void RedoLastAction()
        {
            if (_redoStack.Count == 0)
            {
                SetStatus("Нет действий для повтора");
                return;
            }
            _historyLocked = true;
            _undoStack.Add(CloneItems().ToArray());
            var next = _redoStack[_redoStack.Count - 1];
            _redoStack.RemoveAt(_redoStack.Count - 1);
            RestoreSnapshot(next);
            _historyLocked = false;
            SetStatus("Действие повторено");
        }

        private void SaveFrame()
        {
            var snapshot = new Sportoteka3DProFrameSnapshot
            {
                frameIndex = _frames.Count + 1,
                items = CloneItems().ToArray()
            };
            _frames.Add(snapshot);
            SetStatus("Кадр сохранён: " + snapshot.frameIndex);
        }

        private void LoadFrame(int frame)
        {
            foreach (var f in _frames)
            {
                if (f.frameIndex == frame)
                {
                    PushHistory();
                    _items.Clear();
                    foreach (var item in f.items) _items.Add(item.Clone());
                    Rebuild();
                    SetStatus("Кадр загружен: " + frame);
                    return;
                }
            }
            SetStatus("Кадр " + frame + " ещё не сохранён.");
        }

        private void PlayFrames()
        {
            if (_frames.Count == 0) { SetStatus("Нет кадров для проигрывания."); return; }
            StartCoroutine(PlayFrameRoutine());
        }

        private System.Collections.IEnumerator PlayFrameRoutine()
        {
            foreach (var f in _frames)
            {
                _items.Clear();
                foreach (var item in f.items) _items.Add(item.Clone());
                Rebuild();
                SetStatus("Кадр: " + f.frameIndex);
                yield return new WaitForSeconds(0.7f);
            }
        }

        private List<Sportoteka3DProPlanItem> CloneItems()
        {
            var list = new List<Sportoteka3DProPlanItem>();
            foreach (var item in _items) list.Add(item.Clone());
            return list;
        }

        private void ExportPng()
        {
            string file = "sportoteka_football_board_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".png";
            string path = Path.Combine(Application.persistentDataPath, file);
            ScreenCapture.CaptureScreenshot(path);
            SetStatus("PNG экспортирован: " + path);
        }

        private void ExportJson()
        {
            var snapshot = new Sportoteka3DProPlanSnapshot
            {
                title = "Sportoteka Football Board Export",
                teamName = _teamName,
                items = _items.ToArray()
            };
            string file = "sportoteka_football_board_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".json";
            string path = Path.Combine(Application.persistentDataPath, file);
            File.WriteAllText(path, JsonUtility.ToJson(snapshot, true));
            SetStatus("JSON экспортирован: " + path);
        }

        private void SavePlan()
        {
            Sportoteka3DProPlanStorage.Save(_teamName, _items);
            SetStatus("План сохранён");
        }

        private void LoadPlan()
        {
            var snapshot = Sportoteka3DProPlanStorage.Load();
            if (snapshot == null || snapshot.items == null) { SetStatus("Сохранённый план не найден."); return; }
            _items.Clear();
            foreach (var item in snapshot.items) _items.Add(item.Clone());
            Rebuild();
            SetStatus("План загружен");
        }

        private void RequestClose()
        {
            SavePlan();
#if UNITY_EDITOR
            UnityEditor.EditorApplication.isPlaying = false;
#else
            Application.Quit();
#endif
        }

        private string ModeTitle(Sportoteka3DProMode mode)
        {
            switch (mode)
            {
                case Sportoteka3DProMode.Tactics: return "Схема";
                case Sportoteka3DProMode.Analysis: return "Анализ";
                case Sportoteka3DProMode.Drill: return "Упражнение";
                case Sportoteka3DProMode.Animation: return "Анимация";
                case Sportoteka3DProMode.Calibration: return "Калибровка";
                case Sportoteka3DProMode.Branding: return "Брифинг";
                default: return mode.ToString();
            }
        }

        private string ToolTitle(Sportoteka3DProTool tool)
        {
            switch (tool)
            {
                case Sportoteka3DProTool.Select: return "Выбор";
                case Sportoteka3DProTool.Player: return "Игрок";
                case Sportoteka3DProTool.Opponent: return "Соперник";
                case Sportoteka3DProTool.PassArrow: return "Пас";
                case Sportoteka3DProTool.RunArrow: return "Рывок";
                case Sportoteka3DProTool.CurveArrow: return "Кривая стрелка";
                case Sportoteka3DProTool.Line: return "Линия";
                case Sportoteka3DProTool.DashedLine: return "Пунктир";
                case Sportoteka3DProTool.Freehand: return "Свободное рисование";
                case Sportoteka3DProTool.Zone: return "Зона";
                case Sportoteka3DProTool.HatchedZone: return "Штрихованная зона";
                case Sportoteka3DProTool.Circle: return "Круг";
                case Sportoteka3DProTool.Text: return "Подпись";
                case Sportoteka3DProTool.Cone: return "Конус";
                case Sportoteka3DProTool.Ball: return "Мяч";
                case Sportoteka3DProTool.MiniGoal: return "Мини-ворота";
                case Sportoteka3DProTool.BigGoal: return "Большие ворота";
                case Sportoteka3DProTool.Mannequin: return "Манекен";
                case Sportoteka3DProTool.Ladder: return "Лестница";
                case Sportoteka3DProTool.Hurdle: return "Барьер";
                case Sportoteka3DProTool.Gate: return "Гейт";
                case Sportoteka3DProTool.Pole: return "Стойка";
                case Sportoteka3DProTool.Spotlight: return "Подсветка";
                case Sportoteka3DProTool.Matchup: return "Связь игроков";
                case Sportoteka3DProTool.Offside: return "Линия офсайда";
                case Sportoteka3DProTool.Measurement: return "Дистанция";
                case Sportoteka3DProTool.TeamBadge: return "Логотип команды";
                case Sportoteka3DProTool.CalibrationMarker: return "Точка калибровки";
                default: return tool.ToString();
            }
        }

        private void SetMode(Sportoteka3DProMode mode)
        {
            _mode = mode;
            if (_modeText != null) _modeText.text = ModeTitle(_mode) + " • " + _teamName;
            RefreshModeActionPanel();
            RefreshPremiumLeftToolbar();
            RefreshPremiumBottomDock();
            RefreshPremiumInspector();
            RefreshPremiumLayersPanel();
            SetStatus("Режим: " + ModeTitle(mode) + ".");
        }

        private void SetTool(Sportoteka3DProTool tool)
        {
            _tool = tool;
            RefreshPremiumLeftToolbar();
            RefreshPremiumBottomDock();
            RefreshPremiumInspector();
            RefreshPremiumLayersPanel();
            SetStatus("Инструмент: " + ToolTitle(tool) + ".");
        }

        private void SelectPlayer(Sportoteka3DProPlayerData player)
        {
            _selectedPlayer = player;
            SetTool(Sportoteka3DProTool.Player);
            SetStatus("Выбран игрок №" + player.number + " — " + player.name + ". Теперь кликни по полю.");
        }

        private void SetLineWidth(float value)
        {
            _activeWidth = Mathf.Clamp(value, 0.025f, 0.16f);
            ApplyActiveStyleLive(false);
        }

        private void SetAlpha(float value)
        {
            _activeAlpha = Mathf.Clamp01(value);
            var item = FindItem(_selectedItemId);
            if (item != null)
            {
                item.alpha = _activeAlpha;
                Rebuild();
                SelectItem(item.id);
            }
        }

        private void SetActiveColor(string hex)
        {
            _activeColor = ParseColor(hex);
            ApplyActiveStyleLive(true);
            SetStatus("Цвет: " + hex);
        }


        private int LineWidthPx(float value)
        {
            return Mathf.Clamp(Mathf.RoundToInt(Mathf.Lerp(1f, 7f, Mathf.InverseLerp(0.025f, 0.16f, value))), 1, 7);
        }

        private void ApplyActiveStyleLive(bool refreshInspector)
        {
            var item = FindItem(_selectedItemId);
            if (item == null) return;
            item.color = ColorToHex(_activeColor);
            item.width = _activeWidth;
            item.alpha = _activeAlpha;
            Rebuild();
            SelectItem(item.id);
            if (refreshInspector) RefreshPremiumInspector();
        }

        private void SetLineStyle(string style)
        {
            var item = FindItem(_selectedItemId);
            if (item == null)
            {
                if (style == "dashed") SetTool(Sportoteka3DProTool.DashedLine);
                else if (style == "arrow") SetTool(Sportoteka3DProTool.PassArrow);
                else SetTool(Sportoteka3DProTool.Line);
                return;
            }

            PushHistory();
            bool arrowLike = item.type == "pass" || item.type == "run";
            if (style == "arrow") item.type = "pass";
            else if (style == "dashed") item.type = arrowLike ? "run" : "dashed";
            else item.type = arrowLike ? "pass" : "line";

            item.color = ColorToHex(_activeColor);
            item.width = _activeWidth;
            Rebuild();
            SelectItem(item.id);
            SetStatus("Стиль линии: " + style);
        }

        private void ColorDot(Transform parent, string hex, float x, float y)
        {
            var dot = Panel(parent, "Color " + hex, ParseColor(hex), 12, ParseColor(Border));
            Place(dot, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1), new Vector2(24, 24));
            var b = dot.AddComponent<Button>();
            b.targetGraphic = dot.GetComponent<Image>();
            b.onClick.AddListener(() => SetActiveColor(hex));
        }

        private void RotateCamera(float yaw)
        {
            var cam = Camera.main;
            if (cam == null) return;
            cam.transform.RotateAround(Vector3.zero, Vector3.up, yaw);
            cam.transform.LookAt(Vector3.zero);
            SetStatus("Камера поворот");
        }

        private void ZoomCamera(float amount)
        {
            var cam = Camera.main;
            if (cam == null) return;
            if (cam.orthographic)
            {
                cam.orthographicSize = Mathf.Clamp(cam.orthographicSize + amount, 24f, 66f);
            }
            else
            {
                cam.transform.position += cam.transform.forward * amount;
                cam.transform.LookAt(Vector3.zero);
            }
            SetStatus("Камера zoom");
        }

        private void PanCamera(float right, float forward)
        {
            var cam = Camera.main;
            if (cam == null) return;
            Vector3 r = cam.transform.right; r.y = 0; r.Normalize();
            Vector3 f = Vector3.Cross(r, Vector3.up).normalized;
            cam.transform.position += r * right + f * forward;
            SetStatus("Камера сдвиг");
        }

        private void SetCameraPreset(string preset)
        {
            var cam = Camera.main;
            if (cam == null) return;
            _cameraPreset = string.IsNullOrEmpty(preset) ? "top" : preset;

            if (_cameraPreset == "top" || _cameraPreset == "2d")
            {
                // Professional "2D presentation" camera: still reads as a tactical board,
                // but with a slight stadium perspective like the approved mockup.
                cam.orthographic = true;
                cam.orthographicSize = 48f;
                cam.transform.position = new Vector3(0f, 72f, -42f);
                cam.transform.rotation = Quaternion.Euler(62f, 0f, 0f);
                cam.clearFlags = CameraClearFlags.SolidColor;
                cam.backgroundColor = ParseColor("#F6F8FA");
            }
            else
            {
                cam.orthographic = false;
                cam.transform.position = new Vector3(0f, 46f, -70f);
                cam.transform.LookAt(new Vector3(0f, 0f, 0f));
                cam.fieldOfView = 34f;
                cam.clearFlags = CameraClearFlags.SolidColor;
                cam.backgroundColor = ParseColor("#F6F8FA");
            }

            RebuildPremiumTopBarOnly();
            SetStatus("Камера: " + (_cameraPreset == "tactical" ? "3D тактика" : "2D презентационный обзор"));
        }

        private void FocusCameraOn(Vector3 target)
        {
            var cam = Camera.main;
            if (cam == null) return;
            if (_cameraPreset == "tactical")
            {
                cam.transform.position = target + new Vector3(0f, 38f, -42f);
                cam.transform.LookAt(target);
            }
            else
            {
                cam.orthographic = true;
                cam.orthographicSize = 34f;
                cam.transform.position = target + new Vector3(0f, 62f, -34f);
                cam.transform.rotation = Quaternion.Euler(62f, 0f, 0f);
            }
        }

        private void RebuildPremiumTopBarOnly()
        {
            if (_canvas == null) return;
            for (int i = _canvas.transform.childCount - 1; i >= 0; i--)
            {
                var child = _canvas.transform.GetChild(i);
                if (child.name.Contains("Top Command") || child.name.Contains("Top Bar")) Destroy(child.gameObject);
            }
            BuildPremiumTopBar(_canvas.transform);
        }

        private bool TryFieldPoint(Vector2 screen, out Vector3 hit)
        {
            hit = Vector3.zero;
            var cam = Camera.main;
            if (cam == null) return false;
            Ray ray = cam.ScreenPointToRay(screen);
            Plane plane = new Plane(Vector3.up, Vector3.zero);
            float dist;
            if (!plane.Raycast(ray, out dist)) return false;
            hit = ray.GetPoint(dist);
            return true;
        }

        private Vector3 Snap(Vector3 v)
        {
            return new Vector3(Mathf.Round(v.x * 2f) * 0.5f, 0, Mathf.Round(v.z * 2f) * 0.5f);
        }

        private void MarkDirty(string message)
        {
            SetStatus(message);
        }

        private void SetStatus(string message)
        {
            if (_statusText != null) _statusText.text = message;
            Debug.Log("[Sportoteka3DPro] " + message);
        }

        private void ClearChildren(Transform parent)
        {
            if (parent == null) return;
            for (int i = parent.childCount - 1; i >= 0; i--)
            {
                Destroy(parent.GetChild(i).gameObject);
            }
        }

        private bool IsPointerOverUI()
        {
            return EventSystem.current != null && EventSystem.current.IsPointerOverGameObject();
        }

        private Vector2 PointerPosition()
        {
#if ENABLE_INPUT_SYSTEM
            return Pointer.current != null ? Pointer.current.position.ReadValue() : Vector2.zero;
#else
            return Input.mousePosition;
#endif
        }

        private bool PointerDown()
        {
#if ENABLE_INPUT_SYSTEM
            return Pointer.current != null && Pointer.current.press.wasPressedThisFrame;
#else
            return Input.GetMouseButtonDown(0);
#endif
        }

        private bool PointerHeld()
        {
#if ENABLE_INPUT_SYSTEM
            return Pointer.current != null && Pointer.current.press.isPressed;
#else
            return Input.GetMouseButton(0);
#endif
        }

        private bool PointerUp()
        {
#if ENABLE_INPUT_SYSTEM
            return Pointer.current != null && Pointer.current.press.wasReleasedThisFrame;
#else
            return Input.GetMouseButtonUp(0);
#endif
        }

        private bool KeyDown(string key)
        {
#if ENABLE_INPUT_SYSTEM
            var kb = Keyboard.current;
            if (kb == null) return false;
            if (key == "escape") return kb.escapeKey.wasPressedThisFrame;
            if (key == "delete") return kb.deleteKey.wasPressedThisFrame;
            if (key == "backspace") return kb.backspaceKey.wasPressedThisFrame;
            if (key == "plus") return kb.equalsKey.wasPressedThisFrame || kb.numpadPlusKey.wasPressedThisFrame;
            if (key == "minus") return kb.minusKey.wasPressedThisFrame || kb.numpadMinusKey.wasPressedThisFrame;
            if (key == "leftBracket") return kb.leftBracketKey.wasPressedThisFrame;
            if (key == "rightBracket") return kb.rightBracketKey.wasPressedThisFrame;
            if (key == "c") return kb.cKey.wasPressedThisFrame;
            if (key == "s") return kb.sKey.wasPressedThisFrame;
            if (key == "z") return kb.zKey.wasPressedThisFrame;
            if (key == "y") return kb.yKey.wasPressedThisFrame;
            return false;
#else
            if (key == "escape") return Input.GetKeyDown(KeyCode.Escape);
            if (key == "delete") return Input.GetKeyDown(KeyCode.Delete);
            if (key == "backspace") return Input.GetKeyDown(KeyCode.Backspace);
            if (key == "plus") return Input.GetKeyDown(KeyCode.Equals) || Input.GetKeyDown(KeyCode.KeypadPlus);
            if (key == "minus") return Input.GetKeyDown(KeyCode.Minus) || Input.GetKeyDown(KeyCode.KeypadMinus);
            if (key == "leftBracket") return Input.GetKeyDown(KeyCode.LeftBracket);
            if (key == "rightBracket") return Input.GetKeyDown(KeyCode.RightBracket);
            if (key == "c") return Input.GetKeyDown(KeyCode.C);
            if (key == "s") return Input.GetKeyDown(KeyCode.S);
            if (key == "z") return Input.GetKeyDown(KeyCode.Z);
            if (key == "y") return Input.GetKeyDown(KeyCode.Y);
            return false;
#endif
        }

        private void EnsureEventSystem()
        {
            if (EventSystem.current != null) return;
            var es = new GameObject("EventSystem");
            es.AddComponent<EventSystem>();
#if ENABLE_INPUT_SYSTEM
            es.AddComponent<InputSystemUIInputModule>();
#else
            es.AddComponent<StandaloneInputModule>();
#endif
        }

        private GameObject Panel(Transform parent, string name, Color color, float radius, Color? border = null)
        {
            var obj = new GameObject(name);
            obj.transform.SetParent(parent, false);
            obj.AddComponent<RectTransform>();
            var img = obj.AddComponent<Image>();
            img.color = color;

            if (radius > 0)
            {
                img.sprite = RoundedSprite();
                img.type = Image.Type.Sliced;
            }

            if (border.HasValue)
            {
                var outline = obj.AddComponent<Outline>();
                outline.effectColor = border.Value;
                outline.effectDistance = new Vector2(1f, -1f);
                outline.useGraphicAlpha = false;
            }

            return obj;
        }

        private static Sprite RoundedSprite()
        {
            if (_roundedSprite != null) return _roundedSprite;

            const int size = 64;
            const int radius = 18;
            var texture = new Texture2D(size, size, TextureFormat.RGBA32, false);
            texture.name = "Sportoteka UI Rounded Sprite";

            var clear = new Color(1f, 1f, 1f, 0f);
            var white = Color.white;

            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    bool inside =
                        (x >= radius && x < size - radius) ||
                        (y >= radius && y < size - radius) ||
                        Vector2.Distance(new Vector2(x, y), new Vector2(radius, radius)) <= radius ||
                        Vector2.Distance(new Vector2(x, y), new Vector2(size - radius - 1, radius)) <= radius ||
                        Vector2.Distance(new Vector2(x, y), new Vector2(radius, size - radius - 1)) <= radius ||
                        Vector2.Distance(new Vector2(x, y), new Vector2(size - radius - 1, size - radius - 1)) <= radius;

                    texture.SetPixel(x, y, inside ? white : clear);
                }
            }

            texture.Apply();
            _roundedSprite = Sprite.Create(texture, new Rect(0, 0, size, size), new Vector2(0.5f, 0.5f), 100f, 0, SpriteMeshType.FullRect, new Vector4(radius, radius, radius, radius));
            return _roundedSprite;
        }

        private Text Text(Transform parent, string value, int size, FontStyle style, Color color, TextAnchor anchor)
        {
            var obj = new GameObject("Text");
            obj.transform.SetParent(parent, false);
            obj.AddComponent<RectTransform>();
            var text = obj.AddComponent<Text>();
            text.text = value;
            text.font = Resources.GetBuiltinResource<Font>("Arial.ttf");
            text.fontSize = size;
            text.fontStyle = style;
            text.color = color;
            text.alignment = anchor;
            return text;
        }

        private Button TextButton(Transform parent, string label, UnityEngine.Events.UnityAction action, Color bg, Color fg, float width, float height, int fontSize = 11)
        {
            var obj = Panel(parent, "Button " + label, bg, 12);
            var rt = obj.GetComponent<RectTransform>();
            rt.sizeDelta = new Vector2(width, height);
            var btn = obj.AddComponent<Button>();
            btn.targetGraphic = obj.GetComponent<Image>();
            btn.onClick.AddListener(action);
            var t = Text(obj.transform, label, fontSize, FontStyle.Bold, fg, TextAnchor.MiddleCenter);
            Place(t.gameObject, Vector2.zero, new Vector2(0, 0), new Vector2(1, 1), Vector2.zero, new Vector2(0.5f, 0.5f), true);
            return btn;
        }

        private UnityEngine.UI.Slider Slider(Transform parent, string name, float min, float max, float value, UnityEngine.Events.UnityAction<float> onChange)
        {
            var obj = new GameObject(name);
            obj.transform.SetParent(parent, false);
            obj.AddComponent<RectTransform>();
            var slider = obj.AddComponent<UnityEngine.UI.Slider>();
            slider.minValue = min;
            slider.maxValue = max;
            slider.value = value;
            slider.onValueChanged.AddListener(onChange);

            var bg = Panel(obj.transform, "Bg", ParseColor("#E5E7EB"), 5);
            Place(bg, Vector2.zero, new Vector2(0, 0.5f), new Vector2(1, 0.5f), new Vector2(0, 6), new Vector2(0.5f, 0.5f));
            var fill = Panel(obj.transform, "Fill", ParseColor(Green), 5);
            Place(fill, Vector2.zero, new Vector2(0, 0.5f), new Vector2(1, 0.5f), new Vector2(0, 6), new Vector2(0.5f, 0.5f));
            slider.fillRect = fill.GetComponent<RectTransform>();
            var handle = Panel(obj.transform, "Handle", Color.white, 9, ParseColor(Green));
            Place(handle, Vector2.zero, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), new Vector2(18, 18), new Vector2(0.5f, 0.5f));
            slider.handleRect = handle.GetComponent<RectTransform>();
            slider.targetGraphic = handle.GetComponent<Image>();
            return slider;
        }

        private void Analog(Transform parent, string label, UnityEngine.Events.UnityAction action, float x, float y)
        {
            var b = TextButton(parent, label, action, ParseColor("#F8FAFC"), ParseColor(Graphite), 34, 30, 12);
            Place(b.gameObject, new Vector2(x, y), new Vector2(0, 1), new Vector2(0, 1));
        }

        private void Place(GameObject obj, Vector2 anchored, Vector2 anchorMin, Vector2 anchorMax, Vector2 size, Vector2 pivot, bool stretchOffsets = false)
        {
            var rt = obj.GetComponent<RectTransform>();
            rt.anchorMin = anchorMin;
            rt.anchorMax = anchorMax;
            rt.pivot = pivot;
            if (stretchOffsets)
            {
                rt.offsetMin = Vector2.zero;
                rt.offsetMax = Vector2.zero;
            }
            else
            {
                rt.anchoredPosition = anchored;
                rt.sizeDelta = size;
            }
        }

        private void Place(GameObject obj, Vector2 anchored, Vector2 anchorMin, Vector2 anchorMax)
        {
            Place(obj, anchored, anchorMin, anchorMax, obj.GetComponent<RectTransform>().sizeDelta, new Vector2(0, 1));
        }

        private void Place(GameObject obj, Vector2 anchored, Vector2 anchorMin, Vector2 anchorMax, Vector2 size)
        {
            Place(obj, anchored, anchorMin, anchorMax, size, new Vector2(0, 1));
        }

        private static Color ParseColor(string hex)
        {
            Color c;
            return ColorUtility.TryParseHtmlString(hex, out c) ? c : Color.white;
        }

        private static Color WithAlpha(Color c, float alpha)
        {
            c.a = alpha;
            return c;
        }

        private static string ColorToHex(Color c)
        {
            return "#" + ColorUtility.ToHtmlStringRGB(c);
        }
    }
}
