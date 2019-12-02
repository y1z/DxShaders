
Texture2D txDiffuse : register( t0 );
SamplerState samLinear : register( s0 );

//contains all information related with the camera like 
//the direction it's looking at,it's position 
cbuffer CameraData: register( b0 )
{
  matrix View;
	float4 c_viewPosition;
  float3 c_viewDir;
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
    float4 c_diffuseColor;
    float4 c_specularColor;

    float4 c_LightPos;
    float3 c_LightDir; 

    float c_LightModelIntensity;
    float c_LightSpecularIntensity;
    float c_LightAmbienIntensity;
};


//--------------------------------------------------------------------------------------
struct VS_INPUT
{
  float4 Pos : POSITION;
  float3 Norm : NORMAL0;
  float3 Tan :TANGENT0;
  float2 Tex : TEXCOORD0;
};

struct PS_INPUT
{
  float4 Pos : SV_POSITION;
  float3 Norm : NORMAL0;
  float3 Tan :  TANGENT0;
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

/* finds all the places where the object was not lit by the light*/
  float UnlitArea = (1.0f - IdN);

  float4 ambient = (c_AmbienColor * c_LightAmbienIntensity) * UnlitArea;  

	float3 vsViewDir = normalize(input.Pos.xyz  - c_viewPosition.xyz);

	float4 specular = float4(0.0f,0.0f,0.0f,0.0f );
  #if BLIN
		float3 psReflect = normalize(reflect(vsViewDir.xyz,input.Norm));
    // looking for a reflection
    float vectorDotReflect = max(dot(vsViewDir.xyz,psReflect),0.0);
    float specularFactor = pow(vectorDotReflect,c_LightSpecularIntensity);
    specular = (specularFactor *  c_LightSpecularIntensity * IdN) * c_specularColor ;
		#else// PHONG
		// basically a cheaper way of getting the reflection of a surface 
		float3 HalfVector =normalize(-c_LightDir + -vsViewDir.xyz );
		// find out how much 
		float  SimiReflect = dot(HalfVector,input.Norm.xyz);
    float specularFactor = pow( SimiReflect,c_LightSpecularIntensity);
    specular = (specularFactor *  c_LightSpecularIntensity * IdN) * c_specularColor ;
  #endif//BLIN

   // color the pixels that are bing hit by the light  
   // * IdN; /* txDiffuse.Sample(samLinear , input.Tex)  ; 
	float4 diffuse = saturate( txDiffuse.Sample(samLinear,input.Tex) * c_diffuseColor) * IdN;

  return diffuse + ambient + specular;
}
