Shader "Custom/Ripple"
{
    Properties
    {
        _Attenuation("Attenuation",Range(0,1))=0.99
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100

        Pass
        {
            Name"WaterTransmitPass"
            Tags{"LightMode"="UniversalForward"}
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Utils.hlsl"

            TEXTURE2D(_PrevRT);
            SAMPLER(sampler_PrevRT);
            TEXTURE2D(_CurrentRT);
            SAMPLER(sampler_CurrentRT);

            CBUFFER_START(UnityPerMaterial)
                float _Attenuation;
                float _h;
                float4 _WaterTransmitParams;
                float4 _CurrentRT_TexelSize;
            
            CBUFFER_END

            


            struct appdata
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS=TransformObjectToHClip(v.positionOS.xyz);
                o.uv=v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 e=float3(_CurrentRT_TexelSize.xy,0);
                float2 uv=i.uv;
                float2 uvOffset[4]={float2(uv.x,clamp(0.01,0.99,uv.y+e.y)),float2(uv.x,clamp(0.01,0.99,uv.y-e.y)),float2(clamp(0.01,0.99,uv.x-e.x),uv.y),
                float2(clamp(0.01,0.99,uv.x+e.x),uv.y)};

                float avgCur= DecodeHeight(SAMPLE_TEXTURE2D(_CurrentRT, sampler_CurrentRT, uvOffset[0]))
                + DecodeHeight(SAMPLE_TEXTURE2D(_CurrentRT, sampler_CurrentRT, uvOffset[1]))
                + DecodeHeight(SAMPLE_TEXTURE2D(_CurrentRT, sampler_CurrentRT, uvOffset[2]))
                +DecodeHeight(SAMPLE_TEXTURE2D(_CurrentRT, sampler_CurrentRT, uvOffset[3]));

                float curnCur=DecodeHeight(SAMPLE_TEXTURE2D(_CurrentRT,sampler_CurrentRT,uv));
                float prevCur=DecodeHeight(SAMPLE_TEXTURE2D(_PrevRT,sampler_PrevRT,uv));

                float d=_WaterTransmitParams.z*avgCur+_WaterTransmitParams.y*prevCur+_WaterTransmitParams.x*curnCur;
                d*=_Attenuation;

                return EncodeHeight(d);
            }
            ENDHLSL
        }
    }
}