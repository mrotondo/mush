/*==============================================================================
 Copyright (c) 2012-2013 Qualcomm Connected Experiences, Inc.
 All Rights Reserved.
 ==============================================================================*/

#ifndef _QCAR_QUAD_H_
#define _QCAR_QUAD_H_

#import <GLKit/GLKit.h>
#import "EntityVertex.h"

#define QuadNumVertices 4
#define QuadNumIndices 6
static const EntityVertex quadVertices[QuadNumVertices] = {
    {{-0.5f,  -0.5f,  0.0f},  {0.0f, 0.0f, 1.0f},  {0.0, 0.0}},
    {{0.5f,  -0.5f,  0.0f},   {0.0f, 0.0f, 1.0f},  {1.0, 0.0}},
    {{0.5f,   0.5f,  0.0f},   {0.0f, 0.0f, 1.0f},  {1.0, 1.0}},
    {{-0.5f,   0.5f,  0.0f},  {0.0f, 0.0f, 1.0f},  {0.0, 1.0}},
};

static const unsigned int quadIndices[QuadNumIndices] =
{
     0,  1,  2,  0,  2,  3,
};


#endif // _QC_AR_QUAD_H_
