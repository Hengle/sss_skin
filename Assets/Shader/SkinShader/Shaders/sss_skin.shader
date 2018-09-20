Shader "Custom/sss_skin" {
  Properties {
    _Color ("Color", Color) = (1,1,1,1)
    _MainTex ("Albedo (RGB)", 2D) = "white" {}
    _BumpMap("Normal Map", 2D) = "bump" {}
    _NormalScale("Normal Scale", float) = 1
    _SpecularMap("Specular Map", 2D) = "white"{}
    _HeightMap("Height Map", 2D) = "black"{}
    _Glossiness ("Smoothness", Range(0,1)) = 0.5
    _OcclusionMap("Occlusion Map", 2D) = "white"{}
    _Occlusion("Occlusion Scale", Range(0,1)) = 1
    _SpecularColor("Specular Color",Color) = (0.2,0.2,0.2,1)
    _EmissionColor("Emission Color", Color) = (0,0,0,1)
    _VertexScale("Vertex Scale", Range(-3,3)) = 0.1
    _VertexOffset("Vertex Offset", float) = 0
    _DetailAlbedo("Detail Albedo(RGB) Mask(A)", 2D) = "black"{}
    _AlbedoBlend("Albedo Blend Rate", Range(0,1)) = 0.3
    _DetailBump("Detail Bump(RGB) Mask(A)", 2D) = "bump"{}
    _BumpBlend("Bump Blend Rate", Range(0,1)) = 0.3
    _RampTex("Ramp light texture", 2D) = "white"{}
    _BloodValue("Blood Value", Range(0.01, 1)) = 0.5
    _Power("Power of SSS", Range(0.1,10)) = 1
    _SSColor("SSS Color", Color) = (1,1,1,1)
    _Thickness("Thickness", float) = 1
    _MinDistance("Min SSS transparent Distance", Range(0,2)) = 0.001
  }

  SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
    CGINCLUDE

    #include "UnityShaderVariables.cginc"
    #include "UnityShaderUtilities.cginc"
    #include "UnityCG.cginc"
    #include "Lighting.cginc"
    #include "UnityPBSLighting.cginc"
    #include "UnityMetaPass.cginc"
    #include "AutoLight.cginc"
    #pragma shader_feature USE_FILTER
    #pragma shader_feature USE_NORMAL
    #pragma shader_feature USE_SPECULAR
    #pragma shader_feature USE_VERTEX
    #pragma shader_feature USE_OCCLUSION
    #pragma shader_feature USE_ALBEDO
    #pragma shader_feature USE_DETAILALBEDO
    #pragma shader_feature USE_DETAILNORMAL

    #ifdef POINT
    #define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) \
        unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
        float shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        float destName = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL * shadow;
    #endif

    #ifdef SPOT
    #define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) \
        unityShadowCoord4 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)); \
        float shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        float destName = step(0,lightCoord.z) * UnitySpotCookie(lightCoord) * UnitySpotAttenuate(lightCoord.xyz) * shadow;
    #endif

    #ifdef DIRECTIONAL
        #define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) float destName = UNITY_SHADOW_ATTENUATION(input, worldPos);
    #endif

    #ifdef POINT_COOKIE
    #define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) \
        unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
        float shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        float destName = tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL * texCUBE(_LightTexture0, lightCoord).w * shadow;
    #endif

    #ifdef DIRECTIONAL_COOKIE
    #define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) \
        unityShadowCoord2 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xy; \
        float shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        float destName = tex2D(_LightTexture0, lightCoord).w * shadow;
    #endif

		struct Input {
			float2 uv_MainTex;
			#if USE_DETAILALBEDO
			float2 uv_DetailAlbedo;
			#endif
			#if USE_DETAILNORMAL
			float2 uv_DetailNormal;
			#endif
		};
		
    float4 _SpecularColor;
    float4 _EmissionColor;
		float _HeightScale;
		float _NormalScale;
		float _Occlusion;
		float _VertexScale;
		float _VertexOffset;
		float _BloodValue;
		float _Power;
		float _Thickness;
		float4 _SSColor;
		float _MinDistance;
		sampler2D _DetailAlbedo;
		float _AlbedoBlend;
		sampler2D _DetailBump;
		float _BumpBlend;
		float4 _DetailAlbedo_ST;
		float4 _DetailBump_ST;
		float4 _FrustArray[4];

		sampler2D _BumpMap;
		sampler2D _SpecularMap;
		sampler2D _HeightMap;
		sampler2D _OcclusionMap;
		sampler2D _RampTex;
		sampler2D _MainTex;
		uniform sampler2D _CullFrontDepthTex;
		half _Glossiness;
		float4 _Color;

		inline void surf (Input IN, inout SurfaceOutputStandardSpecular o) {
			float2 uv = IN.uv_MainTex;
			#if USE_ALBEDO
			float4 c = tex2D (_MainTex, uv) * _Color;

			#if USE_DETAILALBEDO
			float4 dA = tex2D(_DetailAlbedo, IN.uv_DetailAlbedo);
			c.rgb = lerp(c.rgb, dA.rgb, _AlbedoBlend);
			#endif
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			#else
			#if USE_DETAILALBEDO
			float4 dA = tex2D(_DetailAlbedo, IN.uv_DetailAlbedo);
			o.Albedo.rgb = lerp(1, dA.rgb, _AlbedoBlend) * _Color;
			#else
			o.Albedo = _Color.rgb;
			o.Alpha = _Color.a;
			#endif
			#endif

			#if USE_OCCLUSION
			o.Occlusion = lerp(1, tex2D(_OcclusionMap, IN.uv_MainTex).r, _Occlusion);
			#else
			o.Occlusion = 1;
			#endif

			#if USE_SPECULAR
			float4 spec = tex2D(_SpecularMap, IN.uv_MainTex);
			o.Specular = _SpecularColor  * spec.rgb;
			o.Smoothness = _Glossiness * spec.a;
			#else
			o.Specular = _SpecularColor;
			o.Smoothness = _Glossiness;
			#endif

			#if USE_NORMAL
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
			#if USE_DETAILNORMAL
			float4 dN =  tex2D(_DetailBump,IN.uv_DetailNormal);
			o.Normal = lerp(o.Normal, UnpackNormal(dN), _BumpBlend);
			#endif
			o.Normal.xy *= _NormalScale;

			#else
			o.Normal = float3(0,0,1);
			#endif
			#if UNITY_PASS_FORWARDBASE
			o.Emission = _EmissionColor;
			#endif
		}


    inline float3 SubTransparentColor(float3 lightDir, float3 viewDir, float3 lightColor, float3 pointDepth){
      float VdotH = pow(saturate(dot(viewDir, -lightDir) + 0.5), _Power);
      return lightColor * VdotH * _SSColor.rgb * pointDepth;
    }

    inline void vert(inout appdata_full v){
      v.vertex.xyz += v.normal *( (tex2Dlod(_HeightMap, v.texcoord).r - 0.5) * _VertexScale +   _VertexOffset);
    }


    inline float3 BloodColor(float3 normal, float3 lightDir){
      float NdotL = dot(normal, lightDir) * 0.5 + 0.5;
      return tex2D(_RampTex, float2(NdotL - 0.0, _BloodValue));
    }

    ENDCG

    Pass {
      Name "FORWARD"
      Tags { "LightMode" = "ForwardBase" }

      CGPROGRAM
      #pragma vertex vert_surf
      #pragma fragment frag_surf
      #pragma target 3.0

      #pragma multi_compile_fog
      #pragma multi_compile_fwdbase

      #if !defined(INSTANCING_ON)
      #define UNITY_PASS_FORWARDBASE

      // no lightmaps:
      #ifndef LIGHTMAP_ON
      struct v2f_surf {
        UNITY_POSITION(pos);
        float2 pack0 : TEXCOORD0; // _MainTex
        float4 tSpace0 : TEXCOORD1;
        float4 tSpace1 : TEXCOORD2;
        float4 tSpace2 : TEXCOORD3;

        #if UNITY_SHOULD_SAMPLE_SH
        half3 sh : TEXCOORD4; // SH
        #endif
        UNITY_SHADOW_COORDS(5)
        UNITY_FOG_COORDS(6)
        #if SHADER_TARGET >= 30
        float4 lmap : TEXCOORD7;
        #endif

        #if USE_DETAILALBEDO
        float2 pack1 : TEXCOORD8;
        #endif

        #if USE_DETAILNORMAL
        float2 pack2 : TEXCOORD9;
        #endif
        float3 worldViewDir : TEXCOORD10;
        float3 lightDir : TEXCOORD11;
        float4 screenPos : TEXCOORD12;
      };
      #endif
      // with lightmaps:
      #ifdef LIGHTMAP_ON
      struct v2f_surf {
        UNITY_POSITION(pos);
        float2 pack0 : TEXCOORD0; // _MainTex
        float4 tSpace0 : TEXCOORD1;
        float4 tSpace1 : TEXCOORD2;
        float4 tSpace2 : TEXCOORD3;

        float4 lmap : TEXCOORD4;
        UNITY_SHADOW_COORDS(5)
        UNITY_FOG_COORDS(6)


          #if USE_DETAILALBEDO
        float2 pack1 : TEXCOORD7;
        #endif

        #if USE_DETAILNORMAL
        float2 pack2 : TEXCOORD8;
        #endif
        float3 worldViewDir : TEXCOORD9;
        float3 lightDir : TEXCOORD10;
        float4 screenPos : TEXCOORD11;
      };
      #endif
      float4 _MainTex_ST;

      // vertex shader
      inline v2f_surf vert_surf (appdata_full v) {
        UNITY_SETUP_INSTANCE_ID(v);
        v2f_surf o;
        UNITY_INITIALIZE_OUTPUT(v2f_surf,o);
      
        o.pos = UnityObjectToClipPos(v.vertex);
        o.screenPos = ComputeScreenPos(o.pos);
        o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
        float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
        o.worldViewDir = (UnityWorldSpaceViewDir(worldPos));
        float3 worldNormal = UnityObjectToWorldNormal(v.normal);
        float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
        float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
        float3 worldBinormal = cross(worldNormal, worldTangent) * tangentSign;
        #if USE_DETAILALBEDO
        o.pack1 = TRANSFORM_TEX(v.texcoord,_DetailAlbedo);
        #endif
        #if USE_DETAILNORMAL
        o.pack2 = TRANSFORM_TEX(v.texcoord, _DetailBump);
        #endif
        o.tSpace0 = (float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x));
        o.tSpace1 = (float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y));
        o.tSpace2 = (float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z));
          
        #ifdef DYNAMICLIGHTMAP_ON
        o.lmap.zw = v.texcoord2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
        #endif
        #ifdef LIGHTMAP_ON
        o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
        #endif

        // SH/ambient and vertex lights
        #ifndef LIGHTMAP_ON
          #if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
            o.sh = 0;
            // Approximated illumination from non-important point lights
            #ifdef VERTEXLIGHT_ON
              o.sh += Shade4PointLights (
                unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                unity_4LightAtten0, worldPos, worldNormal);
            #endif
            o.sh = ShadeSHPerVertex (worldNormal, o.sh);
          #endif
        #endif // !LIGHTMAP_ON

        UNITY_TRANSFER_SHADOW(o,v.texcoord1.xy); // pass shadow coordinates to pixel shader
        UNITY_TRANSFER_FOG(o,o.pos); // pass fog coordinates to pixel shader
          #ifndef USING_DIRECTIONAL_LIGHT
          o.lightDir = (UnityWorldSpaceLightDir(worldPos));
        #else
          o.lightDir = _WorldSpaceLightPos0.xyz;
        #endif
        return o;
      }


      // fragment shader
    inline float4 frag_surf (v2f_surf IN) : SV_Target {
      UNITY_SETUP_INSTANCE_ID(IN);
      // prepare and unpack data
      Input surfIN;
      UNITY_INITIALIZE_OUTPUT(Input,surfIN);
      surfIN.uv_MainTex.x = 1.0;
      
      surfIN.uv_MainTex = IN.pack0.xy;
      #if USE_DETAILALBEDO
      surfIN.uv_DetailAlbedo = IN.pack1;
      #endif

      #if USE_DETAILNORMAL
      surfIN.uv_DetailNormal = IN.pack2;
      #endif
      float3 worldPos = float3(IN.tSpace0.w, IN.tSpace1.w, IN.tSpace2.w);
      float3 lightDir = normalize(IN.lightDir);
      float3 worldViewDir = normalize(IN.worldViewDir);
      #ifdef UNITY_COMPILER_HLSL
      SurfaceOutputStandardSpecular o = (SurfaceOutputStandardSpecular)0;
      #else
      SurfaceOutputStandardSpecular o;
      #endif
      float3x3 wdMatrix= float3x3(  normalize(IN.tSpace0.xyz),  normalize(IN.tSpace1.xyz),  normalize(IN.tSpace2.xyz));
      // call surface function
      surf (surfIN, o);

      // compute lighting & shadowing factor
      UNITY_LIGHT_ATTENUATION(atten, IN, worldPos)
      float4 c = 0;

      o.Normal = normalize(mul(wdMatrix, o.Normal));
      float fragDepth = length(worldPos - _WorldSpaceCameraPos);
      float backDepth = DecodeFloatRGBA(tex2Dproj(_CullFrontDepthTex, IN.screenPos)) * 255;
      float thickness = saturate(1 - max(backDepth - fragDepth, _MinDistance) * _Thickness);

      // Setup lighting environment
      UnityGI gi;
      UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
      gi.light.color = _LightColor0.rgb * atten;
      float3 bloodColor = BloodColor(o.Normal, lightDir) * o.Albedo * gi.light.color;
      o.Albedo *= 0;
      gi.light.dir = lightDir;
      float3 transparentColor = SubTransparentColor(lightDir, worldViewDir,  _LightColor0.rgb, thickness);
      // Call GI (lightmaps/SH/reflections) lighting function
      UnityGIInput giInput;
      UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
      giInput.light = gi.light;
      giInput.worldPos = worldPos;
      giInput.worldViewDir = worldViewDir;
      giInput.atten = atten;
      #if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
        giInput.lightmapUV = IN.lmap;
      #else
        giInput.lightmapUV = 0.0;
      #endif
      #if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
        giInput.ambient = IN.sh;
      #else
        giInput.ambient.rgb = 0.0;
      #endif
      giInput.probeHDR[0] = unity_SpecCube0_HDR;
      giInput.probeHDR[1] = unity_SpecCube1_HDR;
      #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
        giInput.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
      #endif
      #ifdef UNITY_SPECCUBE_BOX_PROJECTION
        giInput.boxMax[0] = unity_SpecCube0_BoxMax;
        giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
        giInput.boxMax[1] = unity_SpecCube1_BoxMax;
        giInput.boxMin[1] = unity_SpecCube1_BoxMin;
        giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
      #endif
      LightingStandardSpecular_GI(o, giInput, gi);

      // realtime lighting: call lighting function
      c += LightingStandardSpecular (o, worldViewDir, gi);
      c.rgb += o.Emission + bloodColor + transparentColor;
      UNITY_APPLY_FOG(IN.fogCoord, c);
      UNITY_OPAQUE_ALPHA(c.a);
      return c;
    }

      #endif
      ENDCG
    }

    Pass {
      Name "FORWARD"
      Tags { "LightMode" = "ForwardAdd" }
      ZWrite Off Blend One One

      CGPROGRAM
      #pragma vertex vert_surf
      #pragma fragment frag_surf
      #pragma target 3.0

      #pragma multi_compile_fog
      #pragma skip_variants INSTANCING_ON
      #pragma multi_compile_fwdadd_fullshadows

      #if !defined(INSTANCING_ON)
      #define UNITY_PASS_FORWARDADD

      struct v2f_surf {
        UNITY_POSITION(pos);
        float2 pack0 : TEXCOORD0; // _MainTex
        float3 tSpace0 : TEXCOORD1;
        float3 tSpace1 : TEXCOORD2;
        float3 tSpace2 : TEXCOORD3;
        float3 worldPos : TEXCOORD4;
        UNITY_SHADOW_COORDS(5)
        UNITY_FOG_COORDS(6)

        #if USE_DETAILALBEDO
        float2 pack1 : TEXCOORD7;
        #endif

        #if USE_DETAILNORMAL
        float2 pack2 : TEXCOORD8;
        #endif
        float3 worldViewDir : TEXCOORD9;
        float3 lightDir : TEXCOORD10;
        float4 screenPos : TEXCOORD11;
      };
      float4 _MainTex_ST;

      // vertex shader
      inline v2f_surf vert_surf (appdata_full v) {
          UNITY_SETUP_INSTANCE_ID(v);
          v2f_surf o;
          UNITY_INITIALIZE_OUTPUT(v2f_surf,o);
        
          o.pos = UnityObjectToClipPos(v.vertex);
          o.screenPos = ComputeScreenPos(o.pos);
          o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
          #if USE_DETAILALBEDO
          o.pack1 = TRANSFORM_TEX(v.texcoord,_DetailAlbedo);
          #endif
          #if USE_DETAILNORMAL
          o.pack2 = TRANSFORM_TEX(v.texcoord, _DetailBump);
          #endif
          float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
          o.worldViewDir = (UnityWorldSpaceViewDir(worldPos));
          float3 worldNormal = UnityObjectToWorldNormal(v.normal);
          float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
          float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
          float3 worldBinormal = cross(worldNormal, worldTangent) * tangentSign;
          o.tSpace0 = (float3(worldTangent.x, worldBinormal.x, worldNormal.x));
          o.tSpace1 = (float3(worldTangent.y, worldBinormal.y, worldNormal.y));
          o.tSpace2 = (float3(worldTangent.z, worldBinormal.z, worldNormal.z));
              
          o.worldPos = worldPos;
              #ifndef USING_DIRECTIONAL_LIGHT
            o.lightDir = (UnityWorldSpaceLightDir(worldPos));
          #else
            o.lightDir = _WorldSpaceLightPos0.xyz;
          #endif
          UNITY_TRANSFER_SHADOW(o,v.texcoord1.xy); // pass shadow coordinates to pixel shader
          UNITY_TRANSFER_FOG(o,o.pos); // pass fog coordinates to pixel shader
          return o;
        }

        // fragment shader
        inline float4 frag_surf (v2f_surf IN) : SV_Target {
          UNITY_SETUP_INSTANCE_ID(IN);
          // prepare and unpack data
          Input surfIN;
          UNITY_INITIALIZE_OUTPUT(Input,surfIN);
          surfIN.uv_MainTex.x = 1.0;
          
          surfIN.uv_MainTex = IN.pack0.xy;
            #if USE_DETAILALBEDO
          surfIN.uv_DetailAlbedo = IN.pack1;
          #endif

          #if USE_DETAILNORMAL
          surfIN.uv_DetailNormal = IN.pack2;
          #endif
          float3 worldPos = (IN.worldPos);
          float3 lightDir = normalize(IN.lightDir);
          float3 worldViewDir = normalize(IN.worldViewDir);
          #ifdef UNITY_COMPILER_HLSL
          SurfaceOutputStandardSpecular o = (SurfaceOutputStandardSpecular)0;
          #else
          SurfaceOutputStandardSpecular o;
          #endif
          float3x3 wdMatrix= float3x3(  normalize(IN.tSpace0.xyz),  normalize(IN.tSpace1.xyz),  normalize(IN.tSpace2.xyz));
          // call surface function
          surf (surfIN, o);
          UNITY_LIGHT_ATTENUATION(atten, IN, worldPos)
          float4 c = 0;

          o.Normal = normalize(mul(wdMatrix, o.Normal));
          float fragDepth = length(worldPos - _WorldSpaceCameraPos);
          float backDepth = DecodeFloatRGBA(tex2Dproj(_CullFrontDepthTex, IN.screenPos)) * 255;
          float thickness = saturate(1 - max(backDepth - fragDepth, _MinDistance) * _Thickness);
          // Setup lighting environment
          UnityGI gi;
          UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
          gi.light.color = _LightColor0.rgb * atten;
          gi.light.dir = lightDir;
          float3 transparentColor = SubTransparentColor(lightDir, worldViewDir,  _LightColor0.rgb, thickness);
          float3 bloodColor = BloodColor(o.Normal, lightDir) * o.Albedo * gi.light.color;
          o.Albedo *= 0.04;
          c += LightingStandardSpecular (o, worldViewDir, gi);
          c.rgb += bloodColor + transparentColor;
          c.a = 0.0;
          UNITY_APPLY_FOG(IN.fogCoord, c); // apply fog
          UNITY_OPAQUE_ALPHA(c.a);
          return c;
        }

        #endif
        ENDCG
      }

      Pass {
        Name "ShadowCaster"
        Tags { "LightMode" = "ShadowCaster" }
        ZWrite On ZTest LEqual

        CGPROGRAM
        // compile directives
        #pragma vertex vert_surf
        #pragma fragment frag_surf
        #pragma target 3.0

        #pragma skip_variants FOG_LINEAR FOG_EXP FOG_EXP2
        #pragma multi_compile_shadowcaster

        #if !defined(INSTANCING_ON)
        #define UNITY_PASS_SHADOWCASTER

        struct v2f_surf {
          V2F_SHADOW_CASTER;

          UNITY_VERTEX_INPUT_INSTANCE_ID
          UNITY_VERTEX_OUTPUT_STEREO
        };

        // vertex shader
        inline v2f_surf vert_surf (appdata_full v) {
          v2f_surf o;
          UNITY_INITIALIZE_OUTPUT(v2f_surf,o);
          TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
          return o;
        }

        // fragment shader
        inline float4 frag_surf (v2f_surf IN) : SV_Target {
          return 1;
        }
        #endif
        ENDCG
      }
    }
}