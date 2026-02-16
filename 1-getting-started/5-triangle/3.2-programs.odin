package main

import "core:fmt"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:glfw"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

vertexShaderSource :: `
#version 330 core
layout (location = 0) in vec3 aPos;
void main() {
	gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}`

fragShaderOrangeSource :: `
#version 330 core
out vec4 FragColor;
void main() {
	FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
}`
fragShaderYellowSource :: `
#version 330 core
out vec4 FragColor;
void main() {
	FragColor = vec4(1.0f, 1.0f, 0.0f, 1.0f);
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

	verticies1 := [?]f32{0.5, 0.5, 0.0, 0.5, -0.5, 0.0, -0.5, -0.5, 0.0}
	verticies2 := [?]f32{-0.5, -0.5, 0.0, -0.5, 0.5, 0.0, 0.5, 0.5, 0.0}

	program1, ok := gl.load_shaders_source(vertexShaderSource, fragShaderOrangeSource)
	if !ok {
		msg, shaderType := gl.get_last_error_message()
		fmt.eprintf("Shader program creation error! %s %v", msg, shaderType)
		os.exit(1)
	}
	defer gl.DeleteProgram(program1)
	program2, ok2 := gl.load_shaders_source(vertexShaderSource, fragShaderYellowSource)
	if !ok2 {
		msg, shaderType := gl.get_last_error_message()
		fmt.eprintf("Shader program creation error! %s %v", msg, shaderType)
		os.exit(1)
	}
	defer gl.DeleteProgram(program2)

	vao1, vbo1: u32
	gl.GenBuffers(1, &vbo1)
	gl.GenVertexArrays(1, &vao1)
	defer gl.DeleteBuffers(1, &vbo1)
	defer gl.DeleteVertexArrays(1, &vao1)

	vao2, vbo2: u32
	gl.GenBuffers(1, &vbo2)
	gl.GenVertexArrays(1, &vao2)
	defer gl.DeleteBuffers(1, &vbo2)
	defer gl.DeleteVertexArrays(1, &vao2)

	// 1 triangle
	gl.BindVertexArray(vao1)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo1)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(verticies1), &verticies1, gl.STATIC_DRAW)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)

	// 2 triangle
	gl.BindVertexArray(vao2)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo2)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(verticies2), &verticies2, gl.STATIC_DRAW)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)

	// gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)

	for !glfw.WindowShouldClose(window) {
		processInput(window)

		gl.ClearColor(0.2, 0.3, 0.7, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		gl.UseProgram(program1)
		gl.BindVertexArray(vao1)
		gl.DrawArrays(gl.TRIANGLES, 0, 3)

		gl.UseProgram(program2)
		gl.BindVertexArray(vao2)
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
