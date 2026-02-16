package main

import "core:fmt"
import "core:math"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:glfw"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

vertexShaderSource :: `
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor; 

out vec3 ourColor;

uniform vec3 offset;

void main() {
	gl_Position = vec4(aPos + offset, 1.0);
	ourColor = aColor;
}`

fragShaderSource :: `
#version 330 core
in vec3 ourColor;
out vec4 FragColor;

void main() {
	FragColor = vec4(ourColor, 1.0);
}`

main :: proc() {
	if !glfw.Init() {
		description, code := glfw.GetError()
		fmt.eprintln(#location(), description, code)
		os.exit(1)
	}
	defer glfw.Terminate()

	glfw.WindowHint(glfw.RESIZABLE, 1)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	window := glfw.CreateWindow(800, 600, "First window", nil, nil)
	if window == nil {
		description, code := glfw.GetError()
		fmt.eprintln(#location(window), description, code)
		os.exit(1)
	}

	glfw.SetFramebufferSizeCallback(window, framebufferSizeCallback)
	glfw.MakeContextCurrent(window)

	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

	verticies := [?]f32{0.0, 0.5, 0.0, 1, 0, 0, 0.5, -0.5, 0.0, 0, 1, 0, -0.5, -0.5, 0.0, 0, 0, 1}

	program, ok := gl.load_shaders_source(vertexShaderSource, fragShaderSource)
	if !ok {
		msg, shaderType := gl.get_last_error_message()
		fmt.eprintf("Shader program creation error! %s %v", msg, shaderType)
		os.exit(1)
	}
	defer gl.DeleteProgram(program)

	vao, vbo, ebo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenVertexArrays(1, &vao)
	defer gl.DeleteBuffers(1, &vbo)
	defer gl.DeleteVertexArrays(1, &vao)
	defer gl.DeleteBuffers(1, &ebo)

	gl.BindVertexArray(vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(verticies), &verticies, gl.STATIC_DRAW)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), cast(uintptr)3 * size_of(f32))
	gl.EnableVertexAttribArray(1)

	offsetLocation := gl.GetUniformLocation(program, "offset")

	for !glfw.WindowShouldClose(window) {
		processInput(window)

		gl.ClearColor(0.2, 0.3, 0.7, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		gl.UseProgram(program)
		gl.BindVertexArray(vao)


		gl.Uniform3f(offsetLocation, 0.3, 0, 0)
		gl.DrawArrays(gl.TRIANGLES, 0, 3)

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
}

framebufferSizeCallback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
}

processInput :: proc(window: glfw.WindowHandle) {
	if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
		glfw.SetWindowShouldClose(window, true)
	}
}
