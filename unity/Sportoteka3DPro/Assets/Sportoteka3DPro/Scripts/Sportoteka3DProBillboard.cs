using UnityEngine;

namespace Sportoteka3DPro
{
    public sealed class Sportoteka3DProBillboard : MonoBehaviour
    {
        private void LateUpdate()
        {
            if (Camera.main == null) return;
            transform.rotation = Quaternion.LookRotation(transform.position - Camera.main.transform.position);
        }
    }
}
