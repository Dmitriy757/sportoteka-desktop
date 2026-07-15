
using UnityEngine;

namespace Sportoteka3DPro
{
    public sealed class Sportoteka3DProDesktopHud : MonoBehaviour
    {
        private static Sportoteka3DProEditorController _controller;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void Bootstrap()
        {
#if UNITY_STANDALONE || UNITY_EDITOR
            if (_controller != null) return;

            var root = GameObject.Find("Sportoteka 3D Pro Professional Editor V4");
            if (root == null)
            {
                root = new GameObject("Sportoteka 3D Pro Professional Editor V4");
                Object.DontDestroyOnLoad(root);
            }

            _controller = root.GetComponent<Sportoteka3DProEditorController>();
            if (_controller == null)
            {
                _controller = root.AddComponent<Sportoteka3DProEditorController>();
            }
#endif
        }
    }
}
