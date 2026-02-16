package main

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:glfw"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 600

CAMERA_SPEED :: 2.5
SENSITIVITY :: 0.1

mainVertexShaderSource :: string(#load("main.vs"))
mainFragShaderSource :: string(#load("main.fs"))
lightVertexShaderSource :: string(#load("light.vs"))
lightFragShaderSource :: string(#load("light.fs"))

Camera :: struct {
	pos, front, up:   glm.vec3,
	pitch, yaw, zoom: f64,
}

camera := Camera {
	pos   = glm.vec3{0, 0, 3},
	front = glm.vec3{0, 0, -1},
	up    = glm.vec3{0, 1, 0},
	yaw   = -90,
	zoom  = 45,
}

lightPos := glm.vec3{1.2, 1, 2}

lastMousePos := [2]f64{SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2}
isFirstTimeMouseUpdate := true

deltaTime, lastFrame: f64

main :: proc() {
	if !glfw.Init() {
		fmt.println("error while glfw init")
		os.exit(1)
	}
	defer glfw.Terminate()

	glfw.WindowHint(glfw.RESIZABLE, 1)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	window := glfw.CreateWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Lightning", nil, nil)
	if window == nil {
		fmt.println("error while window create")
		os.exit(1)
	}

	glfw.SetFramebufferSizeCallback(window, resizeCallback)
	glfw.MakeContextCurrent(window)

	glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)
	glfw.SetCursorPosCallback(window, mouseCallback)
	glfw.SetScrollCallback(window, scrollCallback)

	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)
	gl.Enable(gl.DEPTH_TEST)

	verticies := [?]f32 {
		-0.5,
		-0.5,
		-0.5,
		0.5,
		-0.5,
		-0.5,
		0.5,
		0.5,
		-0.5,
		0.5,
		0.5,
		-0.5,
		-0.5,
		0.5,
		-0.5,
		-0.5,
		-0.5,
		-0.5,
		-0.5,
		-0.5,
		0.5,
		0.5,
		-0.5,
		0.5,
		0.5,
		0.5,
		0.5,
		0.5,
		0.5,
		0.5,
		-0.5,
		0.5,
		0.5,
		-0.5,
		-0.5,
		0.5,
		-0.5,
		0.5,
		0.5,
		-0.5,
		0.5,
		-0.5,
		-0.5,
		-0.5,
		-0.5,
		-0.5,
		-0.5,
		-0.5,
		-0.5,
		-0.5,
		0.5,
		-0.5,
		0.5,
		0.5,
		0.5,
		0.5,
		0.5,
		0.5,
		0.5,
		-0.5,
		0.5,
		-0.5,
		-0.5,
		0.5,
		-0.5,
		-0.5,
		0.5,
		-0.5,
		0.5,
		0.5,
		0.5,
		0.5,
		-0.5,
		-0.5,
		-0.5,
		0.5,
		-0.5,
		-0.5,
		0.5,
		-0.5,
		0.5,
		0.5,
		-0.5,
		0.5,
		-0.5,
		-0.5,
		0.5,
		-0.5,
		-0.5,
		-0.5,
		-0.5,
		0.5,
		-0.5,
		0.5,
		0.5,
		-0.5,
		0.5,
		0.5,
		0.5,
		0.5,
		0.5,
		0.5,
		-0.5,
		0.5,
		0.5,
		-0.5,
		0.5,
		-0.5,
	}

	mainProgram, ok_m := gl.load_shaders_source(mainVertexShaderSource, mainFragShaderSource)
	if !ok_m {
		fmt.println("error while main program create")
		os.exit(1)
	}
	defer gl.DeleteProgram(mainProgram)

	lightProgram, ok_l := gl.load_shaders_source(lightVertexShaderSource, lightFragShaderSource)
	if !ok_l {
		fmt.println("error while light program create")
		os.exit(1)
	}
	defer gl.DeleteProgram(lightProgram)

	vbo: u32
	gl.GenBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(verticies), &verticies, gl.STATIC_DRAW)
	defer gl.DeleteBuffers(1, &vbo)

	cubeVAO: u32
	gl.GenVertexArrays(1, &cubeVAO)
	gl.BindVertexArray(cubeVAO)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)
	defer gl.DeleteVertexArrays(1, &cubeVAO)

	lightVAO: u32
	gl.GenVertexArrays(1, &lightVAO)
	gl.BindVertexArray(lightVAO)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), cast(uintptr)0)
	gl.EnableVertexAttribArray(0)
	defer gl.DeleteVertexArrays(1, &lightVAO)

	lastFrame := glfw.GetTime()

	for !glfw.WindowShouldClose(window) {
		deltaTime = glfw.GetTime() - lastFrame
		lastFrame = glfw.GetTime()

		processInput(window)

		gl.ClearColor(0.1, 0.1, 0.1, 1)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		projection := glm.mat4(1)
		aspect := SCREEN_WIDTH / SCREEN_HEIGHT
		projection *= glm.mat4Perspective(glm.radians_f32(f32(camera.zoom)), f32(SCREEN_WIDTH) / f32(SCREEN_HEIGHT), 0.1, 100)
		view := getViewMatrix()

		lightColor := glm.vec3{1, 1, 1}
		objectColor := glm.vec3{1, 0.5, 0.31}

		gl.UseProgram(lightProgram)
		gl.BindVertexArray(lightVAO)
		model := glm.mat4(1)
		model *= glm.mat4Translate(lightPos)
		model *= glm.mat4Scale(glm.vec3{0.2, 0.2, 0.2})
		gl.UniformMatrix4fv(gl.GetUniformLocation(lightProgram, "projection"), 1, false, &projection[0][0])
		gl.UniformMatrix4fv(gl.GetUniformLocation(lightProgram, "view"), 1, false, &view[0][0])
		gl.UniformMatrix4fv(gl.GetUniformLocation(lightProgram, "model"), 1, false, &model[0][0])
		gl.DrawArrays(gl.TRIANGLES, 0, 36)

		gl.UseProgram(mainProgram)
		gl.BindVertexArray(cubeVAO)
		model = glm.mat4(1)
		gl.UniformMatrix4fv(gl.GetUniformLocation(mainProgram, "projection"), 1, false, &projection[0][0])
		gl.UniformMatrix4fv(gl.GetUniformLocation(mainProgram, "view"), 1, false, &view[0][0])
		gl.UniformMatrix4fv(gl.GetUniformLocation(mainProgram, "model"), 1, false, &model[0][0])

		gl.Uniform3fv(gl.GetUniformLocation(mainProgram, "lightColor"), 1, &lightColor[0])
		gl.Uniform3fv(gl.GetUniformLocation(mainProgram, "objectColor"), 1, &objectColor[0])

		gl.DrawArrays(gl.TRIANGLES, 0, 36)

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
}

processInput :: proc(window: glfw.WindowHandle) {
	if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
		glfw.SetWindowShouldClose(window, true)
	}

	if glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS {
		camera.pos += CAMERA_SPEED * f32(deltaTime) * camera.front
	}
	if glfw.GetKey(window, glfw.KEY_S) == glfw.PRESS {
		camera.pos -= CAMERA_SPEED * f32(deltaTime) * camera.front
	}
	if glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS {
		camera.pos += CAMERA_SPEED * f32(deltaTime) * glm.normalize(glm.cross(camera.front, camera.up))
	}
	if glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS {
		camera.pos -= CAMERA_SPEED * f32(deltaTime) * glm.normalize(glm.cross(camera.front, camera.up))
	}
}

getViewMatrix :: proc() -> glm.mat4 {
	return glm.mat4LookAt(camera.pos, camera.pos + camera.front, camera.up)
}

resizeCallback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
}

mouseCallback :: proc "c" (window: glfw.WindowHandle, x, y: f64) {
	if isFirstTimeMouseUpdate {
		lastMousePos.x = x
		lastMousePos.y = y
		isFirstTimeMouseUpdate = false
	}

	xOffset := x - lastMousePos.x
	yOffset := lastMousePos.y - y

	lastMousePos = [2]f64{x, y}

	camera.yaw += xOffset * SENSITIVITY
	camera.pitch += yOffset * SENSITIVITY
	camera.pitch = math.clamp(camera.pitch, -89, 89)

	direction: glm.vec3
	direction.x = f32(math.cos(glm.radians_f64(camera.yaw)) * math.cos(glm.radians_f64(camera.pitch)))
	direction.y = f32(math.sin(glm.radians_f64(camera.pitch)))
	direction.z = f32(math.sin(glm.radians_f64(camera.yaw) * math.cos(glm.radians_f64(camera.pitch))))
	camera.front = glm.normalize_vec3(direction)
}

scrollCallback :: proc "c" (window: glfw.WindowHandle, x, y: f64) {
	camera.zoom -= y
	camera.zoom = math.clamp(camera.zoom, 1, 45)
}
