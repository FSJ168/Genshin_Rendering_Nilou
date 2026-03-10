using System.Collections;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using UnityEngine;

[ExecuteInEditMode]
public class SmoothNrormal : MonoBehaviour
{

    private SkinnedMeshRenderer[] _skinnedMeshRenderers;
    private MeshFilter[] _MeshFilters;

    private struct WeightedNormal
    {
        public Vector3 normal;
    }
    // Start is called before the first frame update
    void Start()
    {
        _skinnedMeshRenderers=GetComponentsInChildren<SkinnedMeshRenderer>();
        _MeshFilters=GetComponentsInChildren<MeshFilter>();

        foreach(var SkinnedMeshRenderer in _skinnedMeshRenderers)
        {
            SmoothNormal(SkinnedMeshRenderer.sharedMesh);

        }
        foreach(var MeshFliter in _MeshFilters)
        {
            SmoothNormal(MeshFliter.sharedMesh);//采用sharedMesh直接修改物体网格
        }
    }

    private void SmoothNormal(Mesh mesh)
    {
        var normalDict=new Dictionary<Vector3,List<Vector3>>();//字典：Key=顶点位置，Value=该位置下所有顶点的原始法线列表
        var triangles=mesh.triangles; //网格的三角形索引数组，每三个值对应一个三角形的三个顶点索引
        var vertices=mesh.vertices; //网格的顶点位置数组
        var normals=mesh.normals; //网格的原始法线
        var tangents=mesh.tangents; //网格的切线数组
        var SmoothNormals=mesh.normals; //用于储存计算后的平滑法线

        var n=triangles.Length/3; //计算网格中有多少个三角形
        for(var i = 0; i < n; i++)
        {
            
            var vertexIndices=new[] {triangles[i*3],triangles[i*3+1],triangles[i*3+2]};

            for(var j = 0; j < 3; j++)
            {
                var vertexIndex=vertexIndices[j]; //顶点索引
                var vertexPosition=vertices[vertexIndex];

                if (!normalDict.ContainsKey(vertexPosition))
                {
                    normalDict.Add(vertexPosition,new List<Vector3>());
                }
                normalDict[vertexPosition].Add(normals[vertexIndex]);
            }
        }
        Vector2[] smoothNormalUV7=new Vector2[vertices.Length];
        for(var index = 0; index < vertices.Length; index++)
        {
            var vertex=vertices[index];
            var WeightedNormalList=normalDict[vertex];
            var smoothnormal=Vector3.zero;

            foreach(var WeightedNormal in WeightedNormalList)
            {
                smoothnormal+=WeightedNormal;
            }
            smoothnormal=smoothnormal/WeightedNormalList.Count;
            smoothnormal=smoothnormal.normalized;

            // var normal=normals[index];
            // var tangent=tangents[index];
            // var biTangent=(Vector3.Cross(normal,tangent)*tangent.w).normalized;

            // var tbn=new Matrix4x4(tangent,biTangent,normal,Vector3.zero);
            // Vector3 smoothNormalTS=tbn.transpose.MultiplyVector(smoothnormal).normalized;

            //八面体编码，将3D法线压缩为2DUV
            smoothNormalUV7[index]=EncodeNormalOct(smoothnormal);
        }
        mesh.SetUVs(7,smoothNormalUV7);
        print("写入平滑法线成功");
    }
    private Vector2 EncodeNormalOct(Vector3 normal)
    {
        normal=normal.normalized;
        Vector2 p=new Vector2(normal.x,normal.y)/(Mathf.Abs(normal.x)+Mathf.Abs(normal.y)+Mathf.Abs(normal.z));
        if (normal.z < 0)
        {
            p = new Vector2((1 - Mathf.Abs(p.y)) * Mathf.Sign(p.x), (1 - Mathf.Abs(p.x)) * Mathf.Sign(p.y));

        }
        return p*0.5f+new Vector2(0.5f,0.5f);
    }
}
