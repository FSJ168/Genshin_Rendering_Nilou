using System.Collections;
using System.Collections.Generic;
using UnityEditor.Rendering;
using UnityEngine;
using UnityEngine.UI;

public class Ripple : MonoBehaviour
{
    public Camera mainCamera;
    public RenderTexture DrawRT;
    public RenderTexture tempRT;
    public Shader DarwShader;
    
    private Material  drawMat;
    public int TextureSize=512;

    // Start is called before the first frame update
    void Start()
    {
        mainCamera=Camera.main.GetComponent<Camera>();
        DrawRT=CreateRT();
        tempRT=CreateRT();
        drawMat=new Material(DarwShader);
        GetComponent<Renderer>().material.mainTexture=DrawRT;
    }

    public RenderTexture CreateRT()
    {
        RenderTexture rt=new RenderTexture(TextureSize,TextureSize,0,RenderTextureFormat.RFloat);
        rt.Create();
        return rt;
    }

/// <summary>
    /// 在指定纹理坐标位置绘制波纹
    /// </summary>
    /// <param name="x">纹理坐标X</param>
    /// <param name="y">纹理坐标Y</param>
    /// <param name="radius">波纹半径</param>
    private void DrawAt(float x,float y,float radius)
    {
        drawMat.SetTexture("_SourceTex",DrawRT);
        drawMat.SetVector("_Pos",new Vector4(x,y,radius));
        Debug.Log(new Vector4(x,y,radius));
        Graphics.Blit(null,tempRT,drawMat);
        RenderTexture rt=tempRT;
        tempRT=DrawRT;
        DrawRT=rt;
    }
    // Update is called once per frame
    void Update()
    {
        if (Input.GetMouseButton(0))
        {
            Ray ray=mainCamera.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;
            if(Physics.Raycast(ray,out hit))
            {
                DrawAt(hit.textureCoord.x,hit.textureCoord.y,0.1f);
            }

        }
    }
}
