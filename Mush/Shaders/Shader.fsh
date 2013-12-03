//
//  Shader.fsh
//  Mush
//
//  Created by Mike Rotondo on 12/2/13.
//  Copyright (c) 2013 Rototyping. All rights reserved.
//

#version 300 es

in lowp vec4 colorVarying;

out lowp vec4 fragColor;

void main()
{
    fragColor = colorVarying;
}
