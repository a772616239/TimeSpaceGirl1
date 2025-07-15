using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(CanvasRenderer))]
[AddComponentMenu("UI/MeshImage", 100)]
public class MeshImage : MonoBehaviour
{
    [SerializeField]
    Mesh mesh;
    [SerializeField]
    Material material;
    [SerializeField]
    Color color=Color.white;

    Mesh defMesh;

    CanvasRenderer myRender;


    static Vector3[] VexPos = { new Vector3(50, 50), new Vector3(50,-50), new Vector3(-50,50),new Vector3(-50,-50)};
    static Vector2[] uv= { new Vector2(1,1), new Vector2(1, 0), new Vector2(0, 1), new Vector2(0, 0) };
    static int[] triangles = { 0, 1, 2, 1, 2, 3 };

    public MeshImage() { 
        


    }
    // Start is called before the first frame update

    void OnEnable() {
        if (myRender == null)
        {
            myRender = GetComponent<CanvasRenderer>();
        }
        myRender.Clear();
        setRender(myRender);
    }
     
     void OnValidate()
    {
        
        setRender(myRender);
    }
    void Start()
    {
       // setRender();
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    void OnDisable() {
        myRender.Clear();
    }

    void setRender(CanvasRenderer myRender) {
        //CanvasRenderer myRender = GetComponent<CanvasRenderer>();
        myRender.Clear();
        if (mesh==null) {
            myRender.SetMesh(GreatMesh());
        } else
        {
            Vector3[] vexPos_S = mesh.vertices;
            for(int i = 0; i < mesh.vertices.Length; i++)
            {
                vexPos_S[i] *= 100;
            }
            Mesh ls = new Mesh();
            ls.vertices = vexPos_S;
            ls.uv = mesh.uv;
            ls.triangles = mesh.triangles;


            myRender.SetMesh(ls);
        }

        if (material == null) {
            myRender.SetMaterial(Canvas.GetDefaultCanvasMaterial(), Texture2D.whiteTexture); 

        }
        else
        {
            myRender.SetMaterial(material, Texture2D.whiteTexture);

        }
        //    myRender.SetMaterial(material,myTex);
        myRender.SetColor(color);

    }

    Mesh GreatMesh() {
        if (defMesh == null)
        {

            Mesh newMesh = new Mesh();
            newMesh.vertices = VexPos;
            newMesh.triangles = triangles;
            newMesh.uv = uv;
            return newMesh;

        }
        else {
            return defMesh;
        
        }
      
    }

}
