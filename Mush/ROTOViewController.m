//
//  ROTOViewController.m
//  Mush
//
//  Created by Mike Rotondo on 12/2/13.
//  Copyright (c) 2013 Rototyping. All rights reserved.
//

#import "ROTOViewController.h"
#import "ROTOMarchingCubes.h"
#import "ROTOShaderLoader.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_NORMAL,
    ATTRIB_COLOR,
    NUM_ATTRIBUTES
};

static float cellDim = 0.3;
static int numXCells = 25;
static int numYCells = 25;
static int numZCells = 25;

typedef struct _Metaball{
    GLKVector3 position;
    GLKVector3 color;
    float size;
    struct _Metaball *next;
} Metaball;

static XYZ XYZFromGLKVector3(GLKVector3 v)
{
    XYZ p; p.x = v.x; p.y = v.y; p.z = v.z;
    return p;
}

static GLKVector3 GLKVector3FromXYZ(XYZ v)
{
    return GLKVector3Make(v.x, v.y, v.z);
}

static GLKVector2 GLKVector2FromCGPoint(CGPoint p)
{
    return GLKVector2Make(p.x, p.y);
}

@interface ROTOViewController () {
    GLuint _program;
    
    GLKMatrix4 _modelMatrix;
    GLKMatrix4 _viewMatrix;
    GLKMatrix4 _modelViewMatrix;
    GLKMatrix4 _projectionMatrix;
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    float _rotation;
    NSTimeInterval _timeElapsed;
    
    GLuint _vertexArray;
    GLuint _vertexBuffer;
    
    TRIANGLE *_triangles;
    GRIDVERTEX *_gridVertices;
    GRIDCELL *_gridCells;
    Metaball *_metaballs;
}
@property (strong, nonatomic) EAGLContext *context;

@end

@implementation ROTOViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    int maxTrianglesPerCell = 2;
    int numGridVertices = (numXCells + 1) * (numYCells + 1) * (numZCells + 1);
    int numGridCells = numXCells * numYCells * numZCells;
    int maxTotalTriangles = maxTrianglesPerCell * numGridCells;
    _gridVertices = malloc(numGridVertices * sizeof(GRIDVERTEX));
    _gridCells = malloc(numGridCells * sizeof(GRIDCELL));
    _triangles = malloc(maxTotalTriangles * sizeof(TRIANGLE));
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;

    [self setupGL];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.view addGestureRecognizer:tapRecognizer];
}

- (void)addMetaball:(Metaball)mb
{
    Metaball **pointerToHeapMB = NULL;
    if (_metaballs == NULL)
    {
        pointerToHeapMB = &_metaballs;
    }
    else
    {
        Metaball *lastMetaball = _metaballs;
        while (lastMetaball->next != NULL)
        {
            lastMetaball = lastMetaball->next;
        }
        pointerToHeapMB = &lastMetaball->next;
    }
    Metaball *heapMB = (Metaball *)malloc(sizeof(Metaball));
    memcpy(heapMB, &mb, sizeof(Metaball));
    heapMB->next = NULL;
    *pointerToHeapMB = heapMB;
}

- (void)freeMetaballs
{
    Metaball *metaball = _metaballs;
    while (metaball != NULL) {
        Metaball *nextMB = metaball->next;
        free(metaball);
        metaball = nextMB;
    }
}

- (void)dealloc
{    
    [self tearDownGL];
    
    free(_gridVertices);
    free(_gridCells);
    free(_triangles);
    [self freeMetaballs];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }
}

static inline float GLKVector3SquaredLength(GLKVector3 vector)
{
    return vector.v[0] * vector.v[0] + vector.v[1] * vector.v[1] + vector.v[2] * vector.v[2];
}

static inline float pointFieldStrength(GLKVector3 point, GLKVector3 measurementPosition)
{
    float squaredDistance = GLKVector3SquaredLength(GLKVector3Subtract(point, measurementPosition));
    return 1.0 / squaredDistance;
}

static int meshMetaballs(Metaball* metaballs, TRIANGLE *triangles, GRIDCELL *gridCells, GRIDVERTEX *gridVertices, NSTimeInterval time)
{
    GLKVector3 cellSize = GLKVector3Make(cellDim, cellDim, cellDim);
    GLKVector3 halfCellSize = GLKVector3DivideScalar(cellSize, 2.0);
    GLKVector3 gridSize = GLKVector3Multiply(GLKVector3Make(numXCells, numYCells, numZCells), cellSize);
    GLKVector3 halfGridSize = GLKVector3DivideScalar(gridSize, 2.0);
    for (int x = 0; x < numXCells + 1; x++)
    {
        for (int y = 0; y < numYCells + 1; y++)
        {
            for (int z = 0; z < numZCells + 1; z++)
            {
                GLKVector3 vertexPosition = GLKVector3Subtract(GLKVector3Make(x * cellDim, y * cellDim, z * cellDim), halfGridSize);
                GRIDVERTEX vertex;
                vertex.p = XYZFromGLKVector3(vertexPosition);

                Metaball *metaball = metaballs;
                double val = 0;
                while (metaball != NULL)
                {
                    val += pointFieldStrength(metaball->position, vertexPosition) * metaball->size;
                    metaball = metaball->next;
                }
                vertex.val = val;
             
                int gridVertexIndex = y * (numXCells + 1) * (numZCells + 1) + z * (numXCells + 1) + x;
                gridVertices[gridVertexIndex] = vertex;
            }
        }
    }

    for (int x = 0; x < numXCells; x++)
    {
        for (int y = 0; y < numYCells; y++)
        {
            for (int z = 0; z < numZCells; z++)
            {
                GRIDCELL cell;
                
                int lowerBackLeftVertexIndex = y * (numXCells + 1) * (numZCells + 1) + (z + 1) * (numXCells + 1) + x;
                GRIDVERTEX lowerBackLeft = gridVertices[lowerBackLeftVertexIndex];
                cell.v[0] = lowerBackLeft;
                
                int lowerBackRightVertexIndex = y * (numXCells + 1) * (numZCells + 1) + (z + 1) * (numXCells + 1) + (x + 1);
                GRIDVERTEX lowerBackRight = gridVertices[lowerBackRightVertexIndex];
                cell.v[1] = lowerBackRight;
                
                int lowerFrontRightVertexIndex = y * (numXCells + 1) * (numZCells + 1) + z * (numXCells + 1) + (x + 1);
                GRIDVERTEX lowerFrontRight = gridVertices[lowerFrontRightVertexIndex];
                cell.v[2] = lowerFrontRight;
                
                int lowerFrontLeftVertexIndex = y * (numXCells + 1) * (numZCells + 1) + z * (numXCells + 1) + x;
                GRIDVERTEX lowerFrontLeft = gridVertices[lowerFrontLeftVertexIndex];
                cell.v[3] = lowerFrontLeft;

                int upperBackLeftVertexIndex = (y + 1) * (numXCells + 1) * (numZCells + 1) + (z + 1) * (numXCells + 1) + x;
                GRIDVERTEX upperBackLeft = gridVertices[upperBackLeftVertexIndex];
                cell.v[4] = upperBackLeft;
                
                int upperBackRightVertexIndex = (y + 1) * (numXCells + 1) * (numZCells + 1) + (z + 1) * (numXCells + 1) + (x + 1);
                GRIDVERTEX upperBackRight = gridVertices[upperBackRightVertexIndex];
                cell.v[5] = upperBackRight;
                
                int upperFrontRightVertexIndex = (y + 1) * (numXCells + 1) * (numZCells + 1) + z * (numXCells + 1) + (x + 1);
                GRIDVERTEX upperFrontRight = gridVertices[upperFrontRightVertexIndex];
                cell.v[6] = upperFrontRight;
                
                int upperFrontLeftVertexIndex = (y + 1) * (numXCells + 1) * (numZCells + 1) + z * (numXCells + 1) + x;
                GRIDVERTEX upperFrontLeft = gridVertices[upperFrontLeftVertexIndex];
                cell.v[7] = upperFrontLeft;
                
                GLKVector3 cellCenter = GLKVector3Add(GLKVector3FromXYZ(lowerFrontLeft.p), halfCellSize);
                GLKVector3 normal = GLKVector3Make(0, 0, 0);
                GLKVector3 color = GLKVector3Make(0, 0, 0);
                float totalForce = 0;
                Metaball *metaball = metaballs;
                while (metaball != NULL)
                {
                    GLKVector3 metaballNormal = GLKVector3Normalize(GLKVector3Subtract(cellCenter, metaball->position));
                    float contribution = pointFieldStrength(metaball->position, cellCenter) * metaball->size;
                    normal = GLKVector3Add(GLKVector3MultiplyScalar(metaballNormal, contribution), normal);
                    color = GLKVector3Add(GLKVector3MultiplyScalar(metaball->color, contribution), color);
                    totalForce += contribution;
                    metaball = metaball->next;
                }
                normal = GLKVector3DivideScalar(normal, totalForce);
                cell.n = XYZFromGLKVector3(normal);
                color = GLKVector3DivideScalar(color, totalForce);
                cell.c = XYZFromGLKVector3(color);
                
//                for (int i = 0; i < 8; i++)
//                {
//                    XYZ extrudedP;
//                    extrudedP.x = cell.v[i].p.x + normal.x;// * sin(time * cell.v[i].p.y) * 0.1;
//                    extrudedP.y = cell.v[i].p.y + normal.y;// * sin(time * cell.v[i].p.y) * 0.1;
//                    extrudedP.z = cell.v[i].p.z + normal.z;// * sin(time * cell.v[i].p.y) * 0.1;
//                    cell.v[i].p = extrudedP;
//                }


                int gridCellIndex = y * numXCells * numZCells + z * numXCells + x;
                gridCells[gridCellIndex] = cell;
            }
        }
    }
    
    int numTriangles = 0;
    int numGridCells = numXCells * numYCells * numZCells;
    for (int i = 0; i < numGridCells; i++)
    {
        numTriangles += Polygonise(gridCells[i], 1.0, &triangles[numTriangles]);
    }
    
    return numTriangles;
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    _program = [ROTOShaderLoader loadShaders];
    
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(VERTEX), BUFFER_OFFSET(0));
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(VERTEX), BUFFER_OFFSET(sizeof(XYZ)));
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 3, GL_FLOAT, GL_FALSE, sizeof(VERTEX), BUFFER_OFFSET(sizeof(XYZ) * 2));
    
    glBindVertexArrayOES(0);
    
//    glEnable(GL_CULL_FACE);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    _viewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -8.0f);
    
    // Compute the model view matrix for the object rendered with ES2
    _modelMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, 0.0f);
    _modelMatrix = GLKMatrix4Rotate(_modelMatrix, 3 * _rotation, 1.0f, 1.0f, 1.0f);
    
    _modelViewMatrix = GLKMatrix4Multiply(_viewMatrix, _modelMatrix);
    
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(_modelViewMatrix), NULL);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(_projectionMatrix, _modelViewMatrix);
    
    _rotation += self.timeSinceLastUpdate * 0.5f;
    _timeElapsed += self.timeSinceLastUpdate;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glBindVertexArrayOES(_vertexArray);
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    
    Metaball mb1, mb2, mb3, mb4;
    mb1.position = GLKVector3Make(cosf(5 * _rotation), 2 * sinf(_rotation), sinf(5 * _rotation));
    mb1.color = GLKVector3Make(0.8, 0.3, 0.4);
    mb1.size = 0.5;
    
    mb2.position = GLKVector3Make(sinf(2 * _rotation), 2 * -cosf(_rotation), sinf(3 * _rotation));
    mb2.color = GLKVector3Make(0.9, 0.4, 0.15);
    mb2.size = 0.8;
    
    mb3.position = GLKVector3Make(1.2 * sinf(4 * _rotation),  -sinf(_rotation), cosf(8 * _rotation));
    mb3.color = GLKVector3Make(0.45, 0.85, 0.2);
    mb3.size = 0.6;

    mb4.position = GLKVector3Make(0, 2 * cosf(2 * _rotation), 0);
    mb4.color = GLKVector3Make(0.65, 0.35, 0.91);
    mb4.size = 1.2;

    mb1.next = &mb2; mb2.next = &mb3; mb3.next = &mb4; mb4.next = _metaballs;
    
    int numTriangles = meshMetaballs(&mb1, _triangles, _gridCells, _gridVertices, _timeElapsed);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, numTriangles * sizeof(TRIANGLE), _triangles, GL_STATIC_DRAW);
    
    glDrawArrays(GL_TRIANGLES, 0, numTriangles * 3);
//    glDrawArrays(GL_LINE_STRIP, 0, numTriangles * 3);
}

#pragma mark - Touch Handling

- (void)handleTap:(UITapGestureRecognizer *)recognizer
{
    GLint viewport[4] = {};
    glGetIntegerv(GL_VIEWPORT, viewport);
    
    GLKVector3 origin = { 0, 0, 0 };
    GLKVector3 projectedOrigin = GLKMathProject(origin, _modelViewMatrix, _projectionMatrix, viewport);

    GLKVector2 touchPoint = GLKVector2MultiplyScalar(GLKVector2FromCGPoint([recognizer locationInView:self.view]), self.view.contentScaleFactor);
    GLKVector2 flippedTouchPoint = GLKVector2Make(touchPoint.x, self.view.bounds.size.height * self.view.contentScaleFactor - touchPoint.y);
    GLKVector3 windowCoords = GLKVector3Make(flippedTouchPoint.x, flippedTouchPoint.y, projectedOrigin.z);
    
    bool success;
    GLKVector3 pointInSpace = GLKMathUnproject(windowCoords, _modelViewMatrix, _projectionMatrix, viewport, &success);
    if (!success)
    {
        NSLog(@"WHOOPS");
        return;
    }
    
    Metaball mb;
    mb.position = pointInSpace;
    mb.color = GLKVector3Make((arc4random() / (float)0x100000000), (arc4random() / (float)0x100000000), (arc4random() / (float)0x100000000));
    mb.size = (arc4random() / (float)0x100000000);
    [self addMetaball:mb];
}

@end
