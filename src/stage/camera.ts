import { Mat4, mat4, Vec3, vec3 } from "wgpu-matrix";
import { toRadians } from "../math_util";
import { device, canvas, fovYDegrees, aspectRatio } from "../renderer";

// Helper class to manage the uniform buffer layout for the GPU
class CameraUniforms {
    readonly buffer = new ArrayBuffer(416);
    private readonly viewProjMatrixBuffer    = new Float32Array(this.buffer,   0, 16);
    private readonly invViewProjMatrixBuffer = new Float32Array(this.buffer,  64, 16);
    private readonly viewMatrixBuffer        = new Float32Array(this.buffer, 128, 16);
    private readonly invViewMatrixBuffer     = new Float32Array(this.buffer, 192, 16);
    private readonly projMatrixBuffer        = new Float32Array(this.buffer, 256, 16);
    private readonly invProjMatrixBuffer     = new Float32Array(this.buffer, 320, 16);

    private readonly cameraPositionBuffer         = new Float32Array(this.buffer, 384, 3);
    private readonly nearPlaneBuffer      = new Float32Array(this.buffer, 396, 1);
    private readonly farPlaneBuffer       = new Float32Array(this.buffer, 400, 1);
    private readonly screenWidthBuffer          = new Float32Array(this.buffer, 404, 1);
    private readonly screenHeightBuffer         = new Float32Array(this.buffer, 408, 1);

    set setViewProjectionMatrix(mat: Float32Array)    { this.viewProjMatrixBuffer.set(mat); }
    set setInverseViewProjectionMatrix(mat: Float32Array) { this.invViewProjMatrixBuffer.set(mat); }
    set setViewMatrix(mat: Float32Array)        { this.viewMatrixBuffer.set(mat); }
    set setInverseViewMatrix(mat: Float32Array)     { this.invViewMatrixBuffer .set(mat); }
    set setProjectionMatrix(mat: Float32Array)        { this.projMatrixBuffer.set(mat); }
    set setInverseProjectionMatrix(mat: Float32Array)     { this.invProjMatrixBuffer.set(mat); }


    set setCameraPosition(pos: Float32Array)         { this.cameraPositionBuffer.set(pos); }
    set setNearPlane(value: number)          { this.nearPlaneBuffer[0] = value; }
    set setFarPlane(value: number)           { this.farPlaneBuffer[0] = value; }
    set setScreenWidth(value: number)              { this.screenWidthBuffer[0] = value; }
    set setScreenHeight(value: number)             { this.screenHeightBuffer[0] = value; }
}

export class Camera {
    uniforms = new CameraUniforms();
    uniformsBuffer: GPUBuffer;

    projMat: Mat4 = mat4.create();
    cameraPos: Vec3 = vec3.create(-7, 2, 0);
    cameraFront: Vec3 = vec3.create(0, 0, -1);
    cameraUp: Vec3 = vec3.create(0, 1, 0);
    cameraRight: Vec3 = vec3.create(1, 0, 0);
    yaw = 0;
    pitch = 0;
    moveSpeed = 0.004;
    sensitivity = 0.15;
    width = 1024;
    height = 1024;

    static readonly nearPlane = 0.1;
    static readonly farPlane = 1000;

    keys: Record<string, boolean> = {};

    constructor() {
        // TODO-1.1: set `this.uniformsBuffer` to a new buffer of size `this.uniforms.buffer.byteLength`
        // ensure the usage is set to `GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST` since we will be copying to this buffer
        // check `lights.ts` for examples of using `device.createBuffer()`
        //
        // note that you can add more variables (e.g. inverse proj matrix) to this buffer in later parts of the assignment
        this.uniformsBuffer = device.createBuffer({
            size: this.uniforms.buffer.byteLength,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        });

        // TODO-2: initialize extra buffers needed for light clustering here
        this.uniforms.setNearPlane = Camera.nearPlane;
        this.uniforms.setFarPlane = Camera.farPlane;

        this.projMat = mat4.perspective(toRadians(fovYDegrees), aspectRatio, Camera.nearPlane, Camera.farPlane);

        this.rotateCamera(0, 0);

        window.addEventListener('keydown', e => this.onKeyEvent(e, true));
        window.addEventListener('keyup', e => this.onKeyEvent(e, false));
        window.onblur = () => (this.keys = {});

        canvas.addEventListener('mousedown', () => canvas.requestPointerLock());
        canvas.addEventListener('mouseup', () => document.exitPointerLock());
        canvas.addEventListener('mousemove', e => this.onMouseMove(e));
    }

    private onKeyEvent(event: KeyboardEvent, down: boolean) {
        this.keys[event.key.toLowerCase()] = down;
        if (this.keys['alt']) event.preventDefault();
    }

    private rotateCamera(dx: number, dy: number) {
        this.yaw += dx;
        this.pitch = Math.max(-89, Math.min(89, this.pitch - dy));

        const front = vec3.create(
            Math.cos(toRadians(this.yaw)) * Math.cos(toRadians(this.pitch)),
            Math.sin(toRadians(this.pitch)),
            Math.sin(toRadians(this.yaw)) * Math.cos(toRadians(this.pitch))
        );

        this.cameraFront = vec3.normalize(front);
        this.cameraRight = vec3.normalize(vec3.cross(this.cameraFront, [0, 1, 0]));
        this.cameraUp = vec3.normalize(vec3.cross(this.cameraRight, this.cameraFront));
    }

    private onMouseMove(event: MouseEvent) {
        if (document.pointerLockElement === canvas) {
            this.rotateCamera(event.movementX * this.sensitivity, event.movementY * this.sensitivity);
        }
    }

    private processInput(deltaTime: number) {
        let moveDir = vec3.create();

        if (this.keys['w']) moveDir = vec3.add(moveDir, this.cameraFront);
        if (this.keys['s']) moveDir = vec3.sub(moveDir, this.cameraFront);
        if (this.keys['a']) moveDir = vec3.sub(moveDir, this.cameraRight);
        if (this.keys['d']) moveDir = vec3.add(moveDir, this.cameraRight);
        if (this.keys['q']) moveDir = vec3.sub(moveDir, this.cameraUp);
        if (this.keys['e']) moveDir = vec3.add(moveDir, this.cameraUp);

        let speed = this.moveSpeed * deltaTime;
        if (this.keys['shift']) speed *= 3;
        if (this.keys['alt']) speed /= 3;

        if (vec3.length(moveDir) > 0) {
            this.cameraPos = vec3.add(this.cameraPos, vec3.scale(vec3.normalize(moveDir), speed));
        }
    }

    onFrame(deltaTime: number) {
        this.processInput(deltaTime);

        const viewTarget  = vec3.add(this.cameraPos, vec3.scale(this.cameraFront, 1));
        const viewMatrix  = mat4.lookAt(this.cameraPos, viewTarget , this.cameraUp);
        const inverseViewMatrix  = mat4.invert(viewMatrix );
        const inverseProjectionMatrix  = mat4.invert(this.projMat);
        const viewProjectionMatrix  = mat4.mul(this.projMat, viewMatrix );
        const inverseViewProjectionMatrix  = mat4.invert(viewProjectionMatrix );

        // TODO-1.1 & TODO-2
        this.uniforms.setViewProjectionMatrix = viewProjectionMatrix ;
        this.uniforms.setInverseViewProjectionMatrix = inverseViewProjectionMatrix ;
        this.uniforms.setViewMatrix = viewMatrix ;
        this.uniforms.setInverseViewMatrix = inverseViewMatrix ;
        this.uniforms.setProjectionMatrix = this.projMat;
        this.uniforms.setInverseProjectionMatrix = inverseProjectionMatrix ;
        this.uniforms.setCameraPosition = this.cameraPos;
        this.uniforms.setScreenWidth = this.width;
        this.uniforms.setScreenHeight = this.height;

        device.queue.writeBuffer(this.uniformsBuffer, 0, this.uniforms.buffer);
    }
}
