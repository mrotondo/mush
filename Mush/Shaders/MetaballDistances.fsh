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
uniform lowp vec2 metaballPositionsTextureSize;
uniform lowp float numMetaballs;

void main()
{
    lowp vec4 cellPosition = texture2D(cellPositionsTexture, vTexCoords);
//    lowp vec4 texValue = texture2D(dataTexture, vTexCoords);
    
    gl_FragColor = vec4(cellPosition.xyz, 1.0);
}
