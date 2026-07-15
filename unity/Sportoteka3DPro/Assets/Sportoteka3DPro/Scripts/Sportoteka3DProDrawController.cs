using UnityEngine;

#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

namespace Sportoteka3DPro
{
    public sealed class Sportoteka3DProDrawController : MonoBehaviour
    {
        public bool externalLegacyDrawingEnabled = false;
        public Transform drawingRoot;
        public string activeTool = "select";
        public string toolColor = "#FDE047";
        public bool snapToGrid = true;
        public float grid = 1f;

        private bool _dragging;
        private Vector3 _start;
        private GameObject _preview;
        private int _counter;

#if ENABLE_LEGACY_INPUT_MANAGER
        private bool _lastPointerDown;
#endif

        public void SetTool(string tool)
        {
            activeTool = string.IsNullOrEmpty(tool) ? "select" : tool.ToLowerInvariant();
            Debug.Log("[Sportoteka3DPro] Draw tool active: " + activeTool);
        }

        public void SetColor(string color)
        {
            if (!string.IsNullOrEmpty(color))
            {
                toolColor = color;
                Debug.Log("[Sportoteka3DPro] Draw color active: " + toolColor);
            }
        }

        public void SetSnap(string value)
        {
            snapToGrid = value == "1" || value == "true" || value == "yes";
            Debug.Log("[Sportoteka3DPro] Snap to grid: " + snapToGrid);
        }

        public void ClearDrawings()
        {
            if (drawingRoot == null) return;

            for (int i = drawingRoot.childCount - 1; i >= 0; i--)
            {
                Destroy(drawingRoot.GetChild(i).gameObject);
            }

            Debug.Log("[Sportoteka3DPro] Drawings cleared.");
        }

        private void Update()
        {
            if (!externalLegacyDrawingEnabled) return;
            if (Camera.main == null || drawingRoot == null) return;
            if (activeTool == "select" || activeTool == "none") return;

            Vector3 screen;
            bool down;
            bool held;
            bool up;

            if (!ReadPointer(out screen, out down, out held, out up)) return;

            if (down)
            {
                Vector3 hit;
                if (!TryGetFieldPoint(screen, out hit)) return;

                _start = Snap(hit);
                _dragging = true;

                Debug.Log("[Sportoteka3DPro] Draw start: " + activeTool + " " + _start);

                if (IsPointTool(activeTool))
                {
                    CreatePointTool(_start);
                    _dragging = false;
                    DestroyPreview();
                }
                else
                {
                    CreatePreview(_start, _start);
                }
            }
            else if (_dragging && held)
            {
                Vector3 hit;
                if (!TryGetFieldPoint(screen, out hit)) return;
                UpdatePreview(_start, Snap(hit));
            }
            else if (_dragging && up)
            {
                Vector3 hit;
                if (!TryGetFieldPoint(screen, out hit))
                {
                    _dragging = false;
                    DestroyPreview();
                    return;
                }

                Vector3 end = Snap(hit);
                Commit(_start, end);
                DestroyPreview();
                _dragging = false;

                Debug.Log("[Sportoteka3DPro] Draw commit: " + activeTool + " " + _start + " -> " + end);
            }
        }

        private bool ReadPointer(out Vector3 screen, out bool down, out bool held, out bool up)
        {
            screen = Vector3.zero;
            down = false;
            held = false;
            up = false;

#if ENABLE_INPUT_SYSTEM
            Pointer pointer = Pointer.current;

            if (pointer != null)
            {
                Vector2 pos = pointer.position.ReadValue();
                screen = new Vector3(pos.x, pos.y, 0f);

                down = pointer.press.wasPressedThisFrame;
                held = pointer.press.isPressed;
                up = pointer.press.wasReleasedThisFrame;

                return down || held || up;
            }
#endif

#if ENABLE_LEGACY_INPUT_MANAGER
            screen = Input.mousePosition;

            bool now = Input.GetMouseButton(0);
            down = now && !_lastPointerDown;
            held = now;
            up = !now && _lastPointerDown;
            _lastPointerDown = now;

            return down || held || up;
#else
            return false;
#endif
        }

        private bool IsPointTool(string tool)
        {
            return tool == "player" || tool == "ball" || tool == "cone" || tool == "label" || tool == "press";
        }

        private bool TryGetFieldPoint(Vector3 screen, out Vector3 point)
        {
            Plane plane = new Plane(Vector3.up, Vector3.zero);
            Ray ray = Camera.main.ScreenPointToRay(screen);
            float enter;

            if (plane.Raycast(ray, out enter))
            {
                point = ray.GetPoint(enter);
                point.x = Mathf.Clamp(point.x, -52f, 52f);
                point.z = Mathf.Clamp(point.z, -34f, 34f);
                point.y = 0f;
                return true;
            }

            point = Vector3.zero;
            return false;
        }

        private Vector3 Snap(Vector3 p)
        {
            if (!snapToGrid) return p;

            float g = Mathf.Max(0.25f, grid);
            p.x = Mathf.Round(p.x / g) * g;
            p.z = Mathf.Round(p.z / g) * g;
            return p;
        }

        private void CreatePreview(Vector3 a, Vector3 b)
        {
            DestroyPreview();

            _preview = new GameObject("Drawing Preview");
            _preview.transform.SetParent(transform, false);
            UpdatePreview(a, b);
        }

        private void UpdatePreview(Vector3 a, Vector3 b)
        {
            if (_preview == null) return;

            for (int i = _preview.transform.childCount - 1; i >= 0; i--)
            {
                Destroy(_preview.transform.GetChild(i).gameObject);
            }

            Sportoteka3DProObject item = NewObjectFromTool(a, b);
            item.id = "preview";
            item.opacity = 0.35f;
            Sportoteka3DProObjectFactory.Create(item, _preview.transform);
        }

        private void Commit(Vector3 a, Vector3 b)
        {
            if (Vector3.Distance(a, b) < 0.25f && !IsPointTool(activeTool))
            {
                Debug.Log("[Sportoteka3DPro] Draw ignored: distance too small.");
                return;
            }

            Sportoteka3DProObject item = NewObjectFromTool(a, b);
            item.id = "draw_" + (++_counter);
            Sportoteka3DProObjectFactory.Create(item, drawingRoot);
        }

        private Sportoteka3DProObject NewObjectFromTool(Vector3 a, Vector3 b)
        {
            Sportoteka3DProObject item = new Sportoteka3DProObject();
            item.visible = true;
            item.color = toolColor;
            item.x = a.x;
            item.z = a.z;
            item.toX = b.x;
            item.toZ = b.z;
            item.width = 1.0f;

            if (activeTool == "run")
            {
                item.type = "arrow";
                item.effect = "dash";
                item.color = "#38BDF8";
            }
            else if (activeTool == "pass" || activeTool == "arrow")
            {
                item.type = "arrow";
                item.effect = "glow";
                item.color = toolColor;
            }
            else if (activeTool == "line")
            {
                item.type = "line";
            }
            else if (activeTool == "dashed")
            {
                item.type = "dashed_line";
            }
            else if (activeTool == "zone")
            {
                item.type = "zone";
                item.x = (a.x + b.x) * 0.5f;
                item.z = (a.z + b.z) * 0.5f;
                item.width = Mathf.Abs(b.x - a.x);
                item.length = Mathf.Abs(b.z - a.z);
                item.opacity = 0.22f;

                if (item.width < 1f) item.width = 1f;
                if (item.length < 1f) item.length = 1f;
            }
            else if (activeTool == "circle")
            {
                item.type = "circle";
                item.radius = Mathf.Max(0.7f, Vector3.Distance(a, b));
                item.width = 0.65f;
            }
            else if (activeTool == "offside")
            {
                item.type = "offside_line";
                item.x = a.x;
                item.color = "#F43F5E";
            }
            else
            {
                item.type = "arrow";
            }

            return item;
        }

        private void CreatePointTool(Vector3 p)
        {
            Sportoteka3DProObject item = new Sportoteka3DProObject();
            item.id = "draw_" + (++_counter);
            item.visible = true;
            item.x = p.x;
            item.z = p.z;
            item.color = toolColor;

            if (activeTool == "player")
            {
                item.type = "player";
                item.team = "home";
                item.number = _counter % 99;
                item.label = item.number.ToString();
                item.kitColor = "#16A34A";
            }
            else if (activeTool == "ball")
            {
                item.type = "ball";
            }
            else if (activeTool == "cone")
            {
                item.type = "cone";
                item.color = "#FF7A00";
            }
            else if (activeTool == "press")
            {
                item.type = "pressing";
                item.radius = 4.5f;
                item.color = "#F97316";
            }
            else
            {
                item.type = "label";
                item.label = "Эпизод";
                item.y = 2.0f;
            }

            Sportoteka3DProObjectFactory.Create(item, drawingRoot);
            Debug.Log("[Sportoteka3DPro] Point object created: " + activeTool + " at " + p);
        }

        private void DestroyPreview()
        {
            if (_preview != null) Destroy(_preview);
            _preview = null;
        }
    }
}
