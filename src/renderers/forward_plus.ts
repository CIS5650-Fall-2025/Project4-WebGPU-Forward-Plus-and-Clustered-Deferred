import * as renderer from "../renderer";
import * as shaders from "../shaders/shaders";
import { Stage } from "../stage/stage";

const tileSize = 32;
const maxLightsPerTile = 1000;

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
    numTilesZ: number;
    tilesUniformBuffer: GPUBuffer;
    pipelinePrez: GPURenderPipeline;

    // light culling - light intersection
    tilesLightsIdxBuffer: GPUBuffer; // light index for each tile
    tilesLightsGridBuffer: GPUBuffer; // light offset and count for each tile
    lightcullBindGroupLayout: GPUBindGroupLayout;
    lightcullBindGroup: GPUBindGroup;
    pipelineLightcull: GPUComputePipeline;

    sceneLightsBindGroupLayout: GPUBindGroupLayout;
    sceneLightsBindGroup: GPUBindGroup;

    constructor(stage: Stage) {
        super(stage);

        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene uniforms bind group layout",
            entries: [
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

        // light culling
        this.tilesUniformBuffer = renderer.device.createBuffer({
            label: "tiles uniform buffer",
            size: 2 * Uint32Array.BYTES_PER_ELEMENT,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        });

        const tilesUniformBufferArray = new Uint32Array([renderer.canvas.width, renderer.canvas.height]);
        renderer.device.queue.writeBuffer(this.tilesUniformBuffer, 0, tilesUniformBufferArray);

        this.numTilesX = Math.ceil(renderer.canvas.width / tileSize);
        this.numTilesY = Math.ceil(renderer.canvas.height / tileSize);
        this.numTilesZ = 10;

        const numTiles = this.numTilesX * this.numTilesY * this.numTilesZ;
        const bufferSize = numTiles * Int32Array.BYTES_PER_ELEMENT;

        // assume each tile accept at most 10 lights
        this.tilesLightsIdxBuffer = renderer.device.createBuffer({
            label: "tiles lights idx buffer",
            size: bufferSize * maxLightsPerTile,
            usage: GPUBufferUsage.STORAGE,
        });

        // light index offset and count for each tile
        this.tilesLightsGridBuffer = renderer.device.createBuffer({
            label: "tiles lights grid buffer",
            size: bufferSize,
            usage: GPUBufferUsage.STORAGE,
        });

        // light culling - tile per thread
        this.lightcullBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "light cull bind group layout",
            entries: [
                {
                    // screen resolution
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" },
                },
                {
                    // camera view and inv view matrix
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" },
                },
                {
                    // lightSet
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "read-only-storage" },
                },
                {
                    // tiles lights idx
                    binding: 3,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" },
                },
                {
                    // tiles lights grid
                    binding: 4,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" },
                },
            ],
        });

        this.lightcullBindGroup = renderer.device.createBindGroup({
            label: "light cull bind group",
            layout: this.lightcullBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.tilesUniformBuffer },
                },
                {
                    binding: 1,
                    resource: { buffer: this.camera.uniformsBuffer },
                },
                {
                    binding: 2,
                    resource: { buffer: this.lights.lightSetStorageBuffer },
                },
                {
                    binding: 3,
                    resource: { buffer: this.tilesLightsIdxBuffer },
                },
                {
                    binding: 4,
                    resource: { buffer: this.tilesLightsGridBuffer },
                },
            ],
        });

        this.pipelineLightcull = renderer.device.createComputePipeline({
            label: "forward plus light cull pipeline",
            layout: renderer.device.createPipelineLayout({
                label: "forward plus light cull pipeline layout",
                bindGroupLayouts: [this.lightcullBindGroupLayout],
            }),
            compute: {
                module: renderer.device.createShaderModule({
                    label: "forward plus light cull shader",
                    code: shaders.forwardPlusLightcullSrc,
                }),
                entryPoint: "computeMain",
            },
        });

        // debug
        this.sceneLightsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "debug bind group layout",
            entries: [
                {
                    // resolution
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" },
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" },
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" },
                },
            ],
        });

        this.sceneLightsBindGroup = renderer.device.createBindGroup({
            label: "debug bind group",
            layout: this.sceneLightsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.tilesUniformBuffer },
                },
                {
                    binding: 1,
                    resource: { buffer: this.tilesLightsIdxBuffer },
                },
                {
                    binding: 2,
                    resource: { buffer: this.tilesLightsGridBuffer },
                },
            ],
        });

        this.pipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "forward plus pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout,
                    this.sceneLightsBindGroupLayout,
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

        // light culling - revised
        const lightcullPass = encoder.beginComputePass();
        lightcullPass.setPipeline(this.pipelineLightcull);
        lightcullPass.setBindGroup(0, this.lightcullBindGroup);
        lightcullPass.dispatchWorkgroups(Math.ceil(this.numTilesX / 8), Math.ceil(this.numTilesY / 8), this.numTilesZ);

        lightcullPass.end();

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
        renderPass.setBindGroup(shaders.constants.bindGroup_lightcull, this.sceneLightsBindGroup);

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
