using UnityEngine;

namespace Sportoteka3DPro
{
    public static class Sportoteka3DProCameraRig
    {
        public static Camera EnsureCamera()
        {
            Camera camera = Camera.main;
            if (camera == null)
            {
                var cameraObject = new GameObject("Main Camera");
                cameraObject.tag = "MainCamera";
                camera = cameraObject.AddComponent<Camera>();
                cameraObject.AddComponent<AudioListener>();
            }
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.03f, 0.06f, 0.12f);
            camera.fieldOfView = 40f;
            camera.nearClipPlane = 0.1f;
            camera.farClipPlane = 800f;

            var controller = camera.GetComponent<Sportoteka3DProCameraController>();
            if (controller == null) controller = camera.gameObject.AddComponent<Sportoteka3DProCameraController>();
            return camera;
        }

        public static void ApplyPreset(Sportoteka3DProCamera sceneCamera)
        {
            Camera camera = EnsureCamera();
            string preset = sceneCamera?.preset?.ToLowerInvariant() ?? "top";

            var directController = camera.GetComponent<Sportoteka3DProCameraController>();
            if (directController == null) directController = camera.gameObject.AddComponent<Sportoteka3DProCameraController>();
            if (preset == "top" || preset == "2d" || preset == "сверху")
            {
                directController.SnapTo("top");
                return;
            }
            if (preset == "tactical" || preset == "3d" || preset == "тактика")
            {
                directController.SnapTo("tactical");
                return;
            }

            Vector3 position;
            Vector3 target;
            float fov;

            switch (preset)
            {
                case "top":
                case "сверху":
                    position = new Vector3(0f, 92f, 0.1f);
                    target = Vector3.zero;
                    fov = 46f;
                    break;
                case "tactical":
                case "тактика":
                    position = new Vector3(0f, 56f, -42f);
                    target = new Vector3(0f, 0f, 0f);
                    fov = 42f;
                    break;
                case "tv":
                    position = new Vector3(-58f, 26f, -8f);
                    target = new Vector3(0f, 0f, 0f);
                    fov = 34f;
                    break;
                case "diagonal":
                case "диагональ":
                    position = new Vector3(-42f, 28f, -44f);
                    target = new Vector3(3f, 0f, 0f);
                    fov = 38f;
                    break;
                default:
                    position = new Vector3(-38f, 24f, -34f);
                    target = new Vector3(0f, 0f, 0f);
                    fov = 37f;
                    break;
            }

            if (sceneCamera != null && (Mathf.Abs(sceneCamera.y) > 0.01f || Mathf.Abs(sceneCamera.x) > 0.01f || Mathf.Abs(sceneCamera.z) > 0.01f))
            {
                position = new Vector3(sceneCamera.x, sceneCamera.y, sceneCamera.z);
                target = new Vector3(sceneCamera.targetX, sceneCamera.targetY, sceneCamera.targetZ);
                if (sceneCamera.fov > 1f) fov = sceneCamera.fov;
            }

            var controller = camera.GetComponent<Sportoteka3DProCameraController>();
            if (controller == null) controller = camera.gameObject.AddComponent<Sportoteka3DProCameraController>();
            camera.orthographic = false;
            controller.SnapTo(position, target, fov);
        }
    }
}
