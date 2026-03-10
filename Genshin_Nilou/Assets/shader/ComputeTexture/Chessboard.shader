Shader "Custom/Chessboard" {
    Properties {
        _Size ("格子密度", Range(1, 100)) = 10
        _Color1 ("颜色1", Color) = (1,1,1,1)
        _Color2 ("颜色2", Color) = (0,0,0,1)
    }
    SubShader {
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f { float2 uv : TEXCOORD0; float4 vertex : SV_POSITION; };

            float _Size;
            float4 _Color1;
            float4 _Color2;

            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv * _Size; // 缩放UV以控制格子数量
                return o;
            }

            fixed4 frag (v2f i) : SV_Target {
                // 计算棋盘格：根据UV坐标的奇偶性选择颜色
                float2 cell = floor(i.uv);
                bool isEven = (fmod(cell.x, 2) + fmod(cell.y, 2)) % 2 == 0;
                return isEven ? _Color1 : _Color2;
            }
            ENDCG
        }
    }
}