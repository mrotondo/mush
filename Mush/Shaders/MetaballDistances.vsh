//
//  Shader.vsh
//  Mush
//
//  Created by Mike Rotondo on 12/2/13.
//  Copyright (c) 2013 Rototyping. All rights reserved.
//

attribute highp vec4 position;
attribute lowp vec2 texCoords;

uniform lowp mat4 modelViewProjectionMatrix;

varying lowp vec2 vTexCoords;

void main()
{
    vTexCoords = texCoords;
    gl_Position = modelViewProjectionMatrix * position;
}
