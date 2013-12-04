//
//  ROTOViewController.m
//  Mush
//
//  Created by Mike Rotondo on 12/2/13.
//  Copyright (c) 2013 Rototyping. All rights reserved.
//

#import "ROTOViewController.h"
#import "ROTOMarchingCubes.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
//    UNIFORM_NORMAL_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
//    ATTRIB_NORMAL,
    NUM_ATTRIBUTES
};

static float cellDim = 0.22;
static int numXCells = 25;
static int numYCells = 25;
static int numZCells = 25;

static XYZ XYZFromGLKVector3(GLKVector3 v)
{
    XYZ p; p.x = v.x; p.y = v.y; p.z = v.z;
    return p;
}

@interface ROTOViewController () {
    GLuint _program;
    
    GLKMatrix4 _modelViewProjectionMatrix;
//    GLKMatrix3 _normalMatrix;
    float _rotation;
    
    GLuint _vertexArray;
    GLuint _vertexBuffer;
}
@property (strong, nonatomic) EAGLContext *context;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
@end

@implementation ROTOViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [self setupGL];
}

- (void)dealloc
{    
    [self tearDownGL];
    
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

static float GLKVector3SquaredLength(GLKVector3 vector)
{
    return vector.v[0] * vector.v[0] + vector.v[1] * vector.v[1] + vector.v[2] * vector.v[2];
}

static float pointFieldStrength(GLKVector3 point, GLKVector3 measurementPosition)
{
    float squaredDistance = GLKVector3SquaredLength(GLKVector3Subtract(point, measurementPosition));
    return 1.0 / squaredDistance;
}

static int meshMetaballs(int numMetaballs, GLKVector4 *metaballs, TRIANGLE **out_triangles)
{
    GLKVector3 gridSize = GLKVector3Make(numXCells * cellDim, numYCells * cellDim, numZCells * cellDim);
    GLKVector3 halfGridSize = GLKVector3DivideScalar(gridSize, 2.0);
    int numGridCells = numXCells * numYCells * numZCells;
    GRIDCELL *grid = malloc(numGridCells * sizeof(GRIDCELL));
    for (int x = 0; x < numXCells; x++)
    {
        for (int y = 0; y < numYCells; y++)
        {
            for (int z = 0; z < numZCells; z++)
            {
                GLKVector3 cellCenter = GLKVector3Subtract(GLKVector3Make(x * cellDim, y * cellDim, z * cellDim), halfGridSize);
                
                GRIDCELL cell;
                GLKVector3 normalizedCellVertices[8] = {
                    {-0.5, -0.5, 0.5},
                    {0.5, -0.5, 0.5},
                    {0.5, -0.5, -0.5},
                    {-0.5, -0.5, -0.5},
                    {-0.5, 0.5, 0.5},
                    {0.5, 0.5, 0.5},
                    {0.5, 0.5, -0.5},
                    {-0.5, 0.5, -0.5},
                };
                for (int v_i = 0; v_i < 8; v_i++)
                {
                    GLKVector3 v = normalizedCellVertices[v_i];
                    GLKVector3 cellVertexOffset = GLKVector3Make(v.x * cellDim, v.y * cellDim, v.z * cellDim);
                    GLKVector3 cellVertexPos = GLKVector3Add(cellCenter, cellVertexOffset);
                    cell.p[v_i] = XYZFromGLKVector3(cellVertexPos);

                    cell.val[v_i] = 0;
                    for (int m_i = 0; m_i < numMetaballs; m_i++)
                    {
                        GLKVector4 metaball = metaballs[m_i];
                        GLKVector3 metaballPosition = GLKVector3MakeWithArray(metaball.v);
                        float metaballForce = metaball.w;
                        cell.val[v_i] += pointFieldStrength(metaballPosition, cellVertexPos) * metaballForce;
                    }
                }
                int gridCellIndex = y * numXCells * numZCells + z * numXCells + x;
                grid[gridCellIndex] = cell;
            }
        }
    } // lol nesting
    
    int maxTrianglesPerCell = 2;
    int maxTotalTriangles = maxTrianglesPerCell * numGridCells;
    int numTriangles = 0;
    TRIANGLE *triangles = malloc(maxTotalTriangles * sizeof(TRIANGLE));
    for (int i = 0; i < numGridCells; i++)
    {
        numTriangles += Polygonise(grid[i], 1.0, &triangles[numTriangles]);
    }
    free(grid);
    
    *out_triangles = triangles;
    return numTriangles;
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(XYZ), BUFFER_OFFSET(0));
//    glEnableVertexAttribArray(GLKVertexAttribNormal);
//    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 24, BUFFER_OFFSET(12));
    
    glBindVertexArrayOES(0);
    
    glEnable(GL_CULL_FACE);
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
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -8.0f);
    
    // Compute the model view matrix for the object rendered with ES2
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, 0.0f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotation, 1.0f, 1.0f, 1.0f);
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
//    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    _rotation += self.timeSinceLastUpdate * 0.5f;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glBindVertexArrayOES(_vertexArray);
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
//    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    
//    GLKVector4 metaballs[] = {
//        {cosf(5 * _rotation), 2 * sinf(_rotation), sinf(5 * _rotation), 0.4},
//        {sinf(5 * _rotation), 2 * -sinf(_rotation), cosf(5 * _rotation), 0.4},
//        {0, 2 * cosf(_rotation), 0, 0.8}
//    };

    GLKVector4 metaballs[] = {
        {1.8 * cosf(5 * _rotation), 0, 1.8 * sinf(5 * _rotation), 0.1},
        {1.8 * sinf(6 * _rotation), 1.8 * cosf(6 * _rotation), 0, 0.1},
        {0, 0, 0, 1.5}
    };
    
    TRIANGLE *triangles;
    int numTriangles = meshMetaballs(3, metaballs, &triangles);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, numTriangles * sizeof(TRIANGLE), triangles, GL_STATIC_DRAW);
    free(triangles);
    
    glDrawArrays(GL_TRIANGLES, 0, numTriangles * 3);
//    glDrawArrays(GL_LINE_STRIP, 0, numTriangles * 3);
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, GLKVertexAttribPosition, "position");
//    glBindAttribLocation(_program, GLKVertexAttribNormal, "normal");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
//    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
