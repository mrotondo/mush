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
#import "Quad.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_NORMAL,
    ATTRIB_COLOR,
    NUM_ATTRIBUTES
};

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
    GLuint _metaballProgram;
    GLuint _texturedQuadProgram;
    
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
    
    GLuint _cellPositionsTexture;
    GLuint _metaballPositionsTexture;
    GLuint _cellValuesTexture;
    
    Triangle *_triangles;
    GridVertex *_gridVertices;
    GLKVector3 *_gridPositionData;
    GridCell *_gridCells;
    Metaball *_metaballs;

    float _cellDim;
    int _numXCells;
    int _numYCells;
    int _numZCells;
    
    int _textureDim;
    
    GLuint _cellValuesFBO;
}
@property (strong, nonatomic) EAGLContext *context;

@end

@implementation ROTOViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    _cellDim = 0.3;
    _numXCells = 25;
    _numYCells = 25;
    _numZCells = 25;
    
    _textureDim = ceilf(sqrtf((_numXCells + 1) * (_numYCells + 1) * (_numZCells + 1)));
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;

    [self setupGL];

    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.view addGestureRecognizer:tapRecognizer];

    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.view addGestureRecognizer:panRecognizer];
    
    [self initGrid];
    
//    for (int i = 0; i < 300; i++)
//    {
//        Metaball mb;
//        mb.position = GLKVector3Make(-2 + 4 * (arc4random() / (float)0x100000000), -2 + 4 * (arc4random() / (float)0x100000000), -2 + 4 * (arc4random() / (float)0x100000000));
//        mb.color = GLKVector3Make((arc4random() / (float)0x100000000), (arc4random() / (float)0x100000000), (arc4random() / (float)0x100000000));
//        mb.size = 0.5 + (arc4random() / (float)0x100000000);
//        [self addMetaball:mb];
//    }
}

- (void)initGrid
{
    int numGridVertices = (_numXCells + 1) * (_numYCells + 1) * (_numZCells + 1);
    int numGridCells = _numXCells * _numYCells * _numZCells;
    _gridVertices = malloc(numGridVertices * sizeof(GridVertex));
    _gridCells = malloc(numGridCells * sizeof(GridCell));

    int maxTrianglesPerCell = 4;
    int maxTotalTriangles = maxTrianglesPerCell * numGridCells;
    _triangles = malloc(maxTotalTriangles * sizeof(Triangle));
    
    int textureDim = ceilf(sqrtf((_numXCells + 1) * (_numYCells + 1) * (_numZCells + 1)));
    GLKVector3 *gridData = (GLKVector3 *)malloc(textureDim * textureDim * sizeof(GLKVector3));
    
    GLKVector3 gridSize = GLKVector3MultiplyScalar(GLKVector3Make(_numXCells, _numYCells, _numZCells), _cellDim);
    GLKVector3 halfGridSize = GLKVector3DivideScalar(gridSize, 2.0);
    
    for (int x = 0; x < _numXCells + 1; x++)
    {
        for (int y = 0; y < _numYCells + 1; y++)
        {
            for (int z = 0; z < _numZCells + 1; z++)
            {
                int gridVertexIndex = y * (_numXCells + 1) * (_numZCells + 1) + z * (_numXCells + 1) + x;
                GLKVector3 vertexPosition = GLKVector3Subtract(GLKVector3Make(x * _cellDim, y * _cellDim, z * _cellDim), halfGridSize);
                gridData[gridVertexIndex] = vertexPosition;
                
                GridVertex vertex;
                vertex.p = XYZFromGLKVector3(vertexPosition);
                
                _gridVertices[gridVertexIndex] = vertex;
            }
        }
    }
    
    for (int x = 0; x < _numXCells; x++)
    {
        for (int y = 0; y < _numYCells; y++)
        {
            for (int z = 0; z < _numZCells; z++)
            {
                GridCell cell;
                int offsets[8][3] = {
                    {0, 0, 1},
                    {1, 0, 1},
                    {1, 0, 0},
                    {0, 0, 0},
                    {0, 1, 1},
                    {1, 1, 1},
                    {1, 1, 0},
                    {0, 1, 0}
                };
                for (int i = 0; i < 8; i++)
                {
                    int vertexIndex = (y + offsets[i][1]) * (_numXCells + 1) * (_numZCells + 1) + (z + offsets[i][2]) * (_numXCells + 1) + (x + offsets[i][0]);
                    cell.v[i] = &(_gridVertices[vertexIndex]);
                }

                int gridCellIndex = y * _numXCells * _numZCells + z * _numXCells + x;
                _gridCells[gridCellIndex] = cell;
            }
        }
    }
    
    glBindTexture(GL_TEXTURE_2D, _cellPositionsTexture);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, textureDim, textureDim, GL_RGB , GL_FLOAT, gridData);
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
    
    // delete all textures and fbos here
    
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

//static float GLKVector3SquaredLength(GLKVector3 v)
//{
//    return v.v[0] * v.v[0] + v.v[1] * v.v[1] + v.v[2] * v.v[2];
//}

//static float GLKVector3ManhattanLength(GLKVector3 v)
//{
////    return sumFloats(v.v, 3);
//    return 13.5 * (v.v[0] + v.v[1] + v.v[2]);
//}

//static float GLKVector3ConstantLength(GLKVector3 v)
//{
//    return 0.5;
//}

static /*inline*/ void calcPointFieldStrengths(Metaball *metaballs, int numMetaballs, GLKVector3 measurementPosition, float *outContributions, Metaball *outContributingMetaballs, int *outNumContributingMetaballs)
{
    int numContributingMetaballs = 0;
    float contribution = 0.0;
    for (int i = 0; i < numMetaballs; i++)
    {
        GLKVector3 vector = GLKVector3Subtract(measurementPosition, metaballs[i].position);
        float r = GLKVector3Length(vector);
//        float r = GLKVector3SquaredLength(vector);
//        float r = GLKVector3ManhattanLength(vector);
//        float r = GLKVector3ConstantLength(vector);
        
//        if (r < 1.0)
//        {
            // Thanks Ryan Geiss & Ken Perlin! http://www.geisswerks.com/ryan/BLOBS/blobs.html
//            contribution = r * r * r * (r * (r * 6 - 15) + 10);
            contribution = 1.0 / pow(r, 2.0);
            
            outContributions[numContributingMetaballs] = contribution;// * metaballs[i].size;
            outContributingMetaballs[numContributingMetaballs] = metaballs[i];
            ++numContributingMetaballs;
        }
//    }
    *outNumContributingMetaballs = numContributingMetaballs;
}

static /*inline*/ float sumFloats(float *vals, int numVals)
{
    double val = 0;
    for (int i = 0; i < numVals; i++)
    {
        val += vals[i];
    }
    return val;
}

static int meshMetaballs(float cellDim, int numXCells, int numYCells, int numZCells, Metaball* metaballs, Triangle *triangles, GridCell *gridCells, GridVertex *gridVertices, NSTimeInterval time, GLuint cellPositionsTexture)
{
    int numMetaballs = 0;
    Metaball *metaball = metaballs;
    while (metaball != NULL)
    {
        ++numMetaballs;
        metaball = metaball->next;
    }
    
    if (numMetaballs % 10 == 0)
    {
        NSLog(@"NUM MB: %d", numMetaballs);
    }
    
    Metaball mbArray[numMetaballs];
    int mbIndex = 0;
    metaball = metaballs;
    while (metaball != NULL)
    {
        mbArray[mbIndex++] = *metaball;
        metaball = metaball->next;
    }

    float threshold = 0.85;
    
    float *contributions = (float *)malloc(numMetaballs * sizeof(float));
    Metaball *contributingMetaballs = (Metaball *)malloc(numMetaballs * sizeof(Metaball));
    
    GLKVector3 cellSize = GLKVector3Make(cellDim, cellDim, cellDim);
    GLKVector3 halfCellSize = GLKVector3DivideScalar(cellSize, 2.0);
    
    for (int x = 0; x < numXCells + 1; x++)
    {
        for (int y = 0; y < numYCells + 1; y++)
        {
            for (int z = 0; z < numZCells + 1; z++)
            {
                int gridVertexIndex = y * (numXCells + 1) * (numZCells + 1) + z * (numXCells + 1) + x;
                GLKVector3 vertexPosition = GLKVector3FromXYZ(gridVertices[gridVertexIndex].p);
                int numContributingMetaballs = 0;
                calcPointFieldStrengths(mbArray, numMetaballs, vertexPosition, contributions, contributingMetaballs, &numContributingMetaballs);

                float val = sumFloats(contributions, numContributingMetaballs);
                gridVertices[gridVertexIndex].val = val;
//                if (val > threshold / 2.0f)
//                {
//                    gridVertices[gridVertexIndex].val += 0.1f * (arc4random() / (float)0x100000000);
//                }
            }
        }
    }
    
    for (int x = 0; x < numXCells; x++)
    {
        for (int y = 0; y < numYCells; y++)
        {
            for (int z = 0; z < numZCells; z++)
            {
                int gridCellIndex = y * numXCells * numZCells + z * numXCells + x;
                
                int lowerFrontLeftVertexIndex = y * (numXCells + 1) * (numZCells + 1) + z * (numXCells + 1) + x;
                GridVertex lowerFrontLeft = gridVertices[lowerFrontLeftVertexIndex];
                GLKVector3 cellCenter = GLKVector3Add(GLKVector3FromXYZ(lowerFrontLeft.p), halfCellSize);
                GLKVector3 color = GLKVector3Make(0, 0, 0);
                float totalForce = 0;
                int numContributingMetaballs = 0;
                calcPointFieldStrengths(mbArray, numMetaballs, cellCenter, contributions, contributingMetaballs, &numContributingMetaballs);
                if (numContributingMetaballs > 0)
                {
                    for (int i = 0; i < numContributingMetaballs; i++)
                    {
                        color = GLKVector3Add(GLKVector3MultiplyScalar(contributingMetaballs[i].color, contributions[i]), color);
                        totalForce += contributions[i];
                    }
                    color = GLKVector3DivideScalar(color, totalForce);
                    gridCells[gridCellIndex].c = XYZFromGLKVector3(color);
                }
            }
        }
    }
    
    int numTriangles = 0;
    int numGridCells = numXCells * numYCells * numZCells;
    for (int i = 0; i < numGridCells; i++)
    {
        numTriangles += Polygonise(gridCells[i], threshold, &triangles[numTriangles]);
    }
    
    free(contributions);
    free(contributingMetaballs);
    
    return numTriangles;
}

- (void)calcCellValuesWithMetaballs:(Metaball *)metaballs
{
    // Count metaballs
    int numMetaballs = 0;
    Metaball *metaball = metaballs;
    while (metaball != NULL)
    {
        ++numMetaballs;
        metaball = metaball->next;
    }
    
    
    // Put metaball positions in texture
    GLKVector3 *metaballPositionsData = (GLKVector3 *)malloc(64 * 64 * sizeof(GLKVector3));
    int i = 0;
    metaball = metaballs;
    while (metaball != NULL)
    {
        metaballPositionsData[i++] = metaball->position;
        metaball = metaball->next;
    }
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _metaballPositionsTexture);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 64, 64, GL_RGB , GL_FLOAT, metaballPositionsData);
    free(metaballPositionsData);
    
    
    // Do the metaball contribution calculation on the GPU
    int viewport[4];
    glGetIntegerv(GL_VIEWPORT, viewport);
    glViewport(0, 0, _textureDim, _textureDim);
    GLKMatrix4 ortho = GLKMatrix4MakeOrtho(0, _textureDim, 0, _textureDim, -1, 1);
    GLKMatrix4 quadModelViewMatrix = GLKMatrix4MakeScale(_textureDim, _textureDim, 1);

    GLKMatrix4 modelViewMatrix = quadModelViewMatrix;
    GLKMatrix4 modelViewProjection = GLKMatrix4Multiply(ortho, modelViewMatrix);
    glUseProgram(_metaballProgram);
    glVertexAttribPointer(metaballVertexAttribute, 3, GL_FLOAT, GL_FALSE, sizeof(EntityVertex), &quadVertices[0].position);
    glVertexAttribPointer(metaballTexCoordAttribute, 2, GL_FLOAT, GL_FALSE, sizeof(EntityVertex), &quadVertices[0].texCoord);
    glEnableVertexAttribArray(metaballVertexAttribute);
    glEnableVertexAttribArray(metaballTexCoordAttribute);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _cellPositionsTexture);
    glUniform1i(metaballCellPositionsTextureUniform, 0 /*GL_TEXTURE0*/);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _metaballPositionsTexture);
    glUniform1i(metaballMetaballPositionsTextureUniform, 1 /*GL_TEXTURE1*/);
    
    GLKVector2 metaballPositionsTextureSize = GLKVector2Make(64, 64);
    glUniform2fv(metaballMetaballPositionsTextureSizeUniform, 1, metaballPositionsTextureSize.v);
    
    glUniform1f(metaballNumMetaballsUniform, numMetaballs);
    
    glUniformMatrix4fv(metaballMVPMatrixUniform, 1, GL_FALSE, modelViewProjection.m);

    GLint currentFramebuffer;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &currentFramebuffer);
    
    glBindFramebuffer(GL_FRAMEBUFFER, _cellValuesFBO);
    glDrawElements(GL_TRIANGLES, QuadNumIndices, GL_UNSIGNED_INT, quadIndices);
    float *pixels = malloc(_textureDim * _textureDim * 4 * sizeof(float));
    glReadPixels(0, 0, _textureDim, _textureDim, GL_RGBA, GL_FLOAT, pixels);
    
    // do stuff with pixels
    free(pixels);
    
    
    glBindFramebuffer(GL_FRAMEBUFFER, currentFramebuffer);
    
    glDisableVertexAttribArray(metaballVertexAttribute);
    glDisableVertexAttribArray(metaballTexCoordAttribute);
    glUseProgram(0);
    glViewport(viewport[0], viewport[1], viewport[2], viewport[3]);
}

- (void)drawQuadWithTexture:(GLuint)texture size:(GLKVector2)size
{
    GLint viewport[4] = {};
    glGetIntegerv(GL_VIEWPORT, viewport);
    
    glViewport(200, 10, size.x, size.y);
    GLKMatrix4 ortho = GLKMatrix4MakeOrtho(0, size.x, 0, size.y, -1, 1);
    GLKMatrix4 quadModelViewMatrix = GLKMatrix4MakeScale(size.x, size.y, 1);

    GLKMatrix4 modelViewMatrix = quadModelViewMatrix;
    GLKMatrix4 modelViewProjection = GLKMatrix4Multiply(ortho, modelViewMatrix);

    glUseProgram(_texturedQuadProgram);
    glVertexAttribPointer(texturedQuadVertexAttribute, 3, GL_FLOAT, GL_FALSE, sizeof(EntityVertex), &quadVertices[0].position);
    glVertexAttribPointer(texturedQuadTexCoordAttribute, 2, GL_FLOAT, GL_FALSE, sizeof(EntityVertex), &quadVertices[0].texCoord);
    glEnableVertexAttribArray(texturedQuadVertexAttribute);
    glEnableVertexAttribArray(texturedQuadTexCoordAttribute);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture);
    glUniform1i(texturedQuadTextureUniform, 0 /*GL_TEXTURE0*/);
    
    glUniformMatrix4fv(texturedQuadMVPMatrixUniform, 1, GL_FALSE, modelViewProjection.m);
    glDrawElements(GL_TRIANGLES, QuadNumIndices, GL_UNSIGNED_INT, quadIndices);
    glDisableVertexAttribArray(texturedQuadVertexAttribute);
    glDisableVertexAttribArray(texturedQuadTexCoordAttribute);
    glUseProgram(0);

    glViewport(viewport[0], viewport[1], viewport[2], viewport[3]);
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    _program = [ROTOShaderLoader loadDefaultShader];
    _metaballProgram = [ROTOShaderLoader loadMetaballShader];
    _texturedQuadProgram = [ROTOShaderLoader loadTexturedQuadShader];
    
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(TriangleVertex), BUFFER_OFFSET(0));
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(TriangleVertex), BUFFER_OFFSET(sizeof(XYZ)));
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 3, GL_FLOAT, GL_FALSE, sizeof(TriangleVertex), BUFFER_OFFSET(sizeof(XYZ) * 2));
    
    glBindVertexArrayOES(0);
    
    
    
    NSString *extensionString = [NSString stringWithUTF8String:(char *)glGetString(GL_EXTENSIONS)];
    NSArray *extensions = [extensionString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    for (NSString *oneExtension in extensions)
        NSLog(@"%@", oneExtension);
    
    
    glGenTextures (1, &_cellPositionsTexture);
    glBindTexture(GL_TEXTURE_2D, _cellPositionsTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, _textureDim, _textureDim, 0, GL_RGB, GL_FLOAT, NULL);

    glGenTextures (1, &_metaballPositionsTexture);
    glBindTexture(GL_TEXTURE_2D, _metaballPositionsTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 64, 64, 0, GL_RGB, GL_FLOAT, NULL);

    glGenTextures (1, &_cellValuesTexture);
    glBindTexture(GL_TEXTURE_2D, _cellValuesTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED_EXT, _textureDim, _textureDim, 0, GL_RED_EXT, GL_FLOAT, NULL);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED_EXT, _textureDim, _textureDim, 0, GL_RED_EXT, GL_HALF_FLOAT_OES, NULL);
    
    glGenFramebuffers(1, &_cellValuesFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, _cellValuesFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _cellValuesTexture, 0);
    GLenum completeness = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSLog(@"COMPLETE? %@", completeness == GL_FRAMEBUFFER_COMPLETE ? @"YES" : @"NO");
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    
    GLenum err = glGetError();
    if (err != GL_NO_ERROR)
    {
        NSLog(@"THERE IS ERROR");
    }
    else
    {
        NSLog(@"NO ERROR");
    }
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
    Metaball mb1, mb2, mb3, mb4;
    mb1.position = GLKVector3Make(cosf(5 * _rotation), 2 * sinf(_rotation), sinf(5 * _rotation));
    mb1.color = GLKVector3Make(0.8, 0.1, 0.1);
    mb1.size = 0.5;
    
    mb2.position = GLKVector3Make(sinf(2 * _rotation), 2 * -cosf(_rotation), sinf(3 * _rotation));
    mb2.color = GLKVector3Make(0.1, 0.8, 0.1);
    mb2.size = 1;
    
    mb3.position = GLKVector3Make(1.2 * sinf(4 * _rotation),  -sinf(_rotation), cosf(8 * _rotation));
    mb3.color = GLKVector3Make(0.1, 0.1, 0.8);
    mb3.size = 2;

    mb4.position = GLKVector3Make(0, 2 * cosf(2 * _rotation), 0);
    mb4.color = GLKVector3Make(0.35, 0.35, 0.35);
    mb4.size = 3;

    mb1.next = &mb2; mb2.next = &mb3; mb3.next = &mb4; mb4.next = _metaballs;
    
//    mb1.next = NULL;
//    mb4.next = NULL;
    
    
    
    
    [self calcCellValuesWithMetaballs:&mb1];
 
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glBindVertexArrayOES(_vertexArray);
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    
    int numTriangles = meshMetaballs(_cellDim, _numXCells, _numYCells, _numZCells, &mb1, _triangles, _gridCells, _gridVertices, _timeElapsed, _cellPositionsTexture);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, numTriangles * sizeof(Triangle), _triangles, GL_STATIC_DRAW);
    
    glDrawArrays(GL_TRIANGLES, 0, numTriangles * 3);
    
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArrayOES(0);

    
    [self drawQuadWithTexture:_cellValuesTexture size:GLKVector2Make(_textureDim, _textureDim)];
}

#pragma mark - Touch Handling

- (void)addMetaballAtTouchPoint:(GLKVector2)touchPoint
{
    GLint viewport[4] = {};
    glGetIntegerv(GL_VIEWPORT, viewport);
    
    GLKVector3 origin = { 0, 0, 0 };
    GLKVector3 projectedOrigin = GLKMathProject(origin, _modelViewMatrix, _projectionMatrix, viewport);
    
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
    mb.size = 0.2 + 0.8 * (arc4random() / (float)0x100000000);
    [self addMetaball:mb];
}

- (void)handleTap:(UITapGestureRecognizer *)recognizer
{
    GLKVector2 touchPoint = GLKVector2MultiplyScalar(GLKVector2FromCGPoint([recognizer locationInView:self.view]), self.view.contentScaleFactor);
    switch (recognizer.state) {
        case UIGestureRecognizerStateRecognized:
            [self addMetaballAtTouchPoint:touchPoint];
            break;
        default:
            break;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer
{
    GLKVector2 touchPoint = GLKVector2MultiplyScalar(GLKVector2FromCGPoint([recognizer locationInView:self.view]), self.view.contentScaleFactor);
    switch (recognizer.state) {
        case UIGestureRecognizerStateChanged:
            [self addMetaballAtTouchPoint:touchPoint];
            break;
        default:
            break;
    }
}

@end
