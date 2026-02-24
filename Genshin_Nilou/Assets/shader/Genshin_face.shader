Shader "GenshinToon/Face"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map", 2D) = "white" {}

        [Header(shadow Options)]
        [Toggle(_USE_SDF_SHADOW)]_UseSDFshadow("Use SDF Shadow",Range(0,1))=1//SDF开关
        _SDF("SDF ",2D)="white"{}//距离场纹理
        _ShadowMask("shadow Mask",2D)="white"{}//阴影遮罩
        _ShadowColor("Shadow Color",Color)=(1,0.87,0.87,1)//阴影颜色

        [Header(Head direction)]
        [HideInInspector]_HeadForward("Head Forward", Vector) = (0,0,1,0) // 面部前方
        [HideInInspector]_HeadRight("Head Right", Vector) = (1,0,0,0)     // 面部右侧
        [HideInInspector]_HeadUp("Head UP", Vector) = (0,1,0,0)           // 面部上方
        
        [Header(Face Blush)]
        [Toggle(Use_Face_Blash)]_UseFaceBlash("Use Face Blash",Range(0,1))=1//腮红开关
        _FaceBlashColor("Face Blush Color",Color)=(1,0,0,1)//腮红颜色
        _FaceBlushstrength("Face Blush Strength",Range(0,1))=1//腮红强度
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        HLSLINCLUDE
        // 引入URP核心库
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        // 材质属性缓存（仅保留核心参数，避开自动采样器）
        CBUFFER_START(UnityPerMaterial)
           TEXTURE2D(_BaseMap);     // 纹理变量
           SAMPLER(sampler_BaseMap);// 采样器（命名规则：sampler_+纹理名）
           float4 _BaseMap_ST;

           //shadow Options
           sampler2D _SDF;//距离场纹理
           sampler2D _ShadowMask;//阴影遮罩
           float4 _ShadowColor;//阴影颜色
           //Head Direction
           float3 _HeadForward;
           float3 _HeadRight;
           float3 _HeadUp;

           //Face Blush
           float4 _FaceBlashColor;//腮红颜色
           float _FaceBlushstrength;//腮红强度
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex MainVS
            #pragma fragment MainFS

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile_fragment _ SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _REFLECTION_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION

            #pragma shader_feature_local _USE_SDF_SHADOW//SDF开关

            // 顶点输入结构体
            struct Attributes
            {
                float4 positionOS : POSITION; // 对象空间位置
                float2 uv0        : TEXCOORD0;// 原始UV
                float3 normalOS : NORMAL;
            };

            // 顶点输出结构体
            struct Varyings
            {
                float4 positionCS : SV_POSITION; // 裁剪空间位置
                float2 uv0        : TEXCOORD0;   // 处理后的UV
                float3 normalWS : NORMAL;
            };

            // 顶点着色器：处理位置和UV
            Varyings MainVS(Attributes input)
            {
                Varyings output;
                
                // 1. 位置转换（URP标准化写法）
                VertexPositionInputs posInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = posInput.positionCS;
                VertexNormalInputs vertexNormalInputs=GetVertexNormalInputs(input.normalOS);

                output.normalWS=vertexNormalInputs.normalWS;
                // 2. UV处理（应用缩放/偏移，核心逻辑）
                output.uv0 = input.uv0 * _BaseMap_ST.xy + _BaseMap_ST.zw;
                // 等价于 TRANSFORM_TEX(input.uv0, _BaseMap)，手动展开避免宏问题

                return output;
            }

            // 片元着色器：通用纹理采样（避开URP宏）
            half4 MainFS(Varyings input) : SV_TARGET
            {
                Light light=GetMainLight();

                //Normalize Vector
                half3 N=normalize(input.normalWS);
                half3 L=normalize(light.direction);
                half3 headforwardDir=normalize(_HeadForward);
                half3 headUpDir=normalize(_HeadUp);//上方
                half3 headRightDir=normalize(_HeadRight);//右侧

                //Texture Info
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv0);
                half4 shadowMask=tex2D(_ShadowMask,input.uv0);//采样阴影遮罩

                //Face shadow
                half3 LpU=dot(L,headUpDir)/pow(length(headUpDir),2)*headUpDir;//计算光源方向在面部上方的投影
                half3 LpHeaderHorizon=normalize(L-LpU);//光源方向在头部水平面上的投影
                half value=acos(dot(LpHeaderHorizon,headRightDir))/3.141592654;//计算光源方向与面部右方的夹角
                half exposeRight=step(value,0.5);//判断光照是来自左侧还是右侧
                half valueR=pow(1-value*2,3);//右侧阴影强度
                half valueL=pow(value*2-1,3);//左侧阴影强度
                half mixValue=lerp(valueL,valueR,exposeRight);//混合阴影强度
                half sdfLeft=tex2D(_SDF,half2(1-input.uv0.x,input.uv0.y)).r;//左侧距离场
                half sdfRight=tex2D(_SDF,input.uv0).r;//右侧距离场
                half mixSdf=lerp(sdfRight,sdfLeft,exposeRight);//采样SDF纹理
                half sdf=step(mixValue,mixSdf);//计算应硬边界阴影
                sdf=lerp(0,sdf,step(0,dot(LpHeaderHorizon,headforwardDir)));//计算右侧阴影
                sdf*=shadowMask.g;
                sdf=lerp(sdf,1,shadowMask.a);//使用a通道作为阴影遮罩


                half NoL=dot(N,L);
                half lambert=NoL;
                half halfLambert=lambert*0.5+0.5;

                //Face Blush
                half blushStrength=lerp(0,baseColor.a,_FaceBlushstrength);//根据BaseMap的alpha通道计算腮红强度

                //Merge Color
                #if _USE_SDF_SHADOW
                half3 finalColor=lerp(_ShadowColor.rgb*baseColor.rgb,baseColor.rgb,sdf);//合并最终颜色
                #else
                half3 finalColor=baseColor.rgb*halfLambert;
                #endif

                finalColor=lerp(finalColor,finalColor*_FaceBlashColor.rgb,blushStrength);//合并腮红颜色

                // 返回纹理颜色（Alpha强制为1，避免透明问题）
                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }

        Pass{
            Name"ShadowShader"
            Tags{
                "LightMode"="ShadowCaster"//光照模式，阴影投射

            }

            ZWrite On//写入深度缓存区
            ZTest LEqual//深度测试，小于等于
            ColorMask 0//不写入颜色缓存区
            Cull Off//不裁剪

            HLSLPROGRAM

            #pragma multi_compile_instancing // 启用GPU实例化编译
            #pragma multi_compile _ DOTS_INSTANCING_ON // 启用DOTS实例化编译
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW // 启用点光源阴影
            #pragma vertex ShadowVS//声明顶点着色器
            #pragma fragment ShadowFS

            struct Attributes{
                float4 positionOS:POSITION;
                float3 normalOS:NORMAL;
                float4 uv0:TEXCOORD0;
            };

            struct Varyings{
                float4 positionCS:SV_POSITION;
                float2 uv0:TEXCOORD0;
            };

            //自动赋值
            float3 _LightDirection;//光源方向
            float3 _LightPosition;//光源位置

            //将阴影的世界空间顶点位置转换为适合投射阴影的裁剪空间位置
            float4 GetShadowPositionHClip(Attributes input){
                float3 positionWS=TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS=TransformObjectToWorldNormal(input.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW//点光源
                    float3 lightDirectionWS=normalize(_LightPosition-positionWS);
                #else //平行光
                    float3 lightDirectionWS=_LightDirection;
                #endif

                float4 positionCS=TransformWorldToHClip(ApplyShadowBias(positionWS,normalWS,lightDirectionWS));//应用阴影偏移

                //根据平台Z缓冲区方向调整Z值
                #if UNITY_REVERSED_Z //反转Z缓冲区
                    positionCS.z=min(positionCS.z,UNITY_NEAR_CLIP_VALUE);//限制Z值在近裁剪平面以下
                #else //正向Z缓冲区
                    positionCS.z=max(positionCS.z,UNITY_NEAR_CLIP_VALUE);//限制Z值在远裁剪平面以上
                #endif

                return positionCS;//返回裁剪空间坐标
            }

            Varyings ShadowVS(Attributes input){
                Varyings output;
                output.positionCS=GetShadowPositionHClip(input);
                return output;

            }
            half4 ShadowFS(Varyings input):SV_TARGET{
                return 0;
            }
            ENDHLSL
        }
    }

    // URP强制回退Shader
    //FallBack "Hidden/Universal Render Pipeline/FallbackError"
}