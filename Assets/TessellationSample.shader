// MIT License

// Copyright (c) 2021 NedMakesGames

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// This is a shader that demonstrates tessellation techniques and little else

Shader "NedMakesGames/TessellationSample" {
    Properties{
        
		_ShellLength("Shell Length", Float) = 0
		_Density("Density", Float) = 0
		_NoiseMin("Noise Min", Float) = 0
		_NoiseMax("Noise Max", Float) = 0
		_Thickness("Thickness", Float) = 0
		_ShellDistanceAttenuation("Shell Distance Attenuation", Float) = 0
		_Curvature("Curvature", Float) = 0
		_Attenuation("Attenuation", Float) = 0
		_OcclusionBias("Occlusion Bias", Float) = 0
		_DisplacementStrength("Displacement Strength", Float) = 0
		_ShellColor("Shell Color", Color) = (1,1,1,1)
		_ShellDirection("Shell Direction", Vector) = (0,0,0,0)
		_RandomOffsetPower("Random Offset Power", Float) = 0
		_CurlPower("Curl Power", Float) = 0
		_CurlSize("Curl Size", Float) = 0
        _AlphaBase("Base Alpha", Range(0, 1)) = 1.0
        _AlphaPower("Alpha Power", Range(0.0, 10.0)) = 1.0
        _AlphaCutoff("Alpha Cutoff", Range(0.0, 1.0)) = 1.0
        
        _MainTexture("Main texture", 2D) = "white" {}
        // This keyword enum allows us to choose between calculating normals from a normal map or the height map
        [KeywordEnum(MAP, HEIGHT)] _GENERATE_NORMALS("Normal mode", Float) = 0
        // This keyword enum allows us to choose between partitioning modes. It's best to try them out for yourself
        [KeywordEnum(INTEGER, FRAC_EVEN, FRAC_ODD, POW2)] _PARTITIONING("Partition algoritm", Float) = 0
        // This allows us to choose between tessellation factor methods
        [KeywordEnum(CONSTANT, WORLD, SCREEN, WORLD_WITH_DEPTH)] _TESSELLATION_FACTOR("Tessellation mode", Float) = 0
        // This factor is applied differently per factor mode
        //  Constant: not used
        //  World: this is the ideal edge length in world units. The algorithm will try to keep all edges at this value
        //  Screen: this is the ideal edge length in screen pixels. The algorithm will try to keep all edges at this value
        //  World with depth: similar to world, except the edge length is decreased quadratically as the camera gets closer 
        _StrandCount("Strand count", Float) = 1
        _StrandComplexity("Strand complexity", Float) = 1
        // This value is added to the tessellation factor. Use if your model should be more or less tessellated by default
        _TessellationBias("Tessellation bias", Float) = 0
        // Enable this setting to multiply a vector's green color channel into the tessellation factor
        [Toggle(_TESSELLATION_FACTOR_VCOLORS)]_TessellationFactorVColors("Multiply VColor.Green in factor", Float) = 0
        // This keyword selects a tessellation smoothing method
        //  Flat: no smoothing
        //  Phong: use Phong tessellation, as described here: http://www.klayge.org/material/4_0/PhongTess/PhongTessellation.pdf'
        //  Bezier linear normals: use bezier tessellation for poistions, as described here: https://alex.vlachos.com/graphics/CurvedPNTriangles.pdf
        //  Bezier quad normals: the same as above, except it also applies quadratic smoothing to normal vectors
        [KeywordEnum(FLAT, PHONG, BEZIER_LINEAR_NORMALS, BEZIER_QUAD_NORMALS)] _TESSELLATION_SMOOTHING("Smoothing mode", Float) = 0
        // A factor to interpolate between flat and the selected smoothing method
        _TessellationSmoothing("Smoothing factor", Range(0, 1)) = 0.75
        // If enabled, multiply the vertex's red color channel into the smoothing factor
        [Toggle(_TESSELLATION_SMOOTHING_VCOLORS)]_TessellationSmoothingVColors("Multiply VColor.Red in smoothing", Float) = 0
        // A tolerance to frustum culling. Increase if triangles disappear when on screen
        _FrustumCullTolerance("Frustum cull tolerance", Float) = 0.01
        // A tolerance to back face culling. Increase if holes appear on your mesh
        _BackFaceCullTolerance("Back face cull tolerance", Float) = 0.01
    }
    SubShader{
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}

        Pass {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}


            HLSLPROGRAM
            //#pragma target 5.0 // 5.0 required for tessellation
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            // Material keywords
            #pragma shader_feature_local _PARTITIONING_INTEGER _PARTITIONING_FRAC_EVEN _PARTITIONING_FRAC_ODD _PARTITIONING_POW2
            #pragma shader_feature_local _TESSELLATION_SMOOTHING_FLAT _TESSELLATION_SMOOTHING_PHONG _TESSELLATION_SMOOTHING_BEZIER_LINEAR_NORMALS _TESSELLATION_SMOOTHING_BEZIER_QUAD_NORMALS
            #pragma shader_feature_local _TESSELLATION_FACTOR_CONSTANT _TESSELLATION_FACTOR_WORLD _TESSELLATION_FACTOR_SCREEN _TESSELLATION_FACTOR_WORLD_WITH_DEPTH
            #pragma shader_feature_local _TESSELLATION_SMOOTHING_VCOLORS
            #pragma shader_feature_local _TESSELLATION_FACTOR_VCOLORS
            #pragma shader_feature_local _GENERATE_NORMALS_MAP _GENERATE_NORMALS_HEIGHT

            #pragma vertex Vertex
            #pragma hull Hull
            #pragma domain Domain
            #pragma fragment Fragment

            #include "TessellationSample.hlsl"
            ENDHLSL
        }

        Pass {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
            HLSLPROGRAM
            //#pragma target 5.0 // 5.0 required for tessellation

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #pragma shader_feature_local _PARTITIONING_INTEGER _PARTITIONING_FRAC_EVEN _PARTITIONING_FRAC_ODD _PARTITIONING_POW2
            #pragma shader_feature_local _TESSELLATION_SMOOTHING_FLAT _TESSELLATION_SMOOTHING_PHONG _TESSELLATION_SMOOTHING_BEZIER_LINEAR_NORMALS _TESSELLATION_SMOOTHING_BEZIER_QUAD_NORMALS
            #pragma shader_feature_local _TESSELLATION_FACTOR_CONSTANT _TESSELLATION_FACTOR_WORLD _TESSELLATION_FACTOR_SCREEN _TESSELLATION_FACTOR_WORLD_WITH_DEPTH
            #pragma shader_feature_local _TESSELLATION_SMOOTHING_VCOLORS
            #pragma shader_feature_local _TESSELLATION_FACTOR_VCOLORS
            #pragma shader_feature_local _GENERATE_NORMALS_MAP _GENERATE_NORMALS_HEIGHT
            #pragma shader_feature_local _ALPHA_CUTOUT
            #pragma shader_feature_local _DOUBLE_SIDED_NORMALS

            #pragma vertex Vertex
            #pragma hull Hull
            #pragma domain Domain
            #pragma fragment FragmentShadowCaster

            #include "TessellationSample.hlsl"
            ENDHLSL
        }
            Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly" "RenderQueue" = "Transparent"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM

            #define SHADERPASS_DEPTHONLY
            //#pragma target 5.0 // 5.0 required for tessellation

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #pragma shader_feature_local _PARTITIONING_INTEGER _PARTITIONING_FRAC_EVEN _PARTITIONING_FRAC_ODD _PARTITIONING_POW2
            #pragma shader_feature_local _TESSELLATION_SMOOTHING_FLAT _TESSELLATION_SMOOTHING_PHONG _TESSELLATION_SMOOTHING_BEZIER_LINEAR_NORMALS _TESSELLATION_SMOOTHING_BEZIER_QUAD_NORMALS
            #pragma shader_feature_local _TESSELLATION_FACTOR_CONSTANT _TESSELLATION_FACTOR_WORLD _TESSELLATION_FACTOR_SCREEN _TESSELLATION_FACTOR_WORLD_WITH_DEPTH
            #pragma shader_feature_local _TESSELLATION_SMOOTHING_VCOLORS
            #pragma shader_feature_local _TESSELLATION_FACTOR_VCOLORS
            #pragma shader_feature_local _GENERATE_NORMALS_MAP _GENERATE_NORMALS_HEIGHT
            #pragma shader_feature_local _ALPHA_CUTOUT
            #pragma shader_feature_local _DOUBLE_SIDED_NORMALS

            #pragma vertex Vertex
            #pragma hull Hull
            #pragma domain Domain
            #pragma fragment FragmentDepthOnly

            #include "TessellationSample.hlsl"
            ENDHLSL
        }

            // This pass is used when drawing to a _CameraNormalsTexture texture
            Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals" "RenderQueue" = "Transparent"}

            ZWrite On
            HLSLPROGRAM

            #define SHADERPASS_DEPTHONLY
            #define SHADERPASS_DEPTHNORMALS
            //#pragma target 5.0 // 5.0 required for tessellation

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #pragma shader_feature_local _PARTITIONING_INTEGER _PARTITIONING_FRAC_EVEN _PARTITIONING_FRAC_ODD _PARTITIONING_POW2
            #pragma shader_feature_local _TESSELLATION_SMOOTHING_FLAT _TESSELLATION_SMOOTHING_PHONG _TESSELLATION_SMOOTHING_BEZIER_LINEAR_NORMALS _TESSELLATION_SMOOTHING_BEZIER_QUAD_NORMALS
            #pragma shader_feature_local _TESSELLATION_FACTOR_CONSTANT _TESSELLATION_FACTOR_WORLD _TESSELLATION_FACTOR_SCREEN _TESSELLATION_FACTOR_WORLD_WITH_DEPTH
            #pragma shader_feature_local _TESSELLATION_SMOOTHING_VCOLORS
            #pragma shader_feature_local _TESSELLATION_FACTOR_VCOLORS
            #pragma shader_feature_local _GENERATE_NORMALS_MAP _GENERATE_NORMALS_HEIGHT
            #pragma shader_feature_local _ALPHA_CUTOUT
            #pragma shader_feature_local _DOUBLE_SIDED_NORMALS

            #pragma vertex Vertex
            #pragma hull Hull
            #pragma domain Domain
            #pragma fragment FragmentDepthNormals
            #include "TessellationSample.hlsl"
            ENDHLSL
        }
    }
}
