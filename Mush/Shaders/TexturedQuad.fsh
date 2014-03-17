//
//  Shader.fsh
//  Mush
//
//  Created by Mike Rotondo on 12/2/13.
//  Copyright (c) 2013 Rototyping. All rights reserved.
//

varying lowp vec2 vTexCoords;
uniform sampler2D uTexture;

void main()
{
    lowp vec4 color = texture2D(uTexture, vTexCoords);
    gl_FragColor = color;
}
