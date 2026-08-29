#pragma once

#define GL_GLEXT_PROTOTYPES
#define GLX_GLXEXT_PROTOTYPES

extern "C" {
#include <GL/gl.h>
#include <GL/glext.h>
#include <GL/glx.h>
#include <GL/glxext.h>

// Ubuntu's desktop GL headers do not declare several desktop-compatible aliases
// that libGL exports and drivers return from glXGetProcAddress. Keep the small
// non-debug subset observed in the game workload explicit instead of importing
// the complete GLES extension header.
GLAPI GLboolean APIENTRY glBufferRegionEnabled(void);
GLAPI GLuint APIENTRY glNewBufferRegion(GLenum region);
GLAPI void APIENTRY glDeleteBufferRegion(GLuint region);
GLAPI void APIENTRY glReadBufferRegion(GLuint region, GLint x, GLint y, GLsizei width,
                                      GLsizei height);
GLAPI void APIENTRY glDrawBufferRegion(GLuint region, GLint x, GLint y, GLsizei width,
                                      GLsizei height, GLint xDest, GLint yDest);
GLAPI void APIENTRY glNamedFramebufferTextureMultiviewOVR(
    GLuint framebuffer, GLenum attachment, GLuint texture, GLint level, GLint baseViewIndex,
    GLsizei numViews);
GLAPI void APIENTRY glActiveShaderProgramEXT(GLuint pipeline, GLuint program);
GLAPI void APIENTRY glBindProgramPipelineEXT(GLuint pipeline);
GLAPI GLuint APIENTRY glCreateShaderProgramvEXT(GLenum type, GLsizei count,
                                                const GLchar **strings);
GLAPI void APIENTRY glDeleteProgramPipelinesEXT(GLsizei n, const GLuint *pipelines);
GLAPI void APIENTRY glGenProgramPipelinesEXT(GLsizei n, GLuint *pipelines);
GLAPI void APIENTRY glGetProgramPipelineInfoLogEXT(GLuint pipeline, GLsizei bufSize,
                                                   GLsizei *length, GLchar *infoLog);
GLAPI void APIENTRY glGetProgramPipelineivEXT(GLuint pipeline, GLenum pname, GLint *params);
GLAPI GLboolean APIENTRY glIsProgramPipelineEXT(GLuint pipeline);
GLAPI void APIENTRY glUseProgramStagesEXT(GLuint pipeline, GLbitfield stages, GLuint program);
GLAPI void APIENTRY glValidateProgramPipelineEXT(GLuint pipeline);
GLAPI GLenum APIENTRY glGetGraphicsResetStatusKHR(void);
GLAPI void APIENTRY glGetnUniformfvKHR(GLuint program, GLint location, GLsizei bufSize,
                                      GLfloat *params);
GLAPI void APIENTRY glGetnUniformivKHR(GLuint program, GLint location, GLsizei bufSize,
                                      GLint *params);
GLAPI void APIENTRY glGetnUniformuivKHR(GLuint program, GLint location, GLsizei bufSize,
                                       GLuint *params);
GLAPI void APIENTRY glReadnPixelsKHR(GLint x, GLint y, GLsizei width, GLsizei height,
                                    GLenum format, GLenum type, GLsizei bufSize, void *data);
}

#ifdef Success
#undef Success
#endif

#include <lorelei/ThunkInterface/PassTags.h>
#include <lorelei/ThunkInterface/Proc.h>

namespace lore::thunk {

template <>
struct ProcFnDesc<::glXGetProcAddress> {
    _DESC pass::GetProcAddress<1> proc_address_pass = {};
};

template <>
struct ProcFnDesc<::glXGetProcAddressARB> {
    _DESC pass::GetProcAddress<1> proc_address_pass = {};
};

}
