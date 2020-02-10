// Based on this shader on shadertoy: https://www.shadertoy.com/view/tdj3W3
Shader "Unlit/CurlNoiseTransition"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		iChannel0 ("Texture", 2D) = "whtie" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

			sampler2D iChannel0;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

			float3 mod289(float3 x) {
				return x - floor(x*(1.0 / 289.0)) * 289.0;
			}

			float4 mod289(float4 x) {
				return x - floor(x*(1.0 / 289.0)) * 289.0;
			}

			float4 permute(float4 x) {
				return mod289(((x*34.0) + 1.0)*x);
			}

			float4 taylorInvSqrt(float4 r) {
				// TODO
				return 1.79284291400159 - 0.85373472095314 * r;
			}

			float snoise(float3 v) {
				static const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);
				static const float4 D = float4(0.0, 0.5, 1.0, 2.0);

				// First corner
				float3 i = floor(v + dot(v, C.yyy));
				float3 x0 = v - i + dot(i, C.xxx);

				// other corners
				float3 g = step(x0.yzx, x0.xyz);
				float3 l = 1.0 - g;
				float3 i1 = min(g.xyz, l.zxy);
				float3 i2 = max(g.xyz, l.zxy);

				float3 x1 = x0 - i1 + C.xxx;
				float3 x2 = x0 - i2 + C.yyy;
				float3 x3 = x0 - D.yyy;

				// Permutations
				i = mod289(i);
				float4 p = permute(permute(permute(
					i.z + float4(0.0, i1.z, i2.z, 1.0))
					+ i.y + float4(0.0, i1.y, i2.y, 1.0))
					+ i.x + float4(0.0, i1.x, i2.x, 1.0));

				// Gradients: 7x7 points over a square, mapped onto an octahedron,
				// The ring size 17 * 17 = 289 is close to a multple of 49 (49 * 6 = 294)
				float n_ = 0.142857142857; // 1.0/7.0
				float3 ns = n_ * D.wyz - D.xzx;

				float4 j = p - 49.0 * floor(p * ns.z * ns.z);

				float4 x_ = floor(j * ns.z);
				float4 y_ = floor(j - 7.0 * x_);

				float4 x = x_ * ns.x + ns.yyyy;
				float4 y = y_ * ns.x + ns.yyyy;
				float4 h = 1.0 - abs(x) - abs(y);

				float4 b0 = float4(x.xy, y.xy);
				float4 b1 = float4(x.zw, y.zw);

				float4 s0 = floor(b0) * 2.0 + 1.0;
				float4 s1 = floor(b1) * 2.0 + 1.0;
				float4 sh = -step(h, float4(0.0, 0.0, 0.0, 0.0));

				float4 a0 = b0.xzyw + s0.xzyw*sh.xxyy;
				float4 a1 = b1.xzyw + s1.xzyw*sh.zzww;

				float3 p0 = float3(a0.xy, h.x);
				float3 p1 = float3(a0.zw, h.y);
				float3 p2 = float3(a1.xy, h.z);
				float3 p3 = float3(a1.zw, h.w);

				// normalize gradients
				float4 norm = taylorInvSqrt(float4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
				p0 *= norm.x;
				p1 *= norm.y;
				p2 *= norm.z;
				p3 *= norm.w;

				// Mix final noise value
				float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
				m = m * m;
				return 42.0 * dot(m * m, float4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
			}

			float3 curlNoise(float3 p) {
				static const float e = 0.1;

				float n1 = snoise(float3(p.x, p.y + e, p.z));
				float n2 = snoise(float3(p.x, p.y - e, p.z));
				float n3 = snoise(float3(p.x, p.y, p.z + e));
				float n4 = snoise(float3(p.x, p.y, p.z + e));
				float n5 = snoise(float3(p.x + e, p.y, p.z));
				float n6 = snoise(float3(p.x - e, p.y, p.z));

				float x = n2 - n1 - n4 + n3;
				float y = n4 - n3 - n6 + n5;
				float z = n6 - n5 - n2 + n1;

				static const float divisor = 1.0 / (2.0 * e);
				return normalize(float3(x, y, z) * divisor);
			}

            fixed4 frag (v2f i) : SV_Target
            {
                // Normalized pixel coordinates (from 0 to 1)
				float2 uv = i.uv.xy; // fragCoord/iResolution.xy
				float f = sin(_Time.y) * 0.5 + 0.5;
				float3 curl = curlNoise(float3(uv, 1.) * 5. + _Time.y) / 1.;

				float4 t0 = tex2D(iChannel0, float2(uv.x, uv.y + f * (curl.x)));
				float4 t1 = float4(0., 0., 0., 0.);

				// Time varying pixel color
				uv.x += curl.x;
				// Output to screen
				return lerp(t0, t1, f);
				// note: colors don't overlap vec4(vec3(curl.x, curl.y, curl.z), 1.0)
            }
            ENDCG
        }
    }
}
