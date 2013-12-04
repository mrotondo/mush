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
    XYZ p[3];
} TRIANGLE;

typedef struct {
    XYZ p[8];
    double val[8];
} GRIDCELL;

int Polygonise(GRIDCELL grid, double isolevel, TRIANGLE *triangles);

#endif
