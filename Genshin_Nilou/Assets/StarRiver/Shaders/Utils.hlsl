#ifndef UTILS
#define UTILS

//将0~1范围的单浮点数，编码到float2（对应纹理RG通道），提升存储精度
inline float2 EncodeFloatRG(float v)
{
    //将v拆分为两个分量，分别乘以1.0（整数部分）和255.0（小数部分放大）
    float2 kEncodeMul = float2(1.0, 255.0);
    float kEncodeBit = 1.0 / 255.0;
    float2 enc = kEncodeMul * v;
    enc = frac(enc);
    //消除关联误差
    enc.x -= enc.y * kEncodeBit;
    return enc;
}
//解码回0~1范围
inline float DecodeFloatRG(float2 enc)
{
    float2 kDecodeDot = float2(1.0, 1 / 255.0);
    return dot(enc, kDecodeDot);
}

float4 EncodeHeight(float height) {
    float2 rg = EncodeFloatRG(height >= 0 ? height : 0);
    //负高度
    float2 ba = EncodeFloatRG(height < 0 ? -height : 0);
    return float4(rg, ba);
}

float DecodeHeight(float4 rgba)
{
    float d1 = DecodeFloatRG(rgba.rg);
    float d2 = DecodeFloatRG(rgba.ba);
    if (d1 >= d2)
        return d1;
    else 
        //说明为负高度
        return -d2;
}
#endif
