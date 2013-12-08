//
//  ROTOShaderLoader.h
//  Mush
//
//  Created by Mike Rotondo on 12/8/13.
//  Copyright (c) 2013 Rototyping. All rights reserved.
//

#import <Foundation/Foundation.h>

enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

@interface ROTOShaderLoader : NSObject

+ (GLuint)loadShaders;

@end
