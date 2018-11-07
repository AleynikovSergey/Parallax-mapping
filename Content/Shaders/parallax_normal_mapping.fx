struct Light
{
	float3 dir;		
	float3 pos;		
	float4 ambient;
	float4 diffuse;
	float4 specular;
	float spotInnerCone;
	float spotOuterCone;	
	float radius;          
};

struct Material
{
	float4 ambient;
	float4 diffuse;
	float4 emissive;
	float4 specular;
	float shininess;
};

//-----------------------------------------------------------------------------
// Globals.
//-----------------------------------------------------------------------------

float4x4 worldMatrix;
float4x4 worldInverseTransposeMatrix;
float4x4 worldViewProjectionMatrix;

float3 cameraPos;
float4 globalAmbient;
float2 scaleBias;

Light light;
Material material;

//-----------------------------------------------------------------------------
// Textures.
//-----------------------------------------------------------------------------

texture colorMapTexture;
texture normalMapTexture;
texture heightMapTexture;

sampler2D colorMap = sampler_state
{
    Texture = <colorMapTexture>;
    MagFilter = Linear;
    MinFilter = Anisotropic;
    MipFilter = Linear;
    MaxAnisotropy = 16;
};

sampler2D normalMap = sampler_state
{
    Texture = <normalMapTexture>;
    MagFilter = Linear;
    MinFilter = Anisotropic;
    MipFilter = Linear;
    MaxAnisotropy = 16;
};

sampler2D heightMap = sampler_state
{
    Texture = <heightMapTexture>;
    MagFilter = Linear;
    MinFilter = Anisotropic;
    MipFilter = Linear;
    MaxAnisotropy = 16;
};

//-----------------------------------------------------------------------------
// Vertex Shaders.
//-----------------------------------------------------------------------------

struct VS_INPUT
{
	float3 position : POSITION;
	float2 texCoord : TEXCOORD0;
	float3 normal : NORMAL;
    float4 tangent : TANGENT;
};

struct VS_OUTPUT_DIR
{
	float4 position : POSITION;
	float2 texCoord : TEXCOORD0;
	float3 halfVector : TEXCOORD1;
	float3 lightDir : TEXCOORD2;
	float4 diffuse : COLOR0;
	float4 specular : COLOR1;
};

VS_OUTPUT_DIR VS_DirLighting(VS_INPUT IN)
{
	VS_OUTPUT_DIR OUT;
	
	//вычисление halfVector
	float3 worldPos = mul(float4(IN.position, 1.0f), worldMatrix).xyz;
	float3 lightDir = -light.dir;
	float3 viewDir = cameraPos - worldPos;
	float3 halfVector = normalize(normalize(lightDir) + normalize(viewDir));
	
	//вычисление коэффициентов матрицы	
	float3 n = mul(IN.normal, (float3x3)worldInverseTransposeMatrix);
	float3 t = mul(IN.tangent.xyz, (float3x3)worldInverseTransposeMatrix);
	float3 b = cross(n, t) * IN.tangent.w;
	float3x3 tbnMatrix = float3x3(t.x, b.x, n.x,
	                              t.y, b.y, n.y,
	                              t.z, b.z, n.z);

	//запись даных дл€ пиксельного шейдера
	OUT.position = mul(float4(IN.position, 1.0f), worldViewProjectionMatrix);
	OUT.texCoord = IN.texCoord;
	OUT.halfVector = mul(halfVector, tbnMatrix);
	OUT.lightDir = mul(lightDir, tbnMatrix);
	OUT.diffuse = material.diffuse * light.diffuse;
	OUT.specular = material.specular * light.specular;

	return OUT;
}

//-----------------------------------------------------------------------------
// Pixel Shaders.
//-----------------------------------------------------------------------------



float4 PS_DirLighting(VS_OUTPUT_DIR IN, uniform bool bParallax): COLOR
{
    float2 texCoord;
    float3 h = normalize(IN.halfVector);

    //получение высоты из heightMap
    float height = tex2D(heightMap, IN.texCoord).r; 
    //–ассчитываем координаты этой высоты 
    //x - множитель, y - смещение 
    height = height * scaleBias.x + scaleBias.y;
    //¬ычисление смещени€ трассировки вектора
    float Offset = height * h.xy;
    //»скомые текстурные координаты
    texCoord = IN.texCoord + Offset;

    float3 l = normalize(IN.lightDir);
    float3 n = normalize(tex2D(normalMap, texCoord).rgb * 2.0f - 1.0f);
    
    float diffuse = saturate(dot(n, l));
    float spec = saturate(dot(n, h));

    return (diffuse + pow(spec, 128)) * tex2D(colorMap, texCoord);
}


float4 PS_DirLightingStep(VS_OUTPUT_DIR IN, uniform bool bParallax): COLOR
{

    const float numSteps  = 20.0;                         

    float3 et = normalize(IN.halfVector);

    float   step   = 1.0 / numSteps;                     
    float2    dtex   = et.xy * scaleBias.x/ ( numSteps * et.z );
    float   height = 1.0;                                 
    float2  tex    = IN.texCoord;
    float h = tex2D(heightMap, IN.texCoord).a; 

     if ( h < height )
    {
        height -= step;
        tex    += dtex;
        h       = tex2D ( heightMap, tex ).a;

        if ( h < height )
        {
            height -= step;
            tex    += dtex;
            h       = tex2D ( heightMap, tex ).a;

            if ( h < height )
            {
                height -= step;
                tex    += dtex;
                h       = tex2D ( heightMap, tex ).a;

                if ( h < height )
                {
                    height -= step;
                    tex    += dtex;
                    h       = tex2D ( heightMap, tex ).a;

                    if ( h < height )
                    {
                        height -= step;
                        tex    += dtex;
                        h       = tex2D ( heightMap, tex ).a;

                        if ( h < height )
                    	{
	                        height -= step;
	                        tex    += dtex;
	                        h       = tex2D ( heightMap, tex ).a;

	                        if ( h < height )
		                    {
		                        height -= step;
		                        tex    += dtex;
		                        h       = tex2D ( heightMap, tex ).a;

		                        if ( h < height )
			                    {
			                        height -= step;
			                        tex    += dtex;
			                        h       = tex2D ( heightMap, tex ).a;
			                    }
		                    }
                    	}
                    }
                }
            }
        }
    }

    float3  color = tex2D(normalMap, tex).rgb;

    float3 l = normalize(IN.lightDir);
    float3 n = normalize(tex2D(normalMap, tex).rgb * 2.0f - 1.0f);
    float diffuse = saturate(dot(n, l));
    float spec = saturate(dot(n, et));

    return (diffuse + pow(spec, 128)) * tex2D(colorMap, IN.texCoord);
}

float4 PS_DirLightingRelief(VS_OUTPUT_DIR IN, uniform bool bParallax): COLOR
{

    const float numSteps  = 5.0;                       

    float3 et = normalize(IN.halfVector);

    float   step   = 1.0 / numSteps;                     
    float2    dtex   = et.xy * (scaleBias.x - 0.1) / ( numSteps * et.z ); 
    float   height = 1.0;                                 
    float2  tex    = IN.texCoord;
    float h = tex2D(heightMap, IN.texCoord).a; 

     if ( h < height )
    {
        height -= step;
        tex    += dtex;
        h       = tex2D ( heightMap, tex ).a;

        if ( h < height )
        {
            height -= step;
            tex    += dtex;
            h       = tex2D ( heightMap, tex ).a;

            if ( h < height )
            {
                height -= step;
                tex    += dtex;
                h       = tex2D ( heightMap, tex ).a;

                if ( h < height )
                {
                    height -= step;
                    tex    += dtex;
                    h       = tex2D ( heightMap, tex ).a;

                    if ( h < height )
                    {
                        height -= step;
                        tex    += dtex;
                        h       = tex2D ( heightMap, tex ).a;

                        if ( h < height )
                    	{
	                        height -= step;
	                        tex    += dtex;
	                        h       = tex2D ( heightMap, tex ).a;

	                        if ( h < height )
		                    {
		                        height -= step;
		                        tex    += dtex;
		                        h       = tex2D ( heightMap, tex ).a;

		                        if ( h < height )
			                    {
			                        height -= step;
			                        tex    += dtex;
			                        h       = tex2D ( heightMap, tex ).a;
			                    }
		                    }
                    	}	
                    }
                }
            }
        }
    }

    float2 delta = 0.5 * dtex;
    float2 mid   = tex - delta;                            

	for ( int i = 0; i < 5; i++ )
    {
        delta *= 0.5;

        if ( tex2D(heightMap, mid).a < height )
            mid += delta;
        else
            mid -= delta;
    }

    tex = mid;
                                                         
    float3  color = tex2D(normalMap, tex).rgb;

    float3 l = normalize(IN.lightDir);
    float3 n = normalize(tex2D(normalMap, tex).rgb * 2.0f - 1.0f);
    float diffuse = saturate(dot(n, l));
    float spec = saturate(dot(n, et));

    return (diffuse + pow(spec, 128)) * tex2D(colorMap, IN.texCoord);
}

float4 PS_DirLightingOclusion(VS_OUTPUT_DIR IN, uniform bool bParallax): COLOR
{

    const float numSteps  = 10.0;                         

    float3 et = normalize(IN.halfVector);

    float   step   = 1.0 / numSteps;                     
    float2    dtex   = et.xy * scaleBias.x / ( numSteps * et.z ) * 10;
    float   height = 1.0;                                 
    float2  tex    = IN.texCoord;
    float h = tex2D(heightMap, IN.texCoord).a; 

     if ( h < height )
    {
        height -= step;
        tex    += dtex;
        h       = tex2D ( heightMap, tex ).a;

        if ( h < height )
        {
            height -= step;
            tex    += dtex;
            h       = tex2D ( heightMap, tex ).a;

            if ( h < height )
            {
                height -= step;
                tex    += dtex;
                h       = tex2D ( heightMap, tex ).a;

                if ( h < height )
                {
                    height -= step;
                    tex    += dtex;
                    h       = tex2D ( heightMap, tex ).a;

                    if ( h < height )
                    {
                        height -= step;
                        tex    += dtex;
                        h       = tex2D ( heightMap, tex ).a;

                        if ( h < height )
                        {
                            height -= step;
                            tex    += dtex;
                            h       = tex2D ( heightMap, tex ).a;

                            if ( h < height )
                            {
                                height -= step;
                                tex    += dtex;
                                h       = tex2D ( heightMap, tex ).a;

                                if ( h < height )
                                {
                                    height -= step;
                                    tex    += dtex;
                                    h       = tex2D ( heightMap, tex ).a;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    float2  prev   = tex - dtex;                          
    float hPrev  = tex2D(heightMap, prev).a - (height + step);
    float hCur   = h - height;
    float weight = hCur / (hCur - hPrev );

    tex = weight * prev + (1.0 - weight) * tex;

    float3  color = tex2D(normalMap, tex).rgb;

    float3 l = normalize(IN.lightDir);
    float3 n = normalize(tex2D(normalMap, tex).rgb * 2.0f - 1.0f);
    float diffuse = saturate(dot(n, l));
    float spec = saturate(dot(n, et));

    return (diffuse + pow(spec, 128)) * tex2D(colorMap, IN.texCoord);
}

//-----------------------------------------------------------------------------
// Techniques.
//-----------------------------------------------------------------------------

technique ParallaxMapping
{
	pass
	{
		VertexShader = compile vs_2_0 VS_DirLighting();
		PixelShader = compile ps_2_0 PS_DirLighting(true);
	}
}

technique ParallaxMappingStep
{
	pass
	{
		VertexShader = compile vs_2_0 VS_DirLighting();
		PixelShader = compile ps_2_0 PS_DirLightingStep(true);
	}
}

technique ParallaxMappingRelief
{
	pass
	{
		VertexShader = compile vs_2_0 VS_DirLighting();
		PixelShader = compile ps_3_0 PS_DirLightingRelief(true);
	}
}

technique ParallaxMappingOclusion
{
    pass
    {
        VertexShader = compile vs_2_0 VS_DirLighting();
        PixelShader = compile ps_3_0 PS_DirLightingOclusion(true);
    }
}
