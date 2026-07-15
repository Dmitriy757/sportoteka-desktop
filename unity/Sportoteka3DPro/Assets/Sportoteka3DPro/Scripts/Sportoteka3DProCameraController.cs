using UnityEngine;

namespace Sportoteka3DPro
{
    public sealed class Sportoteka3DProCameraController : MonoBehaviour
    {
        private Camera _camera;

        private void Awake()
        {
            EnsureCamera();
        }

        public void SetTopView()
        {
            SnapTo("top");
        }

        public void SetTacticalView()
        {
            SnapTo("tactical");
        }

        public void SetBroadcastView()
        {
            SnapTo("broadcast");
        }

        public void SetFreeView()
        {
            SnapTo("free");
        }

        public void SnapTo(string preset)
        {
            EnsureCamera();
            if (_camera == null) return;

            string p = string.IsNullOrEmpty(preset) ? "top" : preset.ToLowerInvariant();

            if (p == "top" || p == "2d" || p == "верх" || p == "сверху")
            {
                _camera.orthographic = true;
                _camera.orthographicSize = 56.5f;
                _camera.transform.position = new Vector3(0f, 90f, 0.01f);
                _camera.transform.rotation = Quaternion.Euler(90f, 0f, 0f);
            }
            else if (p == "broadcast" || p == "tv" || p == "трансляция")
            {
                _camera.orthographic = false;
                _camera.transform.position = new Vector3(-58f, 28f, -44f);
                _camera.transform.LookAt(Vector3.zero);
                _camera.fieldOfView = 42f;
            }
            else if (p == "free" || p == "свободная")
            {
                _camera.orthographic = false;
                _camera.transform.position = new Vector3(28f, 34f, -46f);
                _camera.transform.LookAt(Vector3.zero);
                _camera.fieldOfView = 48f;
            }
            else
            {
                _camera.orthographic = false;
                _camera.transform.position = new Vector3(0f, 52f, -64f);
                _camera.transform.LookAt(Vector3.zero);
                _camera.fieldOfView = 38f;
            }
        }

        public void SnapTo(string preset, bool animate)
        {
            SnapTo(preset);
        }

        public void SnapTo(string preset, float duration)
        {
            SnapTo(preset);
        }

        public void SnapTo(string preset, float duration, bool animate)
        {
            SnapTo(preset);
        }

        public void SnapTo(Vector3 position)
        {
            EnsureCamera();
            if (_camera == null) return;

            _camera.transform.position = position;
            _camera.transform.LookAt(Vector3.zero);
        }

        public void SnapTo(Vector3 position, Quaternion rotation)
        {
            EnsureCamera();
            if (_camera == null) return;

            _camera.transform.position = position;
            _camera.transform.rotation = rotation;
        }

        public void SnapTo(Vector3 position, Quaternion rotation, float duration)
        {
            SnapTo(position, rotation);
        }

        public void SnapTo(Vector3 position, Quaternion rotation, float duration, bool animate)
        {
            SnapTo(position, rotation);
        }

        public void SnapTo(Vector3 position, Vector3 lookAt)
        {
            EnsureCamera();
            if (_camera == null) return;

            _camera.transform.position = position;
            _camera.transform.LookAt(lookAt);
        }

        // Универсальный 3-й параметр:
        // старый CameraRig может передавать duration, а новые вызовы могут передавать FOV.
        // Для C# это одна и та же сигнатура, поэтому оставляем только один overload.
        public void SnapTo(Vector3 position, Vector3 lookAt, float value)
        {
            SnapTo(position, lookAt);

            if (_camera != null && value > 5f && value < 120f)
            {
                _camera.fieldOfView = value;
            }
        }

        public void SnapTo(Vector3 position, Vector3 lookAt, float value, bool animate)
        {
            SnapTo(position, lookAt, value);
        }

        public void SnapTo(Transform target)
        {
            if (target == null) return;
            SnapTo(target.position, target.rotation);
        }

        public void SnapTo(Transform target, float duration)
        {
            SnapTo(target);
        }

        public void SnapTo(Transform target, float duration, bool animate)
        {
            SnapTo(target);
        }

        public void SnapTo<T>(T preset)
        {
            SnapTo(preset != null ? preset.ToString() : "tactical");
        }

        public void SnapTo<T>(T preset, bool animate)
        {
            SnapTo(preset);
        }

        public void SnapTo<T>(T preset, float duration)
        {
            SnapTo(preset);
        }

        public void SnapTo<T>(T preset, float duration, bool animate)
        {
            SnapTo(preset);
        }

        public void Rotate(float yaw)
        {
            EnsureCamera();
            if (_camera == null) return;

            _camera.transform.RotateAround(Vector3.zero, Vector3.up, yaw);
            _camera.transform.LookAt(Vector3.zero);
        }

        public void Rotate(float yaw, float pitch)
        {
            EnsureCamera();
            if (_camera == null) return;

            _camera.transform.RotateAround(Vector3.zero, Vector3.up, yaw);

            if (Mathf.Abs(pitch) > 0.001f)
            {
                _camera.transform.RotateAround(Vector3.zero, _camera.transform.right, pitch);
            }

            _camera.transform.LookAt(Vector3.zero);
        }

        public void Zoom(float amount)
        {
            EnsureCamera();
            if (_camera == null) return;

            if (_camera.orthographic)
            {
                _camera.orthographicSize = Mathf.Clamp(_camera.orthographicSize - amount, 24f, 66f);
            }
            else
            {
                _camera.transform.position += _camera.transform.forward * amount;
                _camera.transform.LookAt(Vector3.zero);
            }
        }

        public void Pan(float right, float forward)
        {
            EnsureCamera();
            if (_camera == null) return;

            Vector3 r = _camera.transform.right;
            r.y = 0f;
            r.Normalize();

            Vector3 f = Vector3.Cross(r, Vector3.up).normalized;
            _camera.transform.position += r * right + f * forward;
        }

        public Camera GetCamera()
        {
            EnsureCamera();
            return _camera;
        }

        private void EnsureCamera()
        {
            if (_camera != null) return;

            _camera = Camera.main;

#if UNITY_2023_1_OR_NEWER
            if (_camera == null) _camera = Object.FindAnyObjectByType<Camera>();
#else
            if (_camera == null) _camera = Object.FindObjectOfType<Camera>();
#endif
        }
    }
}
