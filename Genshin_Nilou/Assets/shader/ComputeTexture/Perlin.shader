Shader "Custom/PerlinNoiseGenerator"
{
    Properties
    {
        _NoiseScale ("Noise Scale", Float) = 10.0       // 噪声缩放（控制纹理块大小）
        _Octaves ("Octaves", Int) = 4                  // 叠加层数
        _Persistence ("Persistence", Float) = 0.5      // 振幅衰减
        _Lacunarity ("Lacunarity", Float) = 2.0        // 频率倍增
        _Brightness ("Brightness", Range(0, 2)) = 1.0  // 亮度调节
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // 外部参数
            CBUFFER_START(UnityPerMaterial)
                float _NoiseScale;
                int _Octaves;
                float _Persistence;
                float _Lacunarity;
                float _Brightness;
            CBUFFER_END

            // 顶点输入/输出结构
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
            };

            // 经典Perlin噪声核心实现（HLSL版）
            // 1. 置换表（简化版，保证随机性）
            static const int perm[256] = {
                151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,
                8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,
                35,11,32,57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,74,165,71,
                134,139,48,27,166,77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,
                55,46,245,40,244,102,143,54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,
                18,169,200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,
                250,124,123,5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,
                189,28,42,223,183,170,213,119,248,152,2,44,154,163,70,221,153,101,155,167,43,
                172,9,129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,218,246,97,
                228,251,34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,249,14,239,107,
                49,192,214,31,181,199,106,157,184,84,204,176,115,121,50,45,127,4,150,254,138,
                236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
            };

            // 2. 梯度向量表（2D）
            static const float2 grads[4] = {
                float2(1,1), float2(-1,1),
                float2(1,-1), float2(-1,-1)
            };

            // 哈希函数（周期边界）
            int Hash(int i, int j) { return perm[(perm[i & 255] + j) & 255]; }

            // S缓和曲线
            float Fade(float t) { return t * t * t * (t * (t * 6 - 15) + 10); }

            // 线性插值
            float Lerp(float a, float b, float t) { return a + t * (b - a); }

            // 点积计算
            float Dot(float2 g, float x, float y) { return g.x * x + g.y * y; }

            // 基础2D Perlin噪声（返回[-1,1]）
            float PerlinNoise(float2 uv)
            {
                float x = uv.x;
                float y = uv.y;

                // 1. 获取单元格整数顶点
                int xi = floor(x);
                int yi = floor(y);
                float xf = x - xi;
                float yf = y - yi;

                // 2. 缓和曲线处理偏移
                float u = Fade(xf);
                float v = Fade(yf);

                // 3. 计算四个顶点的哈希值
                int aa = Hash(xi, yi);
                int ab = Hash(xi, yi + 1);
                int ba = Hash(xi + 1, yi);
                int bb = Hash(xi + 1, yi + 1);

                // 4. 计算梯度点积
                float x0 = Dot(grads[aa % 4], xf, yf);
                float x1 = Dot(grads[ab % 4], xf, yf - 1);
                float y0 = Lerp(x0, x1, v);

                float x2 = Dot(grads[ba % 4], xf - 1, yf);
                float x3 = Dot(grads[bb % 4], xf - 1, yf - 1);
                float y1 = Lerp(x2, x3, v);

                // 5. 最终插值返回
                return Lerp(y0, y1, u);
            }

            // 多倍频FBM噪声（返回[0,1]）
            float FbmNoise(float2 uv)
            {
                float total = 0.0;
                float amplitude = 1.0;
                float frequency = 1.0;
                float maxValue = 0.0;

                for (int i = 0; i < _Octaves; i++)
                {
                    total += PerlinNoise(uv * frequency) * amplitude;
                    maxValue += amplitude;
                    amplitude *= _Persistence;
                    frequency *= _Lacunarity;
                }

                // 归一化到[0,1]
                return saturate((total / maxValue + 1) / 2);
            }

            // 顶点着色器
            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv * _NoiseScale;
                return output;
            }

            // 片元着色器（生成噪声纹理）
            half4 frag(Varyings input) : SV_Target
            {
                // 生成FBM噪声值
                float noiseValue = FbmNoise(input.uv);
                // 亮度调节+归一化
                noiseValue = saturate(noiseValue * _Brightness);
                // 返回灰度颜色
                return half4(noiseValue, noiseValue, noiseValue, 1.0);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}