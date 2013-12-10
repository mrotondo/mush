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
} GRIDVERTEX;

typedef struct {
    GRIDVERTEX v[8];
    XYZ n;
    XYZ c;
} GRIDCELL;

typedef struct {
    XYZ p;
    XYZ n;
    XYZ c;
} VERTEX;

typedef struct {
    VERTEX p[3];
} TRIANGLE;

int Polygonise(GRIDCELL grid, double isolevel, TRIANGLE *triangles);

#endif
