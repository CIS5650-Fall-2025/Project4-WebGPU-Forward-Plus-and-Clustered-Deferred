import { Mat4, mat4, Vec3, vec3 } from "wgpu-matrix";
import { toRadians } from "../math_util";
import { device, canvas, fovYDegrees, aspectRatio } from "../renderer";

class CameraUniforms {
    // Define the camera buffer, 412 bytes + 4 bytes of padding
    readonly camBuffer = new ArrayBuffer(416);

    // Define view matrices
    // Each is a 4x4 matrix = 16 Float32Array elements
    // 6 matrices x 16 elements each = 96 Float32Array elements
    // Each value in the Float32Array takes 4 bytes
    viewProjMatVals = new Float32Array(this.camBuffer, 0, 16);   
    invViewProjMatVals = new Float32Array(this.camBuffer, 64, 16);   // 0 + (16 elements * 4 bytes) = 64

    // Define view matrix and inverse view matrix
    viewMatVals = new Float32Array(this.camBuffer, 128, 16);         // 64 + (16 * 4) = 128
    invViewMatVals = new Float32Array(this.camBuffer, 192, 16);      // 128 + (16 * 4) = 192
    
    projMatVals = new Float32Array(this.camBuffer, 256, 16);         // 192 + (16 * 4) = 256
    invProjMatVals = new Float32Array(this.camBuffer, 320, 16);      // 256 + (16 * 4) = 320
    
    // Define additional view values
    // 96 elements * 4 bytes each = 384
    eyePosVals = new Float32Array(this.camBuffer, 384, 3);           // 320 + (16 * 4) = 384
    nearPlaneVal = new Float32Array(this.camBuffer, 396, 1);         // 384 + (3 * 4) = 396
    farPlaneVal = new Float32Array(this.camBuffer, 400, 1);          // 396 + 4 = 400

    // Define screen dims
    screenWidthVal = new Float32Array(this.camBuffer, 404, 1);       // 400 + 4 = 404
    screenHeightVal = new Float32Array(this.camBuffer, 408, 1);      // 404 + 4 = 408, ends at 408 + 4 = 412 bytes
}

export class Camera {
    uniforms: CameraUniforms = new CameraUniforms();
    uniformsBuffer: GPUBuffer;

    projMat: Mat4 = mat4.create();
    cameraPos: Vec3 = vec3.create(-7, 2, 0);
    cameraFront: Vec3 = vec3.create(0, 0, -1);
    cameraUp: Vec3 = vec3.create(0, 1, 0);
    cameraRight: Vec3 = vec3.create(1, 0, 0);
    yaw: number = 0;
    pitch: number = 0;
    moveSpeed: number = 0.004;
    sensitivity: number = 0.15;

    // Define screen dims
    height: number = 2056;
    width: number = 1600;

    static readonly nearPlane = 0.1;
    static readonly farPlane = 33;

    keys: { [key: string]: boolean } = {};

    constructor () {
        // DONE-1.1: set `this.uniformsBuffer` to a new buffer of size `this.uniforms.buffer.byteLength`
        // ensure the usage is set to `GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST` since we will be copying to this buffer
        // check `lights.ts` for examples of using `device.createBuffer()`
        //
        // note that you can add more variables (e.g. inverse proj matrix) to this buffer in later parts of the assignment
        this.uniformsBuffer = device.createBuffer({
            size: this.uniforms.camBuffer.byteLength,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        });

        // DONE-2: initialize extra buffers needed for light clustering here
        this.uniforms.nearPlaneVal[0] = Camera.nearPlane;
        this.uniforms.farPlaneVal[0] = Camera.farPlane;

        this.projMat = mat4.perspective(toRadians(fovYDegrees), aspectRatio, Camera.nearPlane, Camera.farPlane);

        this.rotateCamera(0, 0); // set initial camera vectors

        window.addEventListener('keydown', (event) => this.onKeyEvent(event, true));
        window.addEventListener('keyup', (event) => this.onKeyEvent(event, false));
        window.onblur = () => this.keys = {}; // reset keys on page exit so they don't get stuck (e.g. on alt + tab)

        canvas.addEventListener('mousedown', () => canvas.requestPointerLock());
        canvas.addEventListener('mouseup', () => document.exitPointerLock());
        canvas.addEventListener('mousemove', (event) => this.onMouseMove(event));
    }

    private onKeyEvent(event: KeyboardEvent, down: boolean) {
        this.keys[event.key.toLowerCase()] = down;
        if (this.keys['alt']) { // prevent issues from alt shortcuts
            event.preventDefault();
        }
    }

    private rotateCamera(dx: number, dy: number) {
        this.yaw += dx;
        this.pitch -= dy;

        if (this.pitch > 89) {
            this.pitch = 89;
        }
        if (this.pitch < -89) {
            this.pitch = -89;
        }

        const front = mat4.create();
        front[0] = Math.cos(toRadians(this.yaw)) * Math.cos(toRadians(this.pitch));
        front[1] = Math.sin(toRadians(this.pitch));
        front[2] = Math.sin(toRadians(this.yaw)) * Math.cos(toRadians(this.pitch));

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
        let moveDir = vec3.create(0, 0, 0);
        if (this.keys['w']) {
            moveDir = vec3.add(moveDir, this.cameraFront);
        }
        if (this.keys['s']) {
            moveDir = vec3.sub(moveDir, this.cameraFront);
        }
        if (this.keys['a']) {
            moveDir = vec3.sub(moveDir, this.cameraRight);
        }
        if (this.keys['d']) {
            moveDir = vec3.add(moveDir, this.cameraRight);
        }
        if (this.keys['q']) {
            moveDir = vec3.sub(moveDir, this.cameraUp);
        }
        if (this.keys['e']) {
            moveDir = vec3.add(moveDir, this.cameraUp);
        }

        let moveSpeed = this.moveSpeed * deltaTime;
        const moveSpeedMultiplier = 3;
        if (this.keys['shift']) {
            moveSpeed *= moveSpeedMultiplier;
        }
        if (this.keys['alt']) {
            moveSpeed /= moveSpeedMultiplier;
        }

        if (vec3.length(moveDir) > 0) {
            const moveAmount = vec3.scale(vec3.normalize(moveDir), moveSpeed);
            this.cameraPos = vec3.add(this.cameraPos, moveAmount);
        }
    }

    onFrame(deltaTime: number) {
        this.processInput(deltaTime);
    
        // Calculate matrix values and intermediates
        const lookPos = vec3.add(this.cameraPos, vec3.scale(this.cameraFront, 1));
        const viewMat = mat4.lookAt(this.cameraPos, lookPos, [0, 1, 0]);
        const invViewMat = mat4.invert(viewMat);
        const projMat = this.projMat;
        const invProjMat = mat4.invert(projMat);
        const viewProjMat = mat4.mul(projMat, viewMat);
        const invViewProjMat = mat4.invert(viewProjMat);
    
        // DONE-2: write to extra buffers needed for light clustering here
        this.uniforms.viewProjMatVals.set(viewProjMat);
        this.uniforms.invViewProjMatVals.set(invViewProjMat);
        this.uniforms.viewMatVals.set(viewMat);
        this.uniforms.invViewMatVals.set(invViewMat);
        this.uniforms.projMatVals.set(projMat);
        this.uniforms.invProjMatVals.set(invProjMat);

        this.uniforms.nearPlaneVal[0] = Camera.nearPlane;
        this.uniforms.farPlaneVal[0] = Camera.farPlane;
        this.uniforms.eyePosVals.set(this.cameraPos);

        this.uniforms.screenWidthVal[0] = this.width;
        this.uniforms.screenHeightVal[0] = this.height;
    
        // DONE-1.1: upload `this.uniforms.buffer` (host side) to `this.uniformsBuffer` (device side)
        // check `lights.ts` for examples of using `device.queue.writeBuffer()`
        device.queue.writeBuffer(this.uniformsBuffer, 0, this.uniforms.camBuffer);
    }
}