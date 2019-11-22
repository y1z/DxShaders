

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

    float4 c_LightPos;
    float3 c_LightDir; 

    float c_LightModelIntensity;
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
  /*move the vertex to world space */
  output.Pos = mul(input.Pos , World);

  /*move the vertex to view space */
  output.Pos = mul(output.Pos , View);
  output.Pos = mul(output.Pos , Projection);
  /*move normal with the model */
  output.Norm = normalize(mul(float4(input.Norm.xyz,0.0f),World));
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
   float IdN = clamp(dot(-c_LightDir.xyz, input.Norm),0.0f,1.0f);

   // color the pixels that are bing hit by the light  
   // * IdN; /* txDiffuse.Sample(samLinear , input.Tex)  ; 
   float4 diffuse =  saturate( txDiffuse.Sample(samLinear,input.Tex) * c_LightColor) * IdN;
   
  return diffuse;
}
