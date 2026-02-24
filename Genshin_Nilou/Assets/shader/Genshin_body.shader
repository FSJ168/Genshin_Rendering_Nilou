Shader "GenshinToon/Body"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map", 2D) = "white" {}
        _LightMap("Light Map", 2D)="white"{}
        [Toggle(_USE_LIGHTMAP_AO)]_UseLightMapAO("Use LightMap Ao",Range(0,1))=1 //AO开关
        _RampTex("Ramp Tex",2D)="white"{}
        [Toggle(_USE_RAMP_SHADOW)]_UseRampShadow("Use Ramp Shadow",Range(0,1))=1
        _ShadowRampWidth("Shadow Ramp width",Float)=1 //阴影边缘宽度
        _ShadowPosition("Shadow Position",Float)=0.55 //阴影位置
        _ShadowSoftness("Shadow Softness",Float)=0.5 //阴影柔和度

        [Toggle]_UseRampShadow2("Use Ramp Shadow 2",Range(0,1))=1//使用第二行Ramp阴影开关
        [Toggle]_UseRampShadow3("Use Ramp Shadow 3",Range(0,1))=1//使用第三行Ramp阴影开关
        [Toggle]_UseRampShadow4("Use Ramp Shadow 4",Range(0,1))=1//使用第四行Ramp阴影开关
        [Toggle]_UseRampShadow5("Use Ramp Shadow 5",Range(0,1))=1//使用第五行Ramp阴影开关
    
        [Header(Light Options)]
        _DayOrNight("Day Or Night",Range(0,1))=0//日夜阴影交换
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

        #pragma shader_feature_local _USE_LIGHTMAP_AO //AO开关
        #pragma shader_feature_local _USE_RAMP_SHADOW //色阶阴影开关
        // 引入URP核心库
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"


        // 材质属性缓存（仅保留核心参数，避开自动采样器）
        CBUFFER_START(UnityPerMaterial)
           TEXTURE2D(_BaseMap);     // 纹理变量
           SAMPLER(sampler_BaseMap);// 采样器（命名规则：sampler_+纹理名）
           float4 _BaseMap_ST;
           sampler2D _LightMap;

           //ramp shadow

           sampler2D _RampTex;
           float _ShadowRampWidth;
           float _ShadowPosition;
           float _ShadowSoftness;
           float _UseRampShadow2;
           float _UseRampShadow3;
           float _UseRampShadow4;
           float _UseRampShadow5;

           //lighting options
           float _DayOrNight;

        CBUFFER_END


         // 顶点输入结构体
            struct UniversalAttributes
            {
                float4 positionOS : POSITION; // 对象空间位置
                float2 uv0        : TEXCOORD0;// 原始UV
                float2 uv1:TEXCOORD1;
                float3 normalOS : NORMAL;
                float4 color:COLOR0;//顶点颜色
            };

            // 顶点输出结构体
            struct UniversalVaryings
            {
                float4 positionCS : SV_POSITION; // 裁剪空间位置
                float2 uv0        : TEXCOORD0;   // 处理后的UV
                float3 normalWS : TEXCOORD1;
                float4 color:TEXCOORD2;//顶点颜色
            };

            float RampShadowID(float input,float useshadow2,float useShadow3,float useShadow4,float useShadow5,float shadowValue1,float shadowValue2,float shadowValue3,float shadowValue4,float shadowValue5){
                //根据input值将模型分为5个区域
                float v1=step(0.6,input)*step(input,0.8);//0.6-0.8区域
                float v2=step(0.4,input)*step(input,0.6);//0.4-0.6区域
                float v3=step(0.2,input)*step(input,0.4);//0.2-0.4区域
                float v4=step(input,0.2);//0-0.2区域

                //根据开关控制是否使用不同材质的值
                float blend12=lerp(shadowValue1,shadowValue2,useshadow2);
                float blend15=lerp(shadowValue1,shadowValue5,useShadow5);
                float blend13=lerp(shadowValue1,shadowValue3,useShadow3);
                float blend14=lerp(shadowValue1,shadowValue4,useShadow4);

                float result=blend12;//默认使用材质1或2
                result=lerp(result,blend15,v1);//0.6-0.8区域使用材质5
                result=lerp(result,blend13,v2);//0.4-0.6区域使用材质3
                result=lerp(result,blend14,v3);//0.2-0.4区域使用材质4
                result=lerp(result,shadowValue1,v4);//0-0.2区域使用材质1

                return result;
            }

            // 顶点着色器：处理位置和UV
            UniversalVaryings MainVS(UniversalAttributes input)
            {
                UniversalVaryings output;
                
                // 1. 位置转换（URP标准化写法）
                VertexPositionInputs posInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = posInput.positionCS;
                VertexNormalInputs vertexNormalInputs=GetVertexNormalInputs(input.normalOS);

                output.normalWS=vertexNormalInputs.normalWS;
                // 2. UV处理（应用缩放/偏移，核心逻辑）
                output.uv0 = input.uv0 * _BaseMap_ST.xy + _BaseMap_ST.zw;
                // 等价于 TRANSFORM_TEX(input.uv0, _BaseMap)，手动展开避免宏问题

                output.color=input.color;//传递顶点颜色

                return output;
            }

            // 片元着色器：通用纹理采样（避开URP宏）
            half4 MainFS(UniversalVaryings input) : SV_TARGET
            {
                Light light=GetMainLight();
                half4 vertexColor=input.color;
                half3 N=normalize(input.normalWS);
                half3 L=normalize(light.direction);
                half NoL=dot(N,L);
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv0);
                half4 lightMap=tex2D(_LightMap,input.uv0);

                //lambert
                half lambert=NoL;//兰伯特光照（-1，1）
                half halfLambert=lambert*0.5+0.5;//半兰伯特光照（0，1）
                halfLambert+=pow(halfLambert,2);
                half lambertstep=smoothstep(0.01,0.4,halfLambert);//在[0.01-0.4]范围内进行平滑插值
                half shadowFactor=lerp(0,halfLambert,lambertstep);//计算阴影因子

                #if _USE_LIGHTMAP_AO
                    half ambient=lightMap.g;
                #else
                    half ambient=halfLambert;
                #endif

                half shadow=(ambient+halfLambert)*0.5;
                // shadow=0.95<=ambient?1:shadow;
                // shadow=ambient<=0.05?0:shadow;
                shadow=lerp(shadow,1,step(0.95,ambient)); //数学运算适合GPU
                shadow=lerp(shadow,0,step(ambient,0.05));
                half isShadowArea=step(shadow,_ShadowPosition);//判断是否处于阴影区域
                half shadowDepth=saturate(_ShadowPosition-shadow)/_ShadowPosition;//阴影深度
                //根据阴影柔和度调整阴影深度
                shadowDepth=pow(shadowDepth,_ShadowSoftness);
                //限制阴影深度不超过一
                shadowDepth=min(shadowDepth,1);
                half rampwidthFactor=vertexColor.g*2*_ShadowRampWidth;//使用顶点颜色G通道控制Ramp宽度
                half shadowPosition=(_ShadowPosition-shadowFactor)/_ShadowPosition;//带入阴影因子计算阴影位置

                //Ramp
                //计算Ramp图采样U坐标
                half rampU=1-saturate(shadowDepth/rampwidthFactor);
                half rampID=RampShadowID(lightMap.a,_UseRampShadow2,_UseRampShadow3,_UseRampShadow4,_UseRampShadow5,1,2,3,4,5);//根据lightMap的alpha通道计算ramp行

                //根据rampID计算V坐标
                half rampV=0.45-(rampID-1)*0.1;
                half2 rampDayUV=half2(rampU,rampV+0.5);//构建ramp的白天UV坐标
                half2 rampNightUV=half2(rampU,rampV);

                half3 rampDayColor=tex2D(_RampTex,rampDayUV).rgb;
                half3 rampNightColor=tex2D(_RampTex,rampNightUV).rgb;
                half3 rampColor=lerp(rampDayColor,rampNightColor,_DayOrNight);//根据参数选择阴影颜色
                
                //Merge Color
                #if _USE_RAMP_SHADOW
                    half3 finalColor=baseColor*rampColor*(isShadowArea?1:1.2);
                #else
                    half3 finalColor=baseColor*halfLambert*(shadow+0.2);//采用Lambert
                #endif
                // 返回纹理颜色（Alpha强制为1，避免透明问题）
                return half4(finalColor.rgb, 1.0);
                // return half4(vertexColor.ggg,1);
                
            }
            
        ENDHLSL

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back

            HLSLPROGRAM
            #pragma vertex MainVS
            #pragma fragment MainFS

           
            ENDHLSL
        }

        Pass //背面渲染
        {
            Name "UniversalForward"
            Tags { "LightMode" = "SRPDefaultUnlit"
            "Queue"="Geometry+1"//确保在正面之后渲染
            }

            Cull Front

            HLSLPROGRAM

            #pragma vertex BackMainVS
            #pragma fragment MainFS

            UniversalVaryings BackMainVS(UniversalAttributes input){
                UniversalVaryings output=MainVS(input);
                output.uv0=input.uv1;//将uv0换成uv1
                output.normalWS=-output.normalWS;
                return output;
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