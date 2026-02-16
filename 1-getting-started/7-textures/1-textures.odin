package main

import "core:bytes"
import "core:fmt"
import "core:image/png"
import "core:math"
import "core:mem"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:glfw"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

vertexShaderSource :: string(#load("1-textures.vs"))
fragShaderSource :: string(#load("1-textures.fs"))
wallAsset :: "wall.png"
faceAsset :: "face.png"

mixValue := 0.0

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

	verticies := [?]f32 {
		0.5,
		0.5,
		0.0,
		1,
		0,
		0,
		1,
		1, // top right
		0.5,
		-0.5,
		0.0,
		0,
		1,
		0,
		1,
		0, // bottom right
		-0.5,
		-0.5,
		0.0,
		0,
		0,
		1,
		0,
		0, // bottom left
		-0.5,
		0.5,
		0.0,
		1,
		1,
		0,
		0,
		1, // top left
	}
	indicies := [?]u32{0, 1, 3, 1, 2, 3}

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
	gl.GenBuffers(1, &ebo)
	defer gl.DeleteBuffers(1, &vbo)
	defer gl.DeleteVertexArrays(1, &vao)
	defer gl.DeleteBuffers(1, &ebo)

	gl.BindVertexArray(vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(verticies), &verticies, gl.STATIC_DRAW)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indicies), &indicies, gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * size_of(f32), cast(uintptr)3 * size_of(f32))
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * size_of(f32), cast(uintptr)6 * size_of(f32))
	gl.EnableVertexAttribArray(2)

	// wall texture
	wallTexture: u32
	gl.GenTextures(1, &wallTexture)
	defer gl.DeleteTextures(1, &wallTexture)
	gl.BindTexture(gl.TEXTURE_2D, wallTexture)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	pngWall, err := png.load_from_file(wallAsset)
	if err != nil {
		fmt.println("Error while loading wall texture")
		os.exit(1)
	}
	wallImg := bytes.buffer_to_bytes(&pngWall.pixels)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, i32(pngWall.width), i32(pngWall.height), 0, gl.RGB, gl.UNSIGNED_BYTE, &wallImg[0])
	gl.GenerateMipmap(gl.TEXTURE_2D)

	// face texture
	faceTexture: u32
	gl.GenTextures(1, &faceTexture)
	defer gl.DeleteTextures(1, &faceTexture)
	gl.BindTexture(gl.TEXTURE_2D, faceTexture)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	pngFace, faceErr := png.load_from_file(faceAsset)
	if faceErr != nil {
		fmt.println("Error while loading face texture")
		os.exit(1)
	}
	faceImg := bytes.buffer_to_bytes(&pngFace.pixels)
	flipVertical(faceImg, pngFace.width, pngFace.height, pngFace.channels)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, i32(pngFace.width), i32(pngFace.height), 0, gl.RGBA, gl.UNSIGNED_BYTE, &faceImg[0])
	gl.GenerateMipmap(gl.TEXTURE_2D)

	gl.UseProgram(program)
	gl.Uniform1i(gl.GetUniformLocation(program, "texture1"), 0)
	gl.Uniform1i(gl.GetUniformLocation(program, "texture2"), 1)

	for !glfw.WindowShouldClose(window) {
		processInput(window)

		gl.ClearColor(0.2, 0.3, 0.7, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, wallTexture)
		gl.ActiveTexture(gl.TEXTURE1)
		gl.BindTexture(gl.TEXTURE_2D, faceTexture)

		gl.Uniform1f(gl.GetUniformLocation(program, "mixValue"), f32(mixValue))

		gl.UseProgram(program)
		gl.BindVertexArray(vao)
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
		gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, cast(rawptr)(uintptr(0)))

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
}

flipVertical :: proc(data: []u8, width, height, channels: int) {
	tmp: [4]u8
	px1: ^u8
	px2: ^u8
	for x in 0 ..< width {
		for y in 0 ..< height / 2 {
			px1 = &data[(x + y * width) * channels]
			px2 = &data[(x + (height - 1 - y) * width) * channels]

			mem.copy(&tmp, px1, channels)
			mem.copy(px1, px2, channels)
			mem.copy(px2, &tmp, channels)
		}
	}
}

framebufferSizeCallback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
}

processInput :: proc(window: glfw.WindowHandle) {
	if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
		glfw.SetWindowShouldClose(window, true)
	}
	if glfw.GetKey(window, glfw.KEY_UP) == glfw.PRESS {
		mixValue = math.min(1.0, mixValue + 0.01)
	}
	if glfw.GetKey(window, glfw.KEY_DOWN) == glfw.PRESS {
		mixValue = math.max(0.0, mixValue - 0.01)
	}
}
