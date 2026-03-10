Shader "Custom/StarCloud"
{
    Properties
    {
        [Header(Color)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _FlowSpeed("Flow Speed",Range(0,10))=1.0
        _BaseColor("Base Color",Color)=(0.5,0.5,1,1)
        [HDR]_TintCol("Tint Color",Color)=(0.5,0.5,1,1)//染色/色调色

        [Header(Reflection)]
        _ReflectionInt("Reflection Intensity",Range(0,1))=0.5
        _HorizonDistance("Horizon Distance",Range(1,30))=5

        [Header(Flow)]
        [Toggle]_ENABLE_INTERACTIVE("Interacrive By Mouse Or Object(Default: Object)",Float)=1
        [Toggle]_ENABLE_GEOMETRY_WAVE("isOcean?",Float)=1
        _MaskTex("Mask Texture",2D)="white"{}
        _FlowInt("Flow Intensity",Range(0,5.0))=1.0
        _WaveSpeed("WaveSpeed",Range(0,1)) = 0.01
        _WaveA("Wave A(dir,steepness,wavelength)",Vector) = (1,0,0,10)
        _WaveB("Wave B",Vector)  = (0,1,0.25,20)
        _WaveC("Wave C",Vector) = (1,1,0.15,10)
        _Scale("Vertex number Scale",Range(0,1))=0.01
        _Glossiness("Specular Glossiness",Range(1,10))=1
        _SpecInt("Specualr Intensity",Range(0,10))=1

        _NoiseTex("Noise Texture",2D)="white"{}
        _NoiseInt("Noise Intensity",Range(0.0,0.1))=0.02
        _DistortedTex("Disorted Texture",2D)="white"{}
        _DistortInt("Distort Intensity",Range(0,5))=1

        [Header(Star)]
        _StarTex("star Texture",2D)="white"{}
        _StarColor("Star color",Color)=(1,1,1,1)
        _shiningSpeed("Shining Speed",Float)=0.1
        _StarTexSize("Star Texture Size",Float)=1
        _SatrTintCol("Star Tint Color",Color)=(1,1,1,1)
        }
    SubShader
    {
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_StarTex);
        SAMPLER(sampler_StarTex);
        TEXTURE2D(_NoiseTex);
        SAMPLER(sampler_NoiseTex);
        TEXTURE2D(_DistortedTex);
        SAMPLER(sampler_DisortedTex);
        TEXTURE2D(_ReflectionTex);
        SAMPLER(sampler_ReflectionTex);
        sampler2D _MaskTex;
        sampler2D _CameraOpaqueTexture;
        sampler2D _CameraDepthTexture;
        sampler2D _HeightRT;

        CBUFFER_START(UnityPerMaterial)
        
        float4 _MainTex_ST;
        float4 _BaseColor;
        float4 _TintCol;
        float4 _MaskTex_ST;
        float4 _MaskTex_TexelSize;
        float4 _NoiseTex_ST;
        float4 _StarTex_ST;
        float4 _DisortedTex_ST;
        float4 _ReflectionTex_ST;

        float4 _CameraDepthTexture_TexelSize;

        float _ReflectionInt;
        float _HorizonDistance;
        float _FlowInt;
        float _FlowSpeed;
        float _NoiseInt;
        float _DistortInt;
        float _Glossiness;
        float _SpecInt;

        float4 _WaveA,_WaveB,_WaveC;
        float _WaveSpeed;
        float _Scale;

        float4 _StarColor;
        float _shiningSpeed;
        float _StarTexSize;
        float4 _SatrTintCol;
        CBUFFER_END

        #include "WaterPerCompute.hlsl"

        ENDHLSL
        Tags { 
            "RenderType"="Opaque" 
            "Queue"="Geometry" 
            "RenderPipeline"="UniversalPipeline" 
            "LightMode"="UniversalForward" 
        }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            struct Attributes{
                float4 positionOS:POSITION;
                float2 uv:TEXCOORD0;
                float3 normal:NORMAL;
                float4 tangentOS:TANGENT;

            };

            struct Varying{
                float2 uv:TEXCOORD0;
                float4 positionCS:SV_POSITION;
                float3 positionWS:TEXCOORD5;
                float3 viewNormal:NORMAL;
                float4 screenPos:TEXCOORD1;
                float3 viewDirWS:TEXCOORD2;
                float3 normalWS:TEXCOORD3;
                float4 noise_disortUV:TEXCOORD4;
                float4x4 TW:TEXCOORD6;

            };

            inline half3 BelndNormals(half3 n1,half3 n2){
                return normalize(half3(n1.xy+n2.xy,n1.z*n2.z));
            }

           Varying vert(Attributes input){
                Varying o;
                VertexNormalInputs vertexNormalInputs=GetVertexNormalInputs(input.normal.xyz,input.tangentOS);
                o.normalWS=vertexNormalInputs.normalWS;

                #ifdef _ENABLE_GEOMETRY_WAVE_ON
                    float3 gridPoint=input.positionOS.xyz;
                    float3 tangent=float3(1,0,0);
                    float3 binormal=float3(0,0,1);
                    float3 position=gridPoint;
                    //叠加三个Gerstner波，生成复杂面
                    position += GerstnerWave(_WaveA,gridPoint,tangent,binormal,_WaveSpeed,_Scale); 
                    position += GerstnerWave(_WaveB,gridPoint,tangent,binormal,_WaveSpeed,_Scale);
                    position += GerstnerWave(_WaveC,gridPoint,tangent,binormal,_WaveSpeed,_Scale);
                    float3 normal=normalize(cross(binormal,tangent));
                    o.normalWS=TransformObjectToWorldNormal(normal);
                    input.positionOS.xyz=position;


                #endif

                VertexPositionInputs vertexPositionInputs=GetVertexPositionInputs(input.positionOS.xyz);
                float3 positionWS=vertexPositionInputs.positionWS;
                float3 bitangentWS=vertexNormalInputs.bitangentWS;
                float3 tangentWS=vertexNormalInputs.tangentWS;
                float3 normalWS=vertexNormalInputs.normalWS;
                o.TW[0]=float4(tangentWS.x,bitangentWS.x,normalWS.x,positionWS.x);
                o.TW[1]=float4(tangentWS.y,bitangentWS.y,normalWS.y,positionWS.y);
                o.TW[2]=float4(tangentWS.z,bitangentWS.z,normalWS.z,positionWS.z);
                o.positionCS=vertexPositionInputs.positionCS;
                
                o.viewDirWS=normalize(_WorldSpaceCameraPos.xyz-positionWS.xyz);
                
                o.uv=input.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                o.noise_disortUV=float4(input.uv*_NoiseTex_ST.xy+_NoiseTex_ST.zw,input.uv*_DisortedTex_ST.xy+_DisortedTex_ST.zw);
                o.screenPos=ComputeScreenPos(o.positionCS);
                o.positionWS=positionWS;
                return o;
           }
           
           float4 frag(Varying input):SV_TARGET{
                Light mainLight=GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                float3 mainLightDir=normalize(mainLight.direction);
                float3 halfDir=normalize(input.viewDirWS+mainLightDir);

                float phase0=frac(_Time.y*_FlowSpeed);
                float phase1=frac(_Time.y*_FlowSpeed+0.5);

                float3 normalWS=input.normalWS;
                #ifdef _ENABLE_INTERACTIVE_ON
                    
                    float3 normalRT=UnpackNormal(SAMPLE_TEXTURE2D(_NormalRT,sampler_NormalRT,input.uv));
                    RippleNormalWS=normalize(float3(dot(input.TW[0].xyz,normalRT),dot(input.TW[1].xyz,normalRT),dot(input.TW[2].xyz,normalRT)));
                    normalWS=BelndNormals(normalWS,RippleNormalWS);
                #endif
                //高光
                float ndh=saturate(dot(halfDir,normalWS));
                half3 spec=pow(ndh,_Glossiness)*mainLight.color*_SpecInt;
                
                //波形函数
                float flowFactor0=cos(sin(cos(phase0*PI))+0.5);
                float flowFactor1=cos(sin(cos(phase1*PI))+0.5);

                float2 waterDistort=(SAMPLE_TEXTURE2D(_DistortedTex,sampler_DisortedTex,input.noise_disortUV.zw).xy*2-1)*_DistortInt;
                float2 noiseUV=float2(input.noise_disortUV.x+phase0,input.noise_disortUV.y+phase0);

                float surfaceNoise=SAMPLE_TEXTURE2D(_NoiseTex,sampler_NoiseTex,noiseUV).r;

                float2 tilingUV=input.uv+surfaceNoise*_NoiseInt;
                
                
                float2 MainUV0=tilingUV-flowFactor0;
                float2 MainUV1=tilingUV-flowFactor1;

                float3 tex0=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,MainUV0);
                float3 tex1=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,MainUV1);

                //构造权重函数
                float flowLerp=abs(phase0-0.5)*2;
                half3 seaCol=lerp(tex0,tex1,flowLerp)*_BaseColor*_TintCol;
                
                float2 reflectUV=input.screenPos.xy+surfaceNoise*_NoiseInt;
                half4 var_ReflectionTex=SAMPLE_TEXTURE2D(_ReflectionTex,sampler_ReflectionTex,reflectUV);
                half3 reflectCol=var_ReflectionTex.rgb*seaCol;

                //星光
                float2 starUV0=(MainUV0*_StarTex_ST.xy+_StarTex_ST.zw)*_StarTexSize;
                float2 starUV=(MainUV1*_StarTex_ST.xy+_StarTex_ST.zw)*_StarTexSize;
                float4 star0=SAMPLE_TEXTURE2D(_StarTex,sampler_StarTex,starUV0);
                float2 starUV1=starUV-phase0*_shiningSpeed*_StarTexSize;
                float4 star1=SAMPLE_TEXTURE2D(_StarTex,sampler_StarTex,starUV1)*_SatrTintCol;
                seaCol+=(star0.rgb*star1.rgb*_StarColor.rgb);
                
                half3 finalCol=lerp(seaCol,var_ReflectionTex,_ReflectionInt);

                finalCol+=spec;
                return float4 (finalCol,1);
           }
            ENDHLSL
        }
    }
}