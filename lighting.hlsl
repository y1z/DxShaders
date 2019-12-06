
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
		float4 c_pointColor;
		float4 c_spotColor;

    float4 c_LightPos;
    float3 c_LightDir; 

    float c_LightModelIntensity;
    float c_LightSpecularIntensity;
    float c_LightAmbienIntensity;
		float c_LightPointRadious;
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
  // this is for when i separate this shader in two files 
  matrix model : MODEL_MATRIX;
  //where the position is in model space 
  float4 Pos : SV_POSITION;
	// to know when the position is in world space 
	float4 PosWs :POSITION0;  

  float3 Norm : NORMAL0;
  float3 NormWs : NORMAL1;
  float3 Tan :  TANGENT0;

  float2 Tex : TEXCOORD0;
};



	//#***define  POINT_LIGHT 1
	//#***define PIXEL_LIGHT 1	
//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
PS_INPUT VS( VS_INPUT input )
{
  PS_INPUT output = (PS_INPUT) 0;
  /*move the vertex to world space */
  output.Pos = mul(input.Pos , World);
  /*get the position of the vertex in world space for later use*/
	output.PosWs = output.Pos;
  /*getting model to pass in the pixel shader*/
  output.model = World;
  /*move the vertex to view space */
  output.Pos = mul(output.Pos , View);
  output.Pos = mul(output.Pos , Projection);

  output.Tex = input.Tex;
	#if PIXEL_LIGHT
  /*move normal with the model */

  output.Norm = input.Norm.xyz;
	output.NormWs = normalize(mul(float4(input.Norm.xyz,0.0f),World));
	output.Tan = normalize(mul(float4(input.Tan.xyz,0.0f),World));
	
	#endif//PIXEL_LIGHT
    
  return output;
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 PS( PS_INPUT input ) : SV_Target
{
#if PIXEL_LIGHT
    // find out which pixels are being hit by 
    // the light 
  float IdN = clamp(dot(-c_LightDir.xyz, input.NormWs),0.0f,1.0f);
	// color light values 
	float4 ambient = float4(0.0f,0.0f,0.0f,0.0f);
	float4 diffuse= float4(0.0f,0.0f,0.0f,0.0f);
	float4 specular = float4(0.0f,0.0f,0.0f,0.0f);
  /* finds all the places where the object was not lit by the light*/
  float UnlitArea = (1.0f - IdN);

  ambient = (c_AmbienColor * c_LightAmbienIntensity) * UnlitArea;  

	float3 normViewDir = normalize(input.Pos.xyz  - c_viewPosition.xyz);
	float3 normLightDir = normalize(c_LightDir);

	float distance = float(0.0f);


  #if BLIN || ALL_SHADERS 
		float3 psReflect = normalize(reflect(normViewDir.xyz,input.Norm));
    // looking for a reflection
    float vectorDotReflect = max(dot(normViewDir.xyz,psReflect),0.0);
    float specularFactor = pow(vectorDotReflect,c_LightSpecularIntensity);
    specular = (specularFactor *  c_LightSpecularIntensity * IdN) * c_specularColor ;
		#else// PHONG
		// basically a cheaper way of getting the reflection of a surface 
		float3 HalfVector = normalize(-normLightDir + -normViewDir.xyz );
		// find out how much 
		float  SimiReflect = dot(HalfVector,input.NormWs.xyz);
    float specularFactor = pow( SimiReflect,c_LightSpecularIntensity);
    specular = (specularFactor *  c_LightSpecularIntensity * IdN) * c_specularColor ;
  #endif//BLIN
////////////////////////////////////
// POINT LIGHT 
////////////////////////////////////
	#if POINT_LIGHT
    float3 PointLightDirectionWS = -normalize(input.PosWs.xyz - mul(float4(c_LightPos.xyz, 1.0f), input.model).xyz);
		//	float3 PointViewDirectionWS = PointLightDirectionWS;
		distance = length(input.PosWs.xyz - mul(float4(c_LightPos.xyz, 1), input.model).xyz);
		float PointNormalDotLightWS = max(0.0f, dot( PointLightDirectionWS.xyz, input.NormWs)) * (c_LightPointRadious / distance);
	#endif// POINT_LIGHT
   // color the pixels that are bing hit by the light  
   // * IdN; /* txDiffuse.Sample(samLinear , input.Tex)  ; 
	diffuse = saturate( txDiffuse.Sample(samLinear,input.Tex) * c_diffuseColor); //* IdN;
  return diffuse + ambient + specular;
#else
return txDiffuse.Sample(samLinear,input.Tex);
#endif // PIXEL_LIGHT
}
