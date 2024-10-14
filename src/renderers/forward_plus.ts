import * as renderer from "../renderer";
import * as shaders from "../shaders/shaders";
import { Stage } from "../stage/stage";

const tileSize = 16;

export class ForwardPlusRenderer extends renderer.Renderer {
    // TODO-2: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution
    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    pipeline: GPURenderPipeline;

    // light culling
    numTilesX: number;
    numTilesY: number;
    tileBindGroupLayout: GPUBindGroupLayout;
    tileBindGroup: GPUBindGroup;
    tilesUniformBuffer: GPUBuffer;
    tilesMinBuffer: GPUBuffer;
    tilesMaxBuffer: GPUBuffer;
    pipelineLayoutPrez: GPUPipelineLayout;
    pipelinePrez: GPURenderPipeline;
    pipelineBbox: GPUComputePipeline;

    // debug
    uniformBuffer: GPUBuffer;
    xVectorGPUBuffer: GPUBuffer;
    yVectorGPUBuffer: GPUBuffer;
    zVectorGPUBuffer: GPUBuffer;
    saxpyCSBindGroupLayout: GPUBindGroupLayout;
    saxpyCSBindGroup: GPUBindGroup;
    saxpyCSPipelineLayout: GPUPipelineLayout;
    saxpyCSPipeline: GPUComputePipeline;

    constructor(stage: Stage) {
        super(stage);

        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene uniforms bind group layout",
            entries: [
                // TODO-1.2: add an entry for camera uniforms at binding 0, visible to only the vertex shader, and of type "uniform"
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: { type: "uniform" },
                },
                {
                    // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" },
                },
            ],
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                // TODO-1.2: add an entry for camera uniforms at binding 0
                // you can access the camera using `this.camera`
                // if you run into TypeScript errors, you're probably trying to upload the host buffer instead
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer },
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer },
                },
            ],
        });

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
        });
        this.depthTextureView = this.depthTexture.createView();

        this.pipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "forward plus pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout,
                ],
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus",
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "forward plus vert shader",
                    code: shaders.forwardPlusVertSrc,
                }),
                buffers: [renderer.vertexBufferLayout],
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "forward plus frag shader",
                    code: shaders.forwardPlusFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    },
                ],
            },
        });

        // prez pass
        this.pipelinePrez = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "forward plus prez pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout,
                ],
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus",
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "forward plus vert shader",
                    code: shaders.forwardPlusVertSrc,
                }),
                buffers: [renderer.vertexBufferLayout],
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "forward plus prez frag shader",
                    code: shaders.forwardPlusPassthroughSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    },
                ],
            },
        });

        // light culling - bbox calculation
        this.tilesUniformBuffer = renderer.device.createBuffer({
            label: "tiles uniform buffer",
            size: 2 * Uint32Array.BYTES_PER_ELEMENT,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        });
        const tilesUniformBufferArray = new Uint32Array([renderer.canvas.width, renderer.canvas.height]);
        renderer.device.queue.writeBuffer(this.tilesUniformBuffer, 0, tilesUniformBufferArray);

        this.numTilesX = Math.ceil(renderer.canvas.width / tileSize);
        this.numTilesY = Math.ceil(renderer.canvas.height / tileSize);

        const numTiles = this.numTilesX * this.numTilesY;
        const bufferSize = numTiles * Float32Array.BYTES_PER_ELEMENT;

        this.tilesMinBuffer = renderer.device.createBuffer({
            label: "tiles min buffer",
            size: bufferSize,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC,
        });

        this.tilesMaxBuffer = renderer.device.createBuffer({
            label: "tiles max buffer",
            size: bufferSize,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC,
        });

        this.tileBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "tile bind group layout",
            entries: [
                {
                    // screen resolution
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" },
                },
                {
                    // tiles min
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" },
                },
                {
                    // tiles max
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" },
                },
                {
                    // depth
                    binding: 3,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: {
                        sampleType: "depth",
                        viewDimension: "2d",
                    },
                },
            ],
        });

        this.tileBindGroup = renderer.device.createBindGroup({
            label: "tile bind group",
            layout: this.tileBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.tilesUniformBuffer },
                },
                {
                    binding: 1,
                    resource: { buffer: this.tilesMinBuffer },
                },
                {
                    binding: 2,
                    resource: { buffer: this.tilesMaxBuffer },
                },
                {
                    binding: 3,
                    resource: this.depthTextureView,
                },
            ],
        });

        this.pipelineLayoutPrez = renderer.device.createPipelineLayout({
            label: "forward plus prez pipeline layout",
            bindGroupLayouts: [this.tileBindGroupLayout],
        });

        this.pipelineBbox = renderer.device.createComputePipeline({
            label: "forward plus bbox pipeline",
            layout: this.pipelineLayoutPrez,
            compute: {
                module: renderer.device.createShaderModule({
                    label: "forward plus bbox shader",
                    code: shaders.forwardPlusBboxSrc,
                }),
                entryPoint: "computeMain",
            },
        });

        // debug
        const arrLen = 256;
        const scalar = 2;
        this.uniformBuffer = renderer.device.createBuffer({
            label: "uniform buffer",
            size: 2 * Float32Array.BYTES_PER_ELEMENT,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        });
        const uniformBufferArray = new Float32Array([arrLen, scalar]);
        renderer.device.queue.writeBuffer(this.uniformBuffer, 0, uniformBufferArray);

        this.xVectorGPUBuffer = renderer.device.createBuffer({
            label: "x vector buffer",
            size: arrLen * Float32Array.BYTES_PER_ELEMENT,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        });
        // create x vector of length arrLen
        const xVectorArray = new Float32Array(arrLen);
        for (let i = 0; i < arrLen; i++) {
            xVectorArray[i] = 1;
        }
        renderer.device.queue.writeBuffer(this.xVectorGPUBuffer, 0, xVectorArray);

        this.yVectorGPUBuffer = renderer.device.createBuffer({
            label: "y vector buffer",
            size: arrLen * Float32Array.BYTES_PER_ELEMENT,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        });
        // create y vector of length arrLen
        const yVectorArray = new Float32Array(arrLen);
        for (let i = 0; i < arrLen; i++) {
            yVectorArray[i] = 2;
        }
        renderer.device.queue.writeBuffer(this.yVectorGPUBuffer, 0, yVectorArray);

        this.zVectorGPUBuffer = renderer.device.createBuffer({
            label: "z vector buffer",
            size: arrLen * Float32Array.BYTES_PER_ELEMENT,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC,
        });

        this.saxpyCSBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "saxpy compute bind group layout",
            entries: [
                {
                    // uniform
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" },
                },
                {
                    // x vector
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "read-only-storage" },
                },
                {
                    // y vector
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "read-only-storage" },
                },
                {
                    // z vector
                    binding: 3,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" },
                },
                {
                    // depth
                    binding: 4,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: {
                        sampleType: "depth",
                        viewDimension: "2d",
                    },
                },
            ],
        });

        this.saxpyCSBindGroup = renderer.device.createBindGroup({
            label: "saxpy compute bind group",
            layout: this.saxpyCSBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.uniformBuffer },
                },
                {
                    binding: 1,
                    resource: { buffer: this.xVectorGPUBuffer },
                },
                {
                    binding: 2,
                    resource: { buffer: this.yVectorGPUBuffer },
                },
                {
                    binding: 3,
                    resource: { buffer: this.zVectorGPUBuffer },
                },
                {
                    binding: 4,
                    resource: this.depthTextureView,
                },
            ],
        });

        this.saxpyCSPipelineLayout = renderer.device.createPipelineLayout({
            label: "saxpy compute pipeline layout",
            bindGroupLayouts: [this.saxpyCSBindGroupLayout],
        });

        this.saxpyCSPipeline = renderer.device.createComputePipeline({
            label: "saxpy compute pipeline",
            layout: this.saxpyCSPipelineLayout,
            compute: {
                module: renderer.device.createShaderModule({
                    label: "saxpy compute shader",
                    code: shaders.debugComputeSrc,
                }),
                entryPoint: "computeMain",
            },
        });
    }

    override draw() {
        const encoder = renderer.device.createCommandEncoder();
        const canvasTextureView = renderer.context.getCurrentTexture().createView();

        // prez pass
        const renderPassPrez = encoder.beginRenderPass({
            label: "forward plus render pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store",
                },
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store",
            },
        });
        renderPassPrez.setPipeline(this.pipelinePrez);
        renderPassPrez.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);
        renderPassPrez.end();

        // light culling - bbox calculation
        const bboxPass = encoder.beginComputePass();
        bboxPass.setPipeline(this.pipelineBbox);
        bboxPass.setBindGroup(0, this.tileBindGroup);
        bboxPass.dispatchWorkgroups(this.numTilesX, this.numTilesY, 1);
        bboxPass.end();

        // debug
        // const saxpyPass = encoder.beginComputePass();
        // saxpyPass.setPipeline(this.saxpyCSPipeline);
        // saxpyPass.setBindGroup(0, this.saxpyCSBindGroup);
        // saxpyPass.dispatchWorkgroups(256);
        // saxpyPass.end();

        // render pass
        const renderPass = encoder.beginRenderPass({
            label: "forward plus render pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store",
                },
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "load",
                depthStoreOp: "store",
            },
        });

        renderPass.setPipeline(this.pipeline);
        renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);

        this.scene.iterate(
            (node) => {
                renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
            },
            (material) => {
                renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
            },
            (primitive) => {
                renderPass.setVertexBuffer(0, primitive.vertexBuffer);
                renderPass.setIndexBuffer(primitive.indexBuffer, "uint32");
                renderPass.drawIndexed(primitive.numIndices);
            }
        );

        renderPass.end();

        renderer.device.queue.submit([encoder.finish()]);
    }
}
