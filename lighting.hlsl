
	//# define PIXEL_LIGHT 1	
	//# define ALL_SHADERS 1
	//# define BLIN 0
//	# define POINT_LIGHT 1
	//# define SPOT_LIGHT 1

Texture2D txDiffuse : register( t0 );
Texture2D  txNormal : register( t1 );
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
	//color of each light 
    float4 c_AmbienColor;
    float4 c_diffuseColor;
    float4 c_specularColor;
		float4 c_pointColor;
		float4 c_spotColor;

	//positions of the light 
    float4 c_LightPos;
		float4 c_spotPos;


	// directions of each light
    float3 c_LightDir; 
		float3 c_SpotLightDir;

	// how bright the light are
    float c_LightModelIntensity;
    float c_LightSpecularIntensity;
    float c_LightAmbienIntensity;
		float c_LightPointRadius ; 
		float c_LightSpecularPower;
    float c_spotBeta;
    float c_spotAlpha;
    float c_spotRadiuos;
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

  #if PIXEL_LIGHT == 0
  float4 Color : COLOR;
  #endif
  float3 Norm : NORMAL0;
  float3 NormWs : NORMAL1;
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
  /*get the position of the vertex in world space for later use*/
	output.PosWs = output.Pos;
  /*getting model to pass in the pixel shader*/
  /*move the vertex to view space */
  output.Pos = mul(output.Pos , View);
  output.Pos = mul(output.Pos , Projection);

  output.Tex = input.Tex;
  output.model = World;

	#if PIXEL_LIGHT 
  /*move normal with the model */

  output.Norm = input.Norm.xyz;
	output.NormWs = normalize(mul(float4(input.Norm.xyz,0.0f),World)).xyz;
	output.Tan = normalize(mul(float4(input.Tan.xyz,0.0f),World)).xyz;
	#elif PIXEL_LIGHT == 0
	// color light values 
	float4 ambient = float4(0.0f,0.0f,0.0f,0.0f);
	float4 diffuse= float4(0.0f,0.0f,0.0f,0.0f);
	float4 specular = float4(0.0f,0.0f,0.0f,0.0f);
	//
	float distance = float(0.0f);

	float3 normWS = normalize(mul(float4(input.Norm.xyz,0.0f),World)).xyz;
	float3 normLighDir = -normalize(c_LightDir);
	float3 normViewDir = -normalize(c_LightDir);
	float normDotLight = max(0.0f, dot(normLighDir,normWS));


 float dotProductResult = float(0.0f);


#if POINT_LIGHT || ALL_SHADERS

float pointLightDot = float(0.0f);
	// getting a vector that point to the model
    float3 pointLightDirWs = -normalize(output.PosWs.xyz - mul(c_LightPos.xyzw, output.model).xyz);
		float3 pointViewDir = pointLightDirWs;
		distance = length(output.PosWs.xyz - c_LightPos.xyzw );
		// checking what is going to be illuminated
		float pointNormalDotLightWS = max(0.0f, dot( pointLightDirWs.xyz, normWS.xyz)) * (c_LightPointRadius / distance);
		
#endif// POINT_LIGHT

#if SPOT_LIGHT || ALL_SHADERS //SPOT_LIGHT

		float3 normSpotViewDir = -normalize(output.PosWs.xyz - c_viewPosition.xyz);
		float3 normSpotLightDir = -normalize(c_SpotLightDir.xyz);

		float3 SpotDirToVertex = -normalize( output.PosWs.xyz - c_viewPosition.xyz);
		float Theta = dot(SpotDirToVertex, normSpotLightDir.xyz);
		float Spot = Theta - cos(c_spotBeta * 0.5);
		Spot = max(0.0, Spot / (cos(c_spotAlpha * 0.5) - cos(c_spotBeta * 0.5)));

		distance = length(output.PosWs.xyz - c_viewPosition.xyz);
		float SpotNormalDotLightWS = max(0.0, dot(normSpotLightDir, normWS.xyz) * Spot) * (c_spotRadiuos / distance);

#endif//SPOT_LIGHT

#if BLIN || ALL_SHADERS 
		// basically a cheaper way of getting the reflection of a surface 
		float3 HalfVector = normalize(-normLightDir + -normViewDir.xyz );
		// find out how much 
		float SimiReflect = dot(HalfVector,input.NormWs.xyz);
	  pointLightDot = SimiReflect;  
		
    float specularFactor = pow( SimiReflect,c_LightSpecularIntensity);
    specular = (specularFactor *  c_LightSpecularIntensity * lightDirDotNormal) * c_specularColor ;

		#if POINT_LIGHT || ALL_SHADERS 
			HalfVector = normalize( pointViewDir.xyz + pointLightDirWs.xyz);
		  SimiReflect = max(0.0f, dot(input.NormWs.xyz, HalfVector.xyz));
      pointLightDot =SimiReflect;
			float pointSpecularFactor = pow(SimiReflect, c_LightSpecularPower) * pointNormalDotLightWS;
		#endif

		#if SPOT_LIGHT ||  ALL_SHADERS 
			HalfVector = normalize(normSpotViewDir.xyz + normSpotLightDir.xyz); 
			SimiReflect = max(0.0f, dot(input.NormWs.xyz, HalfVector.xyz));
			float SpotSpecularFactor = pow( SimiReflect , c_LightSpecularPower) * SpotNormalDotLightWS;
		#endif//SPOT_LIGHT

 #else// PHONG

		float3 psReflect = normalize(reflect(normViewDir.xyz,normWS.xyz));
    // checking for what reflects  back at as 
    float viewDotReflect = max(dot(normViewDir.xyz, psReflect),0.0);
		
    float specularFactor = pow(viewDotReflect,c_LightSpecularIntensity);
    specular = (specularFactor *  c_LightSpecularIntensity * normDotLight) * c_specularColor ;

		#if POINT_LIGHT || ALL_SHADERS 
			psReflect = normalize(reflect(-pointLightDirWs.xyz, normWS.xyz));
		//checking for the reflection of the point light  
			viewDotReflect = max(0.0f, dot(pointViewDir, psReflect));
			dotProductResult  = viewDotReflect;

		float pointSpecularFactor = pow(psReflect, c_LightSpecularPower) * pointNormalDotLightWS;
		#endif //POINT_LIGHT 

	#if  SPOT_LIGHT || ALL_SHADERS 
			psReflect = normalize(reflect(-normSpotLightDir.xyz,normWS.xyz));
			viewDotReflect = max(0.0f, dot(normSpotViewDir.xyz, psReflect));
			float SpotSpecularFactor = pow(viewDotReflect, c_LightSpecularPower) * SpotNormalDotLightWS;
	#endif // SPOT_LIGHT

 #endif//BLIN

////////////////////////////////////
// POINT LIGHT 
////////////////////////////////////
 #if POINT_LIGHT || ALL_SHADERS
	diffuse += c_LightModelIntensity * c_pointColor *  dotProductResult ;
	specular *= c_LightSpecularIntensity * c_specularColor * pointSpecularFactor;
	ambient *= (1.0 - pointLightDot );
 #endif// POINT_LIGHT

// Light aportation
	diffuse = c_LightModelIntensity * c_diffuseColor * normDotLight;
	specular = c_LightSpecularIntensity * c_specularColor * specularFactor;
	ambient = c_LightAmbienIntensity* (1.0 - normDotLight);


////////////////////////////////////
//  SPOT_LIGHT
////////////////////////////////////
 #if SPOT_LIGHT || ALL_SHADERS 
	diffuse += c_LightModelIntensity * c_spotColor * SpotNormalDotLightWS;
	specular += c_LightSpecularIntensity * c_specularColor * SpotSpecularFactor;
	ambient *= (1.0 - SpotNormalDotLightWS);
 #endif // SPOT_LIGHT 
output.Color.rgba = float4( ambient.rgb + diffuse.rgb + specular.rbg ,1.0f);
#endif//PIXEL_LIGHT
    
  return output;
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 PS( PS_INPUT input ) : SV_Target
{
#if PIXEL_LIGHT
	// color light values 
	float4 ambient = float4(0.0f,0.0f,0.0f,0.0f);
	float4 diffuse= float4(0.0f,0.0f,0.0f,0.0f);
	float4 specular = float4(0.0f,0.0f,0.0f,0.0f);

// used to store the result of any dot product from the equations
	float dotProductResult = float(0.0f);
 input.NormWs  = txNormal.Sample(samLinear,input.Tex);
 input.NormWs = mul(float4(input.NormWs,1.0f),input.model);
  
    // find out which pixels are being hit by 
    // the light 
  float lightDirDotNormal = clamp(dot(-c_LightDir.xyz, input.NormWs),0.0f,1.0f);
  /* finds all the places where the object was not lit by the light*/
  float unlitArea = (1.0f - lightDirDotNormal);

  ambient = (c_AmbienColor * c_LightAmbienIntensity) * unlitArea;  

  float3 ViewPosWs = (mul(c_viewPosition.xyzw , input.model));

	float3 normViewDir = normalize(input.PosWs.xyz  - c_viewPosition.xyz);
	float3 normLightDir = normalize(c_LightDir);

	float distance = float(0.0f);

	float pointLightDot = float(1.0f);

#if POINT_LIGHT || ALL_SHADERS

	// getting a vector that point to the model
    float3 pointLightDirWs = -normalize(input.PosWs.xyz - c_LightPos.xyz);//mul(c_LightPos.xyzw,input.model));
		float3 pointViewDir = pointLightDirWs;
		distance = length( input.PosWs.xyz -(c_LightPos.xyzw));
		// checking what is going to be illuminated
		float pointNormalDotLightWS = max(0.0f, dot( pointLightDirWs.xyz, input.NormWs.xyz)) * (c_LightPointRadius / distance);
		
#endif// POINT_LIGHT

#if SPOT_LIGHT || ALL_SHADERS //SPOT_LIGHT

		float3 normSpotViewDir = -normalize(input.PosWs.xyz - c_viewPosition.xyz);
		float3 normSpotLightDir = -normalize(c_SpotLightDir.xyz);

		float3 SpotDirToVertex = -normalize(input.PosWs.xyz - c_viewPosition.xyz);
		float Theta = dot(SpotDirToVertex, normSpotLightDir.xyz);
		float Spot = Theta - cos(c_spotBeta * 0.5);
		Spot = max(0.0, Spot / (cos(c_spotAlpha * 0.5) - cos(c_spotBeta * 0.5)));

		distance = length(input.PosWs.xyz - c_viewPosition.xyz);
		float SpotNormalDotLightWS = max(0.0, dot(normSpotLightDir, input.NormWs.xyz) * Spot) * (c_spotRadiuos / distance);

#endif//SPOT_LIGHT

 #if BLIN || ALL_SHADERS 
		// basically a cheaper way of getting the reflection of a surface 
		float3 HalfVector = normalize(-normLightDir + -normViewDir.xyz );
		// find out how much 
		float SimiReflect = dot(HalfVector,input.NormWs.xyz);
	  pointLightDot = SimiReflect;  
		
    float specularFactor = pow( SimiReflect,c_LightSpecularIntensity);
    specular = (specularFactor *  c_LightSpecularIntensity * lightDirDotNormal) * c_specularColor ;

		#if POINT_LIGHT || ALL_SHADERS 
			HalfVector = normalize( pointViewDir.xyz + pointLightDirWs.xyz);
		  SimiReflect = max(0.0f, dot(input.NormWs.xyz, HalfVector.xyz));
      pointLightDot =SimiReflect;
			float pointSpecularFactor = pow(SimiReflect, c_LightSpecularPower) * pointNormalDotLightWS;
		#endif

		#if SPOT_LIGHT ||  ALL_SHADERS 
			HalfVector = normalize(normSpotViewDir.xyz + normSpotLightDir.xyz); 
			SimiReflect = max(0.0f, dot(input.NormWs.xyz, HalfVector.xyz));
			float SpotSpecularFactor = pow( SimiReflect , c_LightSpecularPower) * SpotNormalDotLightWS;
		#endif//SPOT_LIGHT

 #else// PHONG

		float3 psReflect = normalize(reflect(normViewDir.xyz,input.NormWs));
    // checking for what reflects  back at as 
    float viewDotReflect = max(dot(normViewDir.xyz, psReflect),0.0);
		
    float specularFactor = pow(viewDotReflect,c_LightSpecularIntensity);
    specular = (specularFactor *  c_LightSpecularIntensity * lightDirDotNormal) * c_specularColor ;

		#if POINT_LIGHT || ALL_SHADERS 
			psReflect = normalize(reflect(-pointLightDirWs.xyz, input.NormWs.xyz));
		//checking for the reflection of the point light  
			viewDotReflect = max(0.0f, dot(pointViewDir, psReflect));
			dotProductResult  = viewDotReflect;

		float pointSpecularFactor = pow(psReflect, c_LightSpecularPower) * pointNormalDotLightWS;
		#endif //POINT_LIGHT 

	#if  SPOT_LIGHT || ALL_SHADERS 
			psReflect = normalize(reflect(-normSpotLightDir.xyz, input.NormWs.xyz));
			viewDotReflect = max(0.0f, dot(normSpotViewDir.xyz, psReflect));
			float SpotSpecularFactor = pow(viewDotReflect, c_LightSpecularPower) * SpotNormalDotLightWS;
	#endif // SPOT_LIGHT

 #endif//BLIN
////////////////////////////////////
// POINT LIGHT 
////////////////////////////////////
#if POINT_LIGHT || ALL_SHADERS
	diffuse += c_LightModelIntensity * c_pointColor *  dotProductResult ;
	specular *= c_LightSpecularIntensity * c_specularColor * pointSpecularFactor;
	ambient *= (1.0 - pointLightDot );
#endif// POINT_LIGHT

////////////////////////////////////
//  SPOT_LIGHT
////////////////////////////////////
#if SPOT_LIGHT || ALL_SHADERS 
	diffuse += c_LightModelIntensity * c_spotColor * SpotNormalDotLightWS;
	specular += c_LightSpecularIntensity * c_specularColor * SpotSpecularFactor;
	ambient *= (1.0 - SpotNormalDotLightWS);
#endif // SPOT_LIGHT 

   // color the pixels that are bing hit by the light  
   // * lightDirDotNormal;  txDiffuse.Sample(samLinear , input.Tex)  ; 
	diffuse += saturate( txDiffuse.Sample(samLinear,input.Tex) * c_diffuseColor); //* lightDirDotNormal;

  return diffuse + ambient + specular;
#elif PIXEL_LIGHT == 0
return txDiffuse.Sample(samLinear,input.Tex) * input.Color;
#endif // PIXEL_LIGHT
}
