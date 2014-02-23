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
    
    // Test test test
    texValue = lowp vec4(1.0);
    
    gl_FragColor = lowp vec4(1.0, 0.5, 0.0, 1.0) * texValue;
}
