Shader "Custom/CheckerGradient" {
    Properties {
        _Size("Size",Range(1,100))=2
        _Steps ("Quantize Steps", Range(2, 8)) = 4
    }
    SubShader {
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            
            float _Steps;
            float _Size;
            
            struct v2f { float2 uv : TEXCOORD0; float4 pos : SV_POSITION; };
            v2f vert (appdata_base v) {
                v2f o; o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord * _Size; // 2x2 tiling
                return o;
            }
            
            half4 frag (v2f i) : SV_Target {
                // 2x2 抛物面渐变
                float2 cellUV = frac(i.uv);
                float2 center = float2(0.5, 0.5);
                float dist = 1 - distance(cellUV, center); // 中心亮
                
                // 灰度反转：1 - dist → 中心暗、边缘亮
                float invDist = 1 - dist;
                
                // 量化色阶
                float quantized = floor(invDist * _Steps) / _Steps;
                
                return half4(quantized, quantized, quantized, 1);
            }
            ENDCG
        }
    }
}