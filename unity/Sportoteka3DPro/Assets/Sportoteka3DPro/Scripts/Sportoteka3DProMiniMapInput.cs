using System;
using UnityEngine;
using UnityEngine.EventSystems;

namespace Sportoteka3DPro
{
    public sealed class Sportoteka3DProMiniMapInput : MonoBehaviour, IPointerClickHandler
    {
        public RectTransform target;
        public Action<Vector2> onMapClick;

        public void OnPointerClick(PointerEventData eventData)
        {
            var rt = target != null ? target : transform as RectTransform;
            if (rt == null) return;

            Vector2 local;
            if (!RectTransformUtility.ScreenPointToLocalPointInRectangle(rt, eventData.position, eventData.pressEventCamera, out local)) return;

            Rect rect = rt.rect;
            if (Mathf.Abs(rect.width) < 0.01f || Mathf.Abs(rect.height) < 0.01f) return;

            float nx = Mathf.InverseLerp(rect.xMin, rect.xMax, local.x);
            float ny = Mathf.InverseLerp(rect.yMin, rect.yMax, local.y);
            onMapClick?.Invoke(new Vector2(Mathf.Clamp01(nx), Mathf.Clamp01(ny)));
        }
    }
}
