Shader "Custom/Water" {
	Properties{
		_ShellIndex("Shell Index", Float) = 0
		_ShellCount("Shell Count", Float) = 0
		_ShellLength("Shell Length", Float) = 0
		_Density("Density", Float) = 0
		_NoiseMin("Noise Min", Float) = 0
		_NoiseMax("Noise Max", Float) = 0
		_Thickness("Thickness", Float) = 0
		_Attenuation("Attenuation", Float) = 0
		_OcclusionBias("Occlusion Bias", Float) = 0
		_ShellDistanceAttenuation("Shell Distance Attenuation", Float) = 0
		_Curvature("Curvature", Float) = 0
		_DisplacementStrength("Displacement Strength", Float) = 0
		_ShellColor("Shell Color", Color) = (1,1,1,1)
		_ShellDirection("Shell Direction", Vector) = (0,0,0,0)

		}
        
	SubShader {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "RenderQueue" = "Opaque"}

		Pass {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
			// Since we can see through the shells technically, we don't want backface culling because then there will be occasional
			// mysterious random holes in the mesh and it'll look really weird
			// also backface culling is when we do not render triangles that are on the backside of a mesh, because that would be a waste
			// of resources since generally you can't see those triangles but in this case we can, so we disable the backface culling
            Cull Off

			HLSLPROGRAM

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			// These inform the shader what functions to use for the rendering pipeline, since below my vertex shader is named 'vp' then we tell the shader
			// to use 'vp' for the vertex shader and 'fp' for the fragment shader
			#pragma vertex vp
			#pragma fragment fp

			// Unity has a lot of built in useful graphics functions, all this stuff is on github which you can look at and read there aren't really any
			// docs on it lmao

			// This is the struct that holds all the data that vertices contain when being passed into the gpu, such as the initial vertex position,
			// the normal, and the uv coordinates
			struct VertexData {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
			};

			// this is called 'v2f' which I call it that cause it stands for like 'vertex to fragment' idk i think it's a cool simple name you can name it anything!!!
			// This holds all the interpolated information that is passed into the fragment shader such as the screenspace position, the uv coordinates, the interpolated normals,
			// and the world position which even though that was not initially passed in with the vertex data we can still calculate it and pass it over to the fragment shader
			// because we can send over anything to be interpolated, it doesn't have to be only what came in with the vertices
			struct v2f {
                float2 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
			};

			struct Attributes {
			    float3 positionOS : POSITION;
			    float3 normalOS : NORMAL;
			    float4 tangentOS : TANGENT;
			    float2 uv : TEXCOORD0;
			};
			struct TessellationControlPoint {
			    float3 positionWS : INTERNALTESSPOS;
			    float4 positionCS : SV_POSITION;
			    float3 normalWS : NORMAL;
			    float4 tangentWS : TANGENT;
			    float2 uv : TEXCOORD0;
			};

			
            int _ShellIndex; // This is the current shell layer being operated on, it ranges from 0 -> _ShellCount 
			int _ShellCount; // This is the total number of shells, useful for normalizing the shell index
			float _ShellLength; // This is the amount of distance that the shells cover, if this is 1 then the shells will span across 1 world space unit
			float _Density;  // This is the density of the strands, used for initializing the noise
			float _NoiseMin, _NoiseMax; // This is the range of possible hair lengths, which the hash then interpolates between 
			float _Thickness; // This is the thickness of the hair strand
			float _Attenuation; // This is the exponent on the shell height for lighting calculations to fake ambient occlusion (the lack of ambient light)
			float _OcclusionBias; // This is an additive constant on the ambient occlusion in order to make the lighting less harsh and maybe kind of fake in-scattering
			float _ShellDistanceAttenuation; // This is the exponent on determining how far to push the shell outwards, which biases shells downwards or upwards towards the minimum/maximum distance covered
			float _Curvature; // This is the exponent on the physics displacement attenuation, a higher value controls how stiff the hair is
			float _DisplacementStrength; // The strength of the displacement (very complicated)
			float3 _ShellColor; // The color of the shells (very complicated)
			float3 _ShellDirection; // The direction the shells are going to point towards, this is updated by the CPU each frame based on user input/movement
			float3 _LightDir; // The direction the shells are going to point towards, this is updated by the CPU each frame based on user input/movement


			// This is a hashing function that takes in an unsigned integer seed and shuffles it around to make it seem random
			// The output is in the range 0 to 1, so you do not have to worry about that and can easily convert it to any other
			// range you desire by multiplying the output with any number.
			float hash(uint n) {
				// integer hash copied from Hugo Elias
				n = (n << 13U) ^ n;
				n = n * (n * n * 15731U + 0x789221U) + 0x1376312589U;
				return float(n & uint(0x7fffffffU)) / float(0x7fffffff);
			}


			// This is the vertex shader which controls the output to the fragment shader, values outputted here are interpolated across triangles
			// It also handles finalizing the positions of vertices, which is why we are able to extrude our shells here in the vertex shader instead
			// of doing that on the cpu (cringe processing unit) which would be really cringe and also slow
			TessellationControlPoint vp(Attributes input) {
				TessellationControlPoint output;

			    UNITY_SETUP_INSTANCE_ID(input);
			    UNITY_TRANSFER_INSTANCE_ID(input, output);

				float shellHeight = (float)_ShellIndex / (float)_ShellCount;
				shellHeight = pow(shellHeight, _ShellDistanceAttenuation);
				float k = pow(shellHeight, _Curvature);
				
			    VertexPositionInputs posnInputs;
			    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
			    posnInputs.positionWS = TransformObjectToWorld(input.positionOS);
				posnInputs.positionWS.xyz += normalInputs.normalWS.xyz * _ShellLength * shellHeight;
				posnInputs.positionWS.xyz += _ShellDirection * k * _DisplacementStrength;
			    posnInputs.positionVS = TransformWorldToView(posnInputs.positionWS);
			    posnInputs.positionCS = TransformWorldToHClip(posnInputs.positionWS);

			    //output.positionWS = posnInputs.positionWS;
			    output.positionCS = posnInputs.positionCS;
			    output.normalWS = normalInputs.normalWS;
			    output.tangentWS = float4(normalInputs.tangentWS, input.tangentOS.w); // tangent.w containts bitangent multiplier
				output.uv = input.uv;
			    return output;
			}

			float4 fp(TessellationControlPoint i) : SV_TARGET {
				 float2 newUV = i.uv * _Density;
    
				 float2 localUV = frac(newUV) * 2 - 1;
				
				 float localDistanceFromCenter = length(localUV);
    
                 uint2 tid = newUV;
				 uint seed = tid.x + 100 * tid.y + 100 * 10;
    
                 float shellIndex = _ShellIndex;
                 float shellCount = _ShellCount;
    
                 float rand = lerp(_NoiseMin, _NoiseMax, hash(seed));
    
                 float h = shellIndex / shellCount;
    
				 int outsideThickness = (localDistanceFromCenter) > (_Thickness * (rand - h));
				
				 if (outsideThickness && _ShellIndex > 0) discard;
                 
				 float ndotl = clamp(dot(i.normalWS, _LightDir), 0.0, 1.0) * 0.5f + 0.5f;
    
				 ndotl = ndotl * ndotl;
    
				 float ambientOcclusion = pow(h, _Attenuation);
    
				 ambientOcclusion += _OcclusionBias;
    
				 ambientOcclusion = saturate(ambientOcclusion);
    

                return float4(_ShellColor * ndotl * ambientOcclusion, 1.0);
			}

			ENDHLSL
		}

		//Pass {
		//	Name"ShadowCaster"
		//				Tags
		//	{"LightMode" = "UniversalForward"
		//	}
		//				// Since we can see through the shells technically, we don't want backface culling because then there will be occasional
		//				// mysterious random holes in the mesh and it'll look really weird
		//				// also backface culling is when we do not render triangles that are on the backside of a mesh, because that would be a waste
		//				// of resources since generally you can't see those triangles but in this case we can, so we disable the backface culling
		//	Cull Off

		//				HLSLPROGRAM

		//	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

		//				// These inform the shader what functions to use for the rendering pipeline, since below my vertex shader is named 'vp' then we tell the shader
		//				// to use 'vp' for the vertex shader and 'fp' for the fragment shader
		//				#pragma vertex vp
		//				#pragma fragment fp

		//				// Unity has a lot of built in useful graphics functions, all this stuff is on github which you can look at and read there aren't really any
		//				// docs on it lmao

		//				// This is the struct that holds all the data that vertices contain when being passed into the gpu, such as the initial vertex position,
		//				// the normal, and the uv coordinates
		//	struct VertexData
		//	{
		//		float4 vertex : POSITION;
		//		float3 normal : NORMAL;
		//		float2 uv : TEXCOORD0;
		//	};

		//				// this is called 'v2f' which I call it that cause it stands for like 'vertex to fragment' idk i think it's a cool simple name you can name it anything!!!
		//				// This holds all the interpolated information that is passed into the fragment shader such as the screenspace position, the uv coordinates, the interpolated normals,
		//				// and the world position which even though that was not initially passed in with the vertex data we can still calculate it and pass it over to the fragment shader
		//				// because we can send over anything to be interpolated, it doesn't have to be only what came in with the vertices
		//	struct v2f
		//	{
		//		float2 uv : TEXCOORD0;
		//		float3 normal : TEXCOORD1;
		//		float3 worldPos : TEXCOORD2;
		//	};

		//	struct Attributes
		//	{
		//		float3 positionOS : POSITION;
		//		float3 normalOS : NORMAL;
		//		float4 tangentOS : TANGENT;
		//		float2 uv : TEXCOORD0;
		//	};
		//	struct TessellationControlPoint
		//	{
		//		float3 positionWS : INTERNALTESSPOS;
		//		float4 positionCS : SV_POSITION;
		//		float3 normalWS : NORMAL;
		//		float4 tangentWS : TANGENT;
		//		float2 uv : TEXCOORD0;
		//	};

			
		//	int _ShellIndex; // This is the current shell layer being operated on, it ranges from 0 -> _ShellCount 
		//	int _ShellCount; // This is the total number of shells, useful for normalizing the shell index
		//	float _ShellLength; // This is the amount of distance that the shells cover, if this is 1 then the shells will span across 1 world space unit
		//	float _Density; // This is the density of the strands, used for initializing the noise
		//	float _NoiseMin, _NoiseMax; // This is the range of possible hair lengths, which the hash then interpolates between 
		//	float _Thickness; // This is the thickness of the hair strand
		//	float _Attenuation; // This is the exponent on the shell height for lighting calculations to fake ambient occlusion (the lack of ambient light)
		//	float _OcclusionBias; // This is an additive constant on the ambient occlusion in order to make the lighting less harsh and maybe kind of fake in-scattering
		//	float _ShellDistanceAttenuation; // This is the exponent on determining how far to push the shell outwards, which biases shells downwards or upwards towards the minimum/maximum distance covered
		//	float _Curvature; // This is the exponent on the physics displacement attenuation, a higher value controls how stiff the hair is
		//	float _DisplacementStrength; // The strength of the displacement (very complicated)
		//	float3 _ShellColor; // The color of the shells (very complicated)
		//	float3 _ShellDirection; // The direction the shells are going to point towards, this is updated by the CPU each frame based on user input/movement
		//	float3 _LightDir; // The direction the shells are going to point towards, this is updated by the CPU each frame based on user input/movement


		//				// This is a hashing function that takes in an unsigned integer seed and shuffles it around to make it seem random
		//				// The output is in the range 0 to 1, so you do not have to worry about that and can easily convert it to any other
		//				// range you desire by multiplying the output with any number.
		//	float hash(uint n)
		//	{
		//					// integer hash copied from Hugo Elias
		//		n = (n << 13U) ^ n;
		//		n = n * (n * n * 15731U + 0x789221U) + 0x1376312589U;
		//		return float(n & uint(0x7fffffffU)) / float(0x7fffffff);
		//	}


		//				// This is the vertex shader which controls the output to the fragment shader, values outputted here are interpolated across triangles
		//				// It also handles finalizing the positions of vertices, which is why we are able to extrude our shells here in the vertex shader instead
		//				// of doing that on the cpu (cringe processing unit) which would be really cringe and also slow
		//	TessellationControlPoint vp(Attributes input)
		//	{
		//		TessellationControlPoint output;

		//		UNITY_SETUP_INSTANCE_ID(input);
		//		UNITY_TRANSFER_INSTANCE_ID(input, output);

		//		float shellHeight = (float) _ShellIndex / (float) _ShellCount;
		//		shellHeight = pow(shellHeight, _ShellDistanceAttenuation);
		//		float k = pow(shellHeight, _Curvature);
				
		//		VertexPositionInputs posnInputs;
		//		VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
		//		posnInputs.positionWS = TransformObjectToWorld(input.positionOS);
		//		posnInputs.positionWS.xyz += normalInputs.normalWS.xyz * _ShellLength * shellHeight;
		//		posnInputs.positionWS.xyz += _ShellDirection * k * _DisplacementStrength;
		//		posnInputs.positionVS = TransformWorldToView(posnInputs.positionWS);
		//		posnInputs.positionCS = TransformWorldToHClip(posnInputs.positionWS);

		//					//output.positionWS = posnInputs.positionWS;
		//		output.positionCS = posnInputs.positionCS;
		//		output.normalWS = normalInputs.normalWS;
		//		output.tangentWS = float4(normalInputs.tangentWS, input.tangentOS.w); // tangent.w containts bitangent multiplier
		//		output.uv = input.uv;
		//		return output;
		//	}

		//	float4 fp(TessellationControlPoint i) : SV_TARGET
		//	{
		//		float2 newUV = i.uv * _Density;
    
		//		float2 localUV = frac(newUV) * 2 - 1;
				
		//		float localDistanceFromCenter = length(localUV);
    
		//		uint2 tid = newUV;
		//		uint seed = tid.x + 100 * tid.y + 100 * 10;
    
		//		float shellIndex = _ShellIndex;
		//		float shellCount = _ShellCount;
    
		//		float rand = lerp(_NoiseMin, _NoiseMax, hash(seed));
    
		//		float h = shellIndex / shellCount;
    
		//		int outsideThickness = (localDistanceFromCenter) > (_Thickness * (rand - h));
				
		//		if (outsideThickness && _ShellIndex > 0)
		//			discard;
                 

		//		return 0;
		//	}

		//	ENDHLSL
		//}
	}
}