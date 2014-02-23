//
//  Shader.fsh
//  Mush
//
//  Created by Mike Rotondo on 12/2/13.
//  Copyright (c) 2013 Rototyping. All rights reserved.
//

varying lowp vec2 vTexCoords;

uniform sampler2D dataTexture;

void main()
{
    lowp vec4 texValue = texture2D(dataTexture, vTexCoords);
    
    gl_FragColor = vec4(vec3(texValue.x), 1.0);
}
