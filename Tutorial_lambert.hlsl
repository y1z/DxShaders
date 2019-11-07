Texture2D txDiffuse : register( t0 );
SamplerState samLinear : register( s0 );



cbuffer cbNeverChanges : register( b0 )
{
  matrix View;
};

cbuffer cbChangeOnResize : register( b1 )
{
  matrix Projection;
};

cbuffer cbChangesEveryFrame : register( b2 )
{
  matrix World;
  float4 vMeshColor;
};

cbuffer LightData : register(b3)
{
    float4 c_AmbienColor;
    float4 c_LightColor;
    float3 c_LightDir; 
    float3 c_LightPos;
    float c_LightmodelIntensity;
    float c_LightAmbienIntensity;
};


//--------------------------------------------------------------------------------------
struct VS_INPUT
{
  float4 Pos : POSITION;
  float3 Norm : NORMAL0;
  float2 Tex : TEXCOORD0;
};

struct PS_INPUT
{
  float4 Pos : SV_POSITION;
  float3 Norm : NORMAL0;
  float2 Tex : TEXCOORD0;
};


//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
PS_INPUT VS( VS_INPUT input )
{
  PS_INPUT output = (PS_INPUT) 0;
  output.Pos = mul(input.Pos , World);
  output.Pos = mul(output.Pos , View);
  output.Pos = mul(output.Pos , Projection);
  output.Norm = mul(normalize(float4(input.Norm.xyz,0.0f)),World);
  output.Tex = input.Tex;

    
  return output;
}


//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 PS( PS_INPUT input ) : SV_Target
{
    // find out which pixels are being hit by 
    // the light 
   float IdN = clamp(dot(-c_LightDir, input.Norm),0.0f,1.0f);
   // color the pixels that are bing hit by the light  
   // * IdN; /* txDiffuse.Sample(samLinear , input.Tex)  ; 
 // vMeshColor * IdN;
  float4 diffuse = txDiffuse.Sample(samLinear,input.Tex) * saturate( vMeshColor * c_LightColor) * IdN;
   
  //diffuse = diffuse * IdN;
  return diffuse;
}
