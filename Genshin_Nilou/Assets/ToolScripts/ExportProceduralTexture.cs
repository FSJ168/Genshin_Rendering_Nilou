using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.IO;
using UnityEditor;

public class ExportProceduralTexture : MonoBehaviour
{
    public Material proceduraMat;
    public int textureSize=1024;
    public string customSavePath = "Assets/Texture/ComputeTexture/"; 
    public string customFileName = "MyProceduralTexture.png";

    [ContextMenu("Export Texture")]
    public void Export()
    {
        RenderTexture rt=new RenderTexture(textureSize,textureSize,0);
        Graphics.Blit(null,rt,proceduraMat);

        Texture2D tex=new Texture2D(textureSize,textureSize,TextureFormat.RGBA32,false);
        RenderTexture.active=rt;
        tex.ReadPixels(new Rect(0,0,textureSize,textureSize),0,0);
        tex.Apply();
        RenderTexture.active=null;

        //保存为PNG
        byte[] pngData=tex.EncodeToPNG();
        Directory.CreateDirectory(customSavePath);
        string savePath=Path.Combine(customSavePath,customFileName);
        File.WriteAllBytes(savePath,pngData);

        //释放资源
        DestroyImmediate(rt);
        DestroyImmediate(tex);
        Debug.Log("程序化纹理以导出到："+savePath);
        AssetDatabase.Refresh();
    }
}
