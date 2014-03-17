//
//  Shader.vsh
//  Mush
//
//  Created by Mike Rotondo on 12/2/13.
//  Copyright (c) 2013 Rototyping. All rights reserved.
//

attribute vec4 aPosition;
attribute vec2 aTexCoords;

varying lowp vec2 vTexCoords;

uniform mat4 uModelViewProjectionMatrix;

void main()
{
    vTexCoords = aTexCoords;
    gl_Position = uModelViewProjectionMatrix * aPosition;
}
