//
//  ROTOMarchingCubes.h
//  Mush
//
//  Created by Mike Rotondo on 12/3/13.
//  Copyright (c) 2013 Rototyping. All rights reserved.
//

#ifndef Mush_ROTOMarchingCubes_h
#define Mush_ROTOMarchingCubes_h

typedef struct {
    float x, y, z;
} XYZ;

typedef struct {
    XYZ p;
    double val;
} GridVertex;

typedef struct {
    GridVertex v[8];
    XYZ n;
    XYZ c;
} GridCell;

typedef struct {
    XYZ p;
    XYZ n;
    XYZ c;
} TriangleVertex;

typedef struct {
    TriangleVertex v[3];
} Triangle;

int Polygonise(GridCell grid, double isolevel, Triangle *triangles);

#endif
