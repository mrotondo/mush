//
//  Shader.fsh
//  Mush
//
//  Created by Mike Rotondo on 12/2/13.
//  Copyright (c) 2013 Rototyping. All rights reserved.
//

varying lowp vec2 vTexCoords;

uniform sampler2D cellPositionsTexture;
uniform sampler2D metaballPositionsTexture;
uniform highp vec2 metaballPositionsTextureSize;
uniform highp float numMetaballs;

void main()
{
    highp vec3 cellPosition = texture2D(cellPositionsTexture, vTexCoords).xyz;

    highp float totalContribution = 0.0;
    highp float i = 0.0;
    highp float x = 0.0;
    highp float y = 0.0;
    while (i < numMetaballs)
    {
        y = floor(i / metaballPositionsTextureSize.x);
        x = i - y * metaballPositionsTextureSize.x;
        highp vec3 metaballPosition = texture2D(metaballPositionsTexture, vec2(x, y)).xyz;
        highp float r = distance(cellPosition, metaballPosition);
        
        highp float contribution = 1.0 / pow(r, 2.0);
        
        totalContribution = totalContribution + contribution;

        i = i + 1.0;
    }

    
    gl_FragColor = vec4(vec3(totalContribution), 1.0);
}
