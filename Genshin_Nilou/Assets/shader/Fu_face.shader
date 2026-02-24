Shader "GenshinToon/Fu_Body"
{
    Properties
    {
        [Space(20.0)]
        [Toggle]_genshinShader("是否是脸部",Float)=0.0

        [Space(15.0)]
        [NoScaleOffset]_BaseMap("Diffuse Map",2D)="white"{} //基础贴图
        _fresnel("边缘光范围",Range(0,10))=1.7
        _edgeLight("边缘光强度",Range(0,1))=0.02
        [Space(8.0)]
        _diffuseA("Alpha(1透明,2自发光)",Range(0,2))=0
        _Cutoff("透明阈值",Range(0,1))=1
        [HDR]_glow("自发光强度",color)=(1,1,1,1)
        _flicker("发光闪烁速度",Float)=0.8
        [Space(30)]

        [NoScaleOffset]_LightMap("Light Map",2D)="white"{} //光照贴图
        _Bright("亮面范围",Range(0,1))=0.8 //亮面控制参数
        _Gray("灰面范围",Range(0,1))=0.6 //灰面控制参数
        _Dark("黑面范围",Range(0,1))=0.1 //暗面补偿
        [Space(30)]

        [Header(Bump)]
        [NoScaleOffset]_Normalmap("Normal Map",2D)="bump"{}
        _NormalScale("Normal Scale",Float)=1.0 //法线强度
        [Space(30)]

        [Toggle(_USE_LIGHTMAP_AO)]_UseLightMapAO("Use LightMap Ao",Range(0,1))=1 //Ao开关
        

        //Ramp 阴影设置
        [Header(Ramp)]
        [NoScaleOffset]_RampTex("Ramp Tex",2D)="white"{}
        _DayOrNight("Day Or Night",Range(0,1))=0 //日月阴影交换
        [Toggle(_USE_RAMP_SHADOW)]_UseRampShadow("Use Ramp Shadow",Range(0,1))=1
        [Toggle]_UseRampShadow2("Use Ramp Shadow2",Range(0,1))=1
        [Toggle]_UseRampShadow3("Use Ramp Shadow3",Range(0,1))=1 
        [Toggle]_UseRampShadow4("Use Ramp Shadow4",Range(0,1))=1
        [Toggle]_UseRampShadow5("Use Ramp Shadow5",Range(0,1))=1 
        [Space(8)]
        _lightmapA0("1.0_Ramp条数" , Range(1, 5)) = 1
        _lightmapA1("0.7_Ramp条数" , Range(1, 5)) = 4
        _lightmapA2("0.5_Ramp条数" , Range(1, 5)) = 3
        _lightmapA3("0.3_Ramp条数" , Range(1, 5)) = 5
        _lightmapA4("0.0_Ramp条数" , Range(1, 5)) = 2
        [Space(30)]

        [NoScaleOffset]_metalMap("Metal Map",2D)="white"{}
        _gloss("高光范围",Range(1,256))=1
        _glossStrength("高光强度",Range(0,1))=1
        _metalMapColor("金属反射颜色",color)=(1,1,1,1)
        [Space(30)]

        _outline("描边粗细",Range(0,1))=0.4
        _outlineColor0("描边颜色1",color)=(0,0,0,0)
        _outlineColor2("描边颜色2",color)=(0,0,0,0)
        _outlineColor3("描边颜色3",color)=(0,0,0,0)
        _outlineColor4("描边颜色4",color)=(0,0,0,0)
        _outlineColor5("描边颜色5",color)=(0,0,0,0)

    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalRenderPipeline" //指定渲染管线为URP
        "RenderType"="Opaque" //指定渲染类型为不透明
        "Queue"="Geometry"  //指定渲染队列，Geometry(不透明物体通常在这个队列)
        }

    HLSLINCLUDE //公共代码起始块

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


        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"        //Unity核心库（必需）
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"    //Unity光照库（必需）

        CBUFFER_START(UnityPerMaterial) //常量缓冲区开始
        // ===== 基础开关/通用属性 =====
            float _genshinShader;          // 是否是脸部
            float _UseLightMapAO;          // LightMap AO开关
            float _UseRampShadow;          // Ramp阴影总开关

            // ===== 基础贴图相关 =====
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            float4 _BaseMap_ST;

            TEXTURE2D(_LightMap);
            SAMPLER(sampler_LightMap);
            float4 _LightMap_ST;

            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);
            float4 _RampTex_ST;

            TEXTURE2D(_Normalmap);
            SAMPLER(sampler_Normalmap);    // 与Properties命名一致（小写m）
            float4 _Normalmap_ST;

            TEXTURE2D(_metalMap);          // 金属贴图
            SAMPLER(sampler_metalMap);
            float4 _metalMap_ST;

            // ===== 边缘光/透明/自发光 =====
            float _fresnel;                // 边缘光范围
            float _edgeLight;              // 边缘光强度
            float _diffuseA;               // Alpha模式（透明/自发光）
            float _Cutoff;                 // 透明阈值
            float4 _glow;                  // 自发光强度（HDR颜色）
            float _flicker;                // 发光闪烁速度

            // ===== 卡通阴影范围 =====
            float _DayOrNight;             // 日夜阴影交换
            float _Bright;                 // 亮面范围
            float _Gray;                   // 灰面范围
            float _Dark;                   // 黑面范围
            float _NormalScale;            // 法线强度

            // ===== Ramp阴影行选择（替代旧的UseRampShadow2-5）=====
            float _lightmapA0;             // 1.0_Ramp条数
            float _lightmapA1;             // 0.7_Ramp条数
            float _lightmapA2;             // 0.5_Ramp条数
            float _lightmapA3;             // 0.3_Ramp条数
            float _lightmapA4;             // 0.0_Ramp条数

            // ===== 高光/金属 =====
            float _gloss;                  // 高光范围
            float _glossStrength;          // 高光强度
            float4 _metalMapColor;         // 金属反射颜色

            // ===== 描边 =====
            float _outline;                // 描边粗细
            float4 _outlineColor0;         // 描边颜色1
            float4 _outlineColor2;         // 描边颜色2
            float4 _outlineColor3;         // 描边颜色3
            float4 _outlineColor4;         // 描边颜色4
            float4 _outlineColor5;         // 描边颜色5

            // ===== 旧版Ramp阴影开关（保留兼容）=====
            float _UseRampShadow2;
            float _UseRampShadow3;
            float _UseRampShadow4;
            float _UseRampShadow5;
            float _ShadowRampWidth;
            float _ShadowPosition;
            float _ShadowSoftness;

        CBUFFER_END

        float3x3 CalculateTBNMatrix(float3 tangentWS, float3 bitangentWS, float3 normalWS)
        {
            float3x3 tbn;
            tbn[0] = tangentWS;
            tbn[1] = bitangentWS;
            tbn[2] = normalWS;
            return tbn;
        }

        // 通过LightMap.a获取材质ID
        float RampShadowID(float input, float useShadow2, float useShadow3, float useShadow4, float useShadow5,
                            float shadowValue1, float shadowValue2, float shadowValue3, float shadowValue4, float shadowValue5)
        {
        // 根据input值将模型分为5个区域（基于input的灰度值区分）
        float v1 = step(0.6, input) * step(input, 0.8); // 0.6-0.8
        float v2 = step(0.4, input) * step(input, 0.6); // 0.4-0.6
        float v3 = step(0.2, input) * step(input, 0.4); // 0.2-0.4
        float v4 = step(input, 0.2);                    // 0.0-0.2
        // 根据开关控制是否使用不同材质的值
        float blend12   = lerp(shadowValue1, shadowValue2, useShadow2);  //useShadow非零即一，这里做一个lerp也不难理解。
        float blend15   = lerp(shadowValue1, shadowValue5, useShadow5);
        float blend13   = lerp(shadowValue1, shadowValue3, useShadow3);
        float blend14   = lerp(shadowValue1, shadowValue4, useShadow4);
        // 根据区域选择对应的材质值
        float result    = blend12;                      //默认使用材质1或2
        result    = lerp(result, blend15, v1);         // 0.6-0.8区域使用材质5
        result    = lerp(result, blend13, v2);         // 0.4-0.6区域使用材质3
        result    = lerp(result, blend14, v3);         // 0.2-0.4区域使用材质4
        result    = lerp(result, shadowValue1, v4);    // 0-0.2区域使用材质1
        // 返回结果
        return result;
        }

        //Ramp
        float3 RampShadow(float4 lightmap,float NdotL){
            lightmap.g=smoothstep(0.2,0.3,lightmap.g);
            float halfLambert=smoothstep(0.0,_Gray,NdotL+_Dark)*lightmap.g; //半lambert
            float brightMask=step(_Bright,halfLambert);//亮面控制

            //判断白天与夜晚
            float rampSampling=0;
            if(_DayOrNight==0){rampSampling=0.5;}

            //Ramp
            float rampU=halfLambert; //采样ramp图横坐标
            float rampID=RampShadowID(lightmap.a,_UseRampShadow2,_UseRampShadow3,_UseRampShadow4,_UseRampShadow5,_lightmapA0,_lightmapA4,_lightmapA2,_lightmapA1,_lightmapA3); //选择ramp行
            float rampV=0.45-(rampID-1.0)*0.1;  //计算Ramp采样纵坐标
            float rampDayUV=float2(rampU,rampV-rampSampling);
            float3 rampDayCol=SAMPLE_TEXTURE2D(_RampTex,sampler_RampTex,rampDayUV).rgb;
            float2 rampNightUV=float2(rampU,rampV);
            float3 rampNightCol=SAMPLE_TEXTURE2D(_RampTex,sampler_RampTex,rampNightUV).rgb;

            float3 rampColor=lerp(rampDayCol,rampNightCol,_DayOrNight);
            float3 ramp=lerp(rampColor,halfLambert,brightMask);

            return ramp;
        }

        //高光
        float3 Spec(float NdotL,float NdotH,float4 lightmap,float3 baseColor){
            float blinnPhong=pow(max(0.0,NdotH),_gloss); //Blinn-Phong
            float3 specular=blinnPhong*lightmap.r*_glossStrength; //高光强度 （r通道存放模型高光度）
            specular=specular*lightmap.b; //混合高光细节（b通道存放模型高光细节）
            specular=baseColor*specular; //叠加固有色
            lightmap.g=smoothstep(0.2,0.3,lightmap.g); //lightmap.g
            float halfLambert=smoothstep(0,_Gray,NdotL+_Dark)*lightmap.g; //半lambert
            float brightMask=step(_Bright,halfLambert); //亮面
            specular=specular*brightMask; //遮罩暗面
            return specular; //输出结果
        }
       

        //金属
        float3 Metal(float3 nDirVS,float4 lightmap,float3 baseColor){
            float metalMask=1-step(lightmap.r,0.9); //金属遮罩
            //采样metalmap
            float3 metalMap=SAMPLE_TEXTURE2D(_metalMap,sampler_metalMap,nDirVS.rg*0.5+0.5).rgb;
            metalMap=lerp(_metalMapColor,baseColor,metalMap); //自定义金属反射环境颜色
            metalMap=lerp(0,metalMap,metalMask);
            return metalMap; //输出结果
        }

        //边缘光
        float3 edgeLight(float NdotV,float3 baseColor){
            float3 fresnel=pow(1-NdotV,_fresnel); //菲涅尔范围
            fresnel=step(0.5,fresnel)*_edgeLight*baseColor;//边缘光强度
            return fresnel; //输出结果
        }

        //自发光
        float3 light(float3 baseColor,float diffuseA){
            diffuseA=smoothstep(0.1,1,diffuseA); //去除噪点
            float3 glow=lerp(0.0,baseColor*((sin(_Time.w*_flicker)*0.5+0.5)*_glow),diffuseA); //自发光
            return glow;

        }

        //身体
        float3 Body(float NdotL, float NdotH, float NdotV, float4 lightmap, float3 baseColor, float3 nDirVS){
            float3 ramp=RampShadow(lightmap,NdotL); //ramp
            float3 specular=Spec(NdotL,NdotH,lightmap,baseColor); //金属
            float3 metal=Metal(nDirVS,lightmap,baseColor); //金属
            float3 diffuse=baseColor*ramp; //漫反射
            diffuse=diffuse*step(lightmap.r,0.9); //遮罩金属区域
            float3 fresnel=edgeLight(NdotV,baseColor); //边缘光
            //混合最终结果
            float3 body=diffuse+metal+specular+fresnel;
            return body; //输出结果
        }

         //顶点着色器输入结构体
        struct Attributes{
            float4 positionOS:POSITION; //物体空间位置
            float2 uv0:TEXCOORD0; //原始UV
            float2 uv1:TEXCOORD1; //第二套UV
            float3 normalOS:NORMAL; //法线
            float4 color:COLOR0; //顶点颜色
            float4 tangentOS    : TANGENT; //切线

        };

        //片元着色器输入结构体
        struct Varyings{
            float4 positionCS:SV_POSITION;
            float2 uv0:TEXCOORD0;//处理后的UV
            float3 normalWS:TEXCOORD1;
            float4 color:TEXCOORD2;//顶点颜色
            float4 TtoW0        : TEXCOORD3; //x切线,y副切线,z法线,w顶点
            float4 TtoW1    : TEXCOORD4; //x切线,y副切线,z法线,w顶点
            float4 TtoW2  : TEXCOORD5; //x切线,y副切线,z法线,w顶点
        };

    ENDHLSL

    Pass{
        Name "Front" //Pass名称
        Tags{"LightMode"="UniversalForward"} //LightMode

        Cull Back //正面渲染，背面剔除

        HLSLPROGRAM

        #pragma vertex MainVS//指定顶点着色器
        #pragma fragment MainFS //指定片元着色器

        Varyings MainVS(Attributes input){
            Varyings output;

            //位置转换
            VertexPositionInputs posInput=GetVertexPositionInputs(input.positionOS.xyz);
            output.positionCS=posInput.positionCS;
            VertexNormalInputs vertexNormalInputs=GetVertexNormalInputs(input.normalOS);
            //法线变换
            float3 nDirWS = vertexNormalInputs.normalWS;  //世界空间法线
            float3 tDirWS = vertexNormalInputs.tangentWS;  //世界空间切线
            float3 bDirWS = vertexNormalInputs.bitangentWS;  //世界空间副切线
            float3 posWS = posInput.positionWS;  //世界顶点位置
            
            output.TtoW0 = float4(tDirWS.x, bDirWS.x, nDirWS.x, posWS.x);  //x切线,y副切线,z法线,w顶点
            output.TtoW1 = float4(tDirWS.y, bDirWS.y, nDirWS.y, posWS.y);  //x切线,y副切线,z法线,w顶点
            output.TtoW2 = float4(tDirWS.z, bDirWS.z, nDirWS.z, posWS.z);  //x切线,y副切线,z法线,w顶点

            //UV处理
            output.uv0=input.uv0*_BaseMap_ST.xy+_BaseMap_ST.zw;

            //传递顶点颜色
            output.color=input.color;
            output.normalWS=nDirWS;

            return output;

        } 

        //片元着色器
        float4 MainFS(Varyings i):SV_TARGET
        {
            //获取主光源
            Light mlight=GetMainLight();

            //采样纹理
            float3 baseColor=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv0).rgb;
            float diffuseA=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv0).a;
            float4 lightMap=SAMPLE_TEXTURE2D(_LightMap,sampler_LightMap,i.uv0);

            //法线计算
            float3 nDirTS=UnpackNormal(SAMPLE_TEXTURE2D(_Normalmap,sampler_Normalmap,i.uv0));
            nDirTS.xy*=_NormalScale;
            nDirTS.z=sqrt(1.0-saturate(dot(nDirTS.xy,nDirTS.xy))); //切线空间中归一化法线
            float3 posWS=float3(i.TtoW0.w,i.TtoW1.w,i.TtoW2.w); //世界空间顶点
            float3 nDirWS=normalize(half3(dot(i.TtoW0.xyz,nDirTS),dot(i.TtoW1.xyz,nDirTS),dot(i.TtoW2.xyz,nDirTS)));
            

            //光线计算
            float3 lDirWS=normalize(mlight.direction); //世界光源方向（平行光）
            float3 vDirWS=normalize(GetWorldSpaceViewDir(posWS)); //世界观察方向
            float3 hDirWS=normalize(vDirWS+lDirWS); //半角方向
            float3 nDirVS=mul((float3x3)UNITY_MATRIX_V,nDirWS); //世界空间法线方向

            //向量准备
            float NdotL=dot(nDirWS,lDirWS); //Lambert
            float NdotV=dot(nDirWS,vDirWS); //菲涅尔
            float NdotH=dot(nDirVS,hDirWS); //Blinn-Phong

            //半lambert
            lightMap.g=smoothstep(0.2,0.3,lightMap.g);
            float halfLambert=NdotL*0.5+0.5;
            halfLambert=smoothstep(0.1,_Gray,halfLambert-_Dark)*lightMap.g; //灰面控制
            float brightMask=step(_Bright,halfLambert); //亮面控制（Bright），bringhtMask 得到两面遮罩值0或1

            float3 _HDR=light(baseColor,diffuseA);
            //FinalColor
            float3 finalRGB=Body(NdotL,NdotH,NdotV,lightMap,baseColor, nDirVS);

            return float4(finalRGB, diffuseA);
            //return float4(_HDR,diffuseA);

        }
        ENDHLSL

    }

    Pass{
        Name "Back" //Pass名称
        Tags{"LightMode"="SRPDefailtUnlit"
        "Queue"="Geometry+1" //确保在正面之后渲染
    } //LightMode

        Cull Front //背面渲染，正面剔除

        HLSLPROGRAM

        #pragma vertex MainVS//指定顶点着色器
        #pragma fragment MainFS //指定片元着色器

        Varyings MainVS(Attributes input){
            Varyings output;

            //位置转换
            VertexPositionInputs posInput=GetVertexPositionInputs(input.positionOS.xyz);
            output.positionCS=posInput.positionCS;
            VertexNormalInputs vertexNormalInputs=GetVertexNormalInputs(input.normalOS);
            //法线变换
            float3 nDirWS = vertexNormalInputs.normalWS;  //世界空间法线
            float3 tDirWS = vertexNormalInputs.tangentWS;  //世界空间切线
            float3 bDirWS = vertexNormalInputs.bitangentWS;  //世界空间副切线
            float3 posWS = posInput.positionWS;  //世界顶点位置
            
            output.TtoW0 = float4(tDirWS.x, bDirWS.x, nDirWS.x, posWS.x);  //x切线,y副切线,z法线,w顶点
            output.TtoW1 = float4(tDirWS.y, bDirWS.y, nDirWS.y, posWS.y);  //x切线,y副切线,z法线,w顶点
            output.TtoW2 = float4(tDirWS.z, bDirWS.z, nDirWS.z, posWS.z);  //x切线,y副切线,z法线,w顶点

            //UV处理
            output.uv0=input.uv1*_BaseMap_ST.xy+_BaseMap_ST.zw;

            //传递顶点颜色
            output.color=input.color;
            output.normalWS=nDirWS;

            return output;

        } 

        //片元着色器
        float4 MainFS(Varyings i):SV_TARGET
        {
            //获取主光源
            Light mlight=GetMainLight();

            //采样纹理
            float3 baseColor=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv0).rgb;
            float diffuseA=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv0).a;
            float4 lightMap=SAMPLE_TEXTURE2D(_LightMap,sampler_LightMap,i.uv0);

            //法线计算
            float3 nDirTS=UnpackNormal(SAMPLE_TEXTURE2D(_Normalmap,sampler_Normalmap,i.uv0));
            nDirTS.xy*=_NormalScale;
            nDirTS.z=sqrt(1.0-saturate(dot(nDirTS.xy,nDirTS.xy))); //切线空间中归一化法线
            float3 posWS=float3(i.TtoW0.w,i.TtoW1.w,i.TtoW2.w); //世界空间顶点
            float3 nDirWS=normalize(half3(dot(i.TtoW0.xyz,nDirTS),dot(i.TtoW1.xyz,nDirTS),dot(i.TtoW2.xyz,nDirTS)));
            

            //光线计算
            float3 lDirWS=normalize(mlight.direction); //世界光源方向（平行光）
            float3 vDirWS=normalize(GetWorldSpaceViewDir(posWS)); //世界观察方向
            float3 hDirWS=normalize(vDirWS+lDirWS); //半角方向
            float3 nDirVS=mul((float3x3)UNITY_MATRIX_V,nDirWS); //世界空间法线方向

            //向量准备
            float NdotL=dot(nDirWS,lDirWS); //Lambert
            float NdotV=dot(nDirWS,vDirWS); //菲涅尔
            float NdotH=dot(nDirVS,hDirWS); //Blinn-Phong

            //半lambert
            lightMap.g=smoothstep(0.2,0.3,lightMap.g);
            float halfLambert=NdotL*0.5+0.5;
            halfLambert=smoothstep(0.1,_Gray,halfLambert-_Dark)*lightMap.g; //灰面控制
            float brightMask=step(_Bright,halfLambert); //亮面控制（Bright），bringhtMask 得到两面遮罩值0或1

            float3 _HDR=light(baseColor,diffuseA);
            //FinalColor
            float3 finalRGB=Body(NdotL,NdotH,NdotV,lightMap,baseColor, nDirVS);

            return float4(finalRGB, diffuseA);
            //return float4(_HDR,diffuseA);

        }
        ENDHLSL

    }

    // Pass{
    //     Tags{"LightMode"="SRPDefaultUnlit"  
    // }
    //     Cull Front
    //     HLSLPROGRAM

    //     #pragma vertex vert
    //     #pragma fragment frag

    //     Varyings vert(Attributes input){
    //         Varyings output;
    //         VertexPositionInputs posInput=GetVertexPositionInputs(input.positionOS.xyz); 
    //         VertexNormalInputs vertexNormalInputs=GetVertexNormalInputs(input.normalOS);
    //         float3 normalCS = normalize(mul((float3x3)UNITY_MATRIX_VP, vertexNormalInputs.normalWS)); // 世界空间→裁剪空间
    //         float3 ndcNormal = normalCS * posInput.positionCS.w; // 乘以w分量，消除透视拉伸
    //         float4 nearUpperRight=mul(unity_CameraInvProjection,float4(1,1,UNITY_NEAR_CLIP_VALUE,_ProjectionParams.y));//将近裁剪面右上角位置顶点变换到观察空间
    //         float aspect=abs(nearUpperRight.y/nearUpperRight.x); //求得屏幕宽高比
    //         ndcNormal.x*=aspect;
    //         float4 outPos=posInput.positionCS;
    //         outPos.xy+=0.01*_outline*ndcNormal.xy;
    //         output.positionCS=outPos;
    //         return output;

    //     }

    //     half4 frag(Varyings i):SV_TARGET{
    //         //采样贴图
    //         float4 lightmap = SAMPLE_TEXTURE2D(_LightMap,sampler_LightMap,i.uv0).rgba;
    //         float diffuseA = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv0).a;
    //         //分离lightmap.a各材质
    //         float lightmapA2 = step(0.25, lightmap.a);  //0.3
    //         float lightmapA3 = step(0.45, lightmap.a);  //0.5
    //         float lightmapA4 = step(0.65, lightmap.a);  //0.7
    //         float lightmapA5 = step(0.95, lightmap.a);  //1.0
    //         //重组lightmap.a
    //         float3 outlineColor = _outlineColor0;  //0.0
    //         outlineColor = lerp(outlineColor, _outlineColor2, lightmapA2);  //0.3
    //         outlineColor = lerp(outlineColor, _outlineColor3, lightmapA3);  //0.5
    //         outlineColor = lerp(outlineColor, _outlineColor4, lightmapA4);  //0.7
    //         outlineColor = lerp(outlineColor, _outlineColor5, lightmapA5);  //1.0

    //         if(_diffuseA == 1){ //裁剪
    //             diffuseA = smoothstep(0.05, 0.7, diffuseA);  //去除噪点
    //             clip(diffuseA - _Cutoff);
    //         }

    //         return half4(outlineColor, 1.0);  //输出
    //     }

    //     ENDHLSL
    // }
    
    }
}
