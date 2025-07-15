using UnityEngine;
using UnityEngine.UI;

[ExecuteInEditMode]
public class SortLayer : MonoBehaviour
{
    // Fields
    private int _lastOrder;
    public bool IsUI=true;
    public bool IsSetAllChild = false;
    public int LayerOrder;
    private bool isAddCanvas = false;

    // Methods
    public void ResetSortLayer(int iorder)
    {
        this.LayerOrder = iorder;
        this._lastOrder = this.LayerOrder;
        if (IsUI)
        {
            if (base.transform.gameObject.GetComponent<Canvas>() == null)
            {
                Canvas canvas = gameObject.AddComponent<Canvas>();
                canvas.overrideSorting = true;
                canvas.sortingOrder = this.LayerOrder;
                gameObject.AddComponent<GraphicRaycaster>();
                isAddCanvas = true;
            }
            else
            {
                if (!IsSetAllChild)
                    base.transform.gameObject.GetComponent<Canvas>().sortingOrder = this.LayerOrder;
                else
                {
                    var canvases = base.transform.gameObject.GetComponentsInChildren<Canvas>();
                    foreach (var canvas in canvases)
                        canvas.sortingOrder = this.LayerOrder;
                }
            }
        }
        else
        {
            if (isAddCanvas)
            {
                var canvas = gameObject.GetComponent<Canvas>();
                if (canvas != null)
                    Destroy(canvas);
                var rayCanvas = gameObject.GetComponent<GraphicRaycaster>();
                if (rayCanvas != null)
                    Destroy(rayCanvas);
            }
            if (!IsSetAllChild)
            {
                var render = base.gameObject.GetComponent<Renderer>();
                if (render != null)
                    render.sortingOrder = this.LayerOrder;
            }
            else
            {
                var renders = base.gameObject.GetComponentsInChildren<Renderer>();
                if (renders != null && renders.Length > 0)
                {
                    for (int i = 0; i < renders.Length; i++)
                    {
                        if (renders[i] != null)
                            renders[i].sortingOrder = this.LayerOrder;  
                    }
                }
            }
        }
    }

    private void Start()
    {
        this.ResetSortLayer(this.LayerOrder);
    }

    private void Update()
    {
        if (this.LayerOrder != this._lastOrder)
        {
            this.ResetSortLayer(this.LayerOrder);
        }
    }
}



