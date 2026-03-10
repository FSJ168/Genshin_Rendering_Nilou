using UnityEngine;
using System.Collections;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;



public class InteractiveWaterRenderPassFeature : ScriptableRendererFeature
{

    [System.Serializable]
    public class Settings
    {
        //标记涟漪触发位置（对应TriggerRT.shader）
        public Material TriggerInputMat;
        //涟漪传播材质（对应Rapple.shader）
        public Material WaterTransmitMat;
        //渲染水面并应用涟漪
        public Material WaterMaterial;
        //生成涟漪法线
        public Material NormalGeneratorMaterial;

        //触发涟漪交互纹理
       public RenderTexture InteractiveRT;

    
        //鼠标触发
        public bool isPointerInteractive = false;
        
        


        [Range(0, 1.0f)]
        //触发半径
        public float drawRadius = 0.1f;
        [Range(0, 1.0f)]
        //衰减系数
        public float waveAttenuation = 0.99f;

        [Range(0, 1.0f)]
        //传播速度
        public float WaveSpeed = 0.5f;
        [Range(0, 1.0f)]

        //粘度，越大消失越快
        public float WaveViscosity = 0.15f; 
        //最大高度
        public float WaveHeight = 0.999f;

        //不透明物体渲染之后执行
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
        //RenderTexture分辨率
        public int RenderTextureSize = 128;
     

    }

    
    public Settings setting = new Settings();


    class WaterRenderPass : ScriptableRenderPass
    {

        public Settings setting;
        //渲染标签
        public ShaderTagId shaderTag = new ShaderTagId("UniversalForward");
        //指定渲染队列范围
        public FilteringSettings filteringSetting;
        //上一帧高度状态
        RenderTexture prevRT;
        RenderTexture currentRT;
        //临时RT
        RenderTexture tempRT;
        //涟漪法线
        RenderTexture normalRT;

        private Material WaterTransmitMaterial;
        private Vector4 WaterTransmitParams;
        private Vector4 WaterMarkParams;
 
        //采样计数器
        //private int m_sampleCounter;

        private void InitRT()
        {
            currentRT = new RenderTexture(setting.RenderTextureSize, setting.RenderTextureSize, 0, RenderTextureFormat.Default);
            prevRT = new RenderTexture(setting.RenderTextureSize, setting.RenderTextureSize, 0, RenderTextureFormat.Default);
            tempRT = new RenderTexture(setting.RenderTextureSize, setting.RenderTextureSize, 0, RenderTextureFormat.Default);
            normalRT = new RenderTexture(setting.RenderTextureSize, setting.RenderTextureSize, 0, RenderTextureFormat.Default);
           

        }

        private void ExchangeRT(ref RenderTexture a, ref RenderTexture b)
        {

            RenderTexture rt = a;
            a = b;
            b = rt;
        }
        //波动方程
        void InitWaveTransmitParams()
        {
            //像素步长为1
            float uvStep = 1.0f / setting.RenderTextureSize;
            float dt = Time.fixedDeltaTime;
            //考虑粘度的最大波速
            float maxWaveStepVisosity = uvStep / (2 * dt) * (Mathf.Sqrt(setting.WaveViscosity * dt + 2));
            //粘度平方
            float waveVisositySqr = setting.WaveViscosity * setting.WaveViscosity;
            //通过控制WaveSpeed来控制波速
            float curWaveSpeed = maxWaveStepVisosity * setting.WaveSpeed;
            float ut = setting.WaveViscosity * dt;

            float f1 = curWaveSpeed * curWaveSpeed * dt * dt / (uvStep * uvStep);
            float f2 = 1.0f / (ut + 2);
            
            float k1 = (4.0f - 8.0f * f1) * f2;
            float k2 = (ut - 2) * f2;
            float k3 = 2.0f * f1 * f2;
            //Znew=K1xZcur+K2xZprev+K3x(Zup+Zdown+Zleft+Zright)
            WaterTransmitParams.Set(k1, k2, k3, uvStep);

        }


        public WaterRenderPass(Settings setting)
        {
            this.setting = setting;
            //创建渲染队列范围
            RenderQueueRange queue = new RenderQueueRange();
            filteringSetting = new FilteringSettings(queue);
            //将drawRadius传递给CameraRayCast
            CameraRayCast.drawRadius = setting.drawRadius;
   
            InitRT();
            InitWaveTransmitParams();

            // m_sampleCounter = setting.sampleTextureCount;

        }
        //渲染之前计算涟漪
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {


            
            if (setting.TriggerInputMat != null && setting.WaterTransmitMat != null)
            {
              
                if (setting.isPointerInteractive == true && CameraRayCast.isRayCast == true)
                {
                    setting.TriggerInputMat.SetVector("_HitPoint", CameraRayCast.currentPos);
                    setting.TriggerInputMat.SetFloat("_isRenderMousePointer", setting.isPointerInteractive == true ? 1 : 0);
                    if (setting.InteractiveRT != null)
                    {
                        setting.TriggerInputMat.SetTexture("_InteractiveTex", setting.InteractiveRT);
                    }
                  
                    setting.TriggerInputMat.SetTexture("_CurrentRT", currentRT);
                    //触发执行涟漪shader，绘制给tempRT
                    cmd.Blit(null, tempRT, setting.TriggerInputMat);
                    ExchangeRT(ref tempRT, ref currentRT);
                   
                }
                
                else
                {
                    setting.TriggerInputMat.SetVector("_HitPoint",new Vector4(0,0,0,0));
                    if (setting.InteractiveRT != null)
                    {
                        setting.TriggerInputMat.SetTexture("_InteractiveTex", setting.InteractiveRT);
                    }
                    
                    setting.TriggerInputMat.SetTexture("_CurrentRT", currentRT);
                 
                    cmd.Blit(null, tempRT, setting.TriggerInputMat);
                    ExchangeRT(ref tempRT, ref currentRT);
                }

                


                   // 传入上一帧RT
                setting.WaterTransmitMat.SetVector("_WaterTransmitParams", WaterTransmitParams);
                setting.WaterTransmitMat.SetTexture("_PrevRT", prevRT);
                setting.WaterTransmitMat.SetTexture("_CurrentRT", currentRT);
                setting.WaterTransmitMat.SetFloat("_Attenuation", setting.waveAttenuation);
                
                setting.NormalGeneratorMaterial.SetTexture("_CurrentRT", currentRT);
                cmd.Blit(null, normalRT, setting.NormalGeneratorMaterial);
                //将法线纹理传给水面渲染材质
                setting.WaterMaterial.SetTexture("_NormalRT", normalRT);

                cmd.Blit(null, tempRT, setting.WaterTransmitMat);
                cmd.Blit(tempRT, prevRT);
                //更新涟漪状态
                ExchangeRT(ref prevRT, ref currentRT);
                

            }




        }

        //执行渲染
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {

             if (setting.WaterMaterial != null)
            {
                //指定使用的shader标签和排序方式
                var drawFrame = CreateDrawingSettings(shaderTag, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags);
                setting.WaterMaterial.SetTexture("_NormalRT", normalRT);
                //设置覆盖材质为水面渲染材质
                drawFrame.overrideMaterial = setting.WaterMaterial;
                drawFrame.overrideMaterialPassIndex = 0;
                context.DrawRenderers(renderingData.cullResults, ref drawFrame, ref filteringSetting);
            }
 
        }


        public override void FrameCleanup(CommandBuffer cmd)
        {
            //tempRT.Release();
            
        }
    }

    WaterRenderPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new WaterRenderPass(setting);

        // 配置渲染事件时机
        m_ScriptablePass.renderPassEvent = setting.Event;
    }


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //将RenderPass加入渲染队列
        renderer.EnqueuePass(m_ScriptablePass);
    }
}
