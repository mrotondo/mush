//
//  EntityVertex.h
//  Funomenology
//
//  Created by Mike Rotondo on 1/29/14.
//  Copyright (c) 2014 Launchpad Toys. All rights reserved.
//

#ifndef Funomenology_EntityVertex_h
#define Funomenology_EntityVertex_h

#import <GLKit/GLKit.h>

typedef struct {
    GLKVector3 position;
    GLKVector3 normal;
    GLKVector2 texCoord;
} EntityVertex;

#endif
