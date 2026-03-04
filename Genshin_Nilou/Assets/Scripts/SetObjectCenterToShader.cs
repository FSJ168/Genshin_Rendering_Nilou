using UnityEngine;
// 新增：引入Dictionary所需的命名空间
using System.Collections.Generic;


public class SetObjectCenterToShader : MonoBehaviour
{
    // 存储所有蒙皮网格渲染器（带动画的模型）
    private SkinnedMeshRenderer[] _skinnedMeshRenderers;
    // 存储所有普通网格渲染器（静态模型）
    private MeshRenderer[] _meshRenderers;
    // 存储每个渲染器对应的材质实例（避免修改共享材质）
    private Dictionary<Renderer, Material> _materialInstances = new Dictionary<Renderer, Material>();

    // 物体上一帧的位置，用于判断是否移动
    private Vector3 _lastPosition;
    // 物体上一帧的旋转，用于判断是否旋转（旋转也会影响包围盒）
    private Quaternion _lastRotation;

    void Start()
    {
        // 获取所有子物体的蒙皮网格渲染器和普通网格渲染器（包含禁用的子物体）
        _skinnedMeshRenderers = GetComponentsInChildren<SkinnedMeshRenderer>(true);
        _meshRenderers = GetComponentsInChildren<MeshRenderer>(true);

        // 初始化蒙皮网格的材质实例
        foreach (var skinnedRenderer in _skinnedMeshRenderers)
        {
            if (skinnedRenderer.sharedMaterial != null)
            {
                Material instance = new Material(skinnedRenderer.sharedMaterial);
                skinnedRenderer.material = instance;
                _materialInstances.Add(skinnedRenderer, instance);
            }
        }

        // 初始化普通网格的材质实例
        foreach (var meshRenderer in _meshRenderers)
        {
            if (meshRenderer.sharedMaterial != null)
            {
                Material instance = new Material(meshRenderer.sharedMaterial);
                meshRenderer.material = instance;
                _materialInstances.Add(meshRenderer, instance);
            }
        }

        // 记录初始位置/旋转
        _lastPosition = transform.position;
        _lastRotation = transform.rotation;

        // 初始化物体中心
        UpdateObjectCenter();
    }

    void Update()
    {
        // 仅当物体位置/旋转变化时更新（优化性能，避免每一帧计算）
        if (transform.position != _lastPosition || transform.rotation != _lastRotation)
        {
            UpdateObjectCenter();
            _lastPosition = transform.position;
            _lastRotation = transform.rotation;
        }
    }

    void OnDestroy()
    {
        // 销毁所有材质实例，避免内存泄漏
        foreach (var pair in _materialInstances)
        {
            if (pair.Value != null)
            {
                Destroy(pair.Value);
            }
        }
        _materialInstances.Clear();
    }

    void UpdateObjectCenter()
    {
        // 计算所有渲染器的合并包围盒（最准确的整体中心）
        Bounds totalBounds = new Bounds(transform.position, Vector3.zero);

        // 合并蒙皮网格的包围盒（修复：替换isActiveAndEnabled为正确的激活判断）
        foreach (var skinnedRenderer in _skinnedMeshRenderers)
        {
            // 判断渲染器是否启用，且所在物体在层级中激活
            if (skinnedRenderer.enabled && skinnedRenderer.gameObject.activeInHierarchy)
            {
                totalBounds.Encapsulate(skinnedRenderer.bounds);
            }
        }

        // 合并普通网格的包围盒（修复：替换isActiveAndEnabled为正确的激活判断）
        foreach (var meshRenderer in _meshRenderers)
        {
            // 判断渲染器是否启用，且所在物体在层级中激活
            if (meshRenderer.enabled && meshRenderer.gameObject.activeInHierarchy)
            {
                totalBounds.Encapsulate(meshRenderer.bounds);
            }
        }

        // 获取整体中心（世界空间）
        Vector3 objectCenterWS = totalBounds.center;

        // 将中心坐标传递给所有材质实例的Shader
        foreach (var pair in _materialInstances)
        {
            if (pair.Value != null)
            {
                pair.Value.SetVector("_ObjectCenterWS", new Vector4(objectCenterWS.x, objectCenterWS.y, objectCenterWS.z, 1));
            }
        }
    }
}