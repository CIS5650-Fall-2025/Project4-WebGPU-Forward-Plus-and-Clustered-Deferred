import * as renderer from "../renderer";
import * as shaders from "../shaders/shaders";
import { Stage } from "../stage/stage";

const tileSize = 16;
const maxLightsPerTile = 100;

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

    // light culling - light intersection
    tilesLightsIdxBuffer: GPUBuffer; // light index for each tile
    tilesLightsGridBuffer: GPUBuffer; // light offset and count for each tile

    // debug
    debugBindGroupLayout: GPUBindGroupLayout;
    debugBindGroup: GPUBindGroup;
    debugPipeline: GPURenderPipeline;

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
            usage: GPUBufferUsage.STORAGE,
        });

        this.tilesMaxBuffer = renderer.device.createBuffer({
            label: "tiles max buffer",
            size: bufferSize,
            usage: GPUBufferUsage.STORAGE,
        });

        // assume each tile accept at most 10 lights
        this.tilesLightsIdxBuffer = renderer.device.createBuffer({
            label: "tiles lights idx buffer",
            size: bufferSize * maxLightsPerTile,
            usage: GPUBufferUsage.STORAGE,
        });

        // light index offset and count for each tile
        this.tilesLightsGridBuffer = renderer.device.createBuffer({
            label: "tiles lights grid buffer",
            size: bufferSize * 2,
            usage: GPUBufferUsage.STORAGE,
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
                {
                    // lightSet
                    binding: 4,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "read-only-storage" },
                },
                {
                    // tiles lights idx
                    binding: 5,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" },
                },
                {
                    // tiles lights grid
                    binding: 6,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" },
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
                {
                    binding: 4,
                    resource: { buffer: this.lights.lightSetStorageBuffer },
                },
                {
                    binding: 5,
                    resource: { buffer: this.tilesLightsIdxBuffer },
                },
                {
                    binding: 6,
                    resource: { buffer: this.tilesLightsGridBuffer },
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
        this.debugBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "debug bind group layout",
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
                {
                    // tiles min
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" },
                },
                {
                    // tiles max
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" },
                },
                {
                    // resolution
                    binding: 4,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" },
                },
            ],
        });

        this.debugBindGroup = renderer.device.createBindGroup({
            label: "debug bind group",
            layout: this.debugBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer },
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer },
                },
                {
                    binding: 2,
                    resource: { buffer: this.tilesMinBuffer },
                },
                {
                    binding: 3,
                    resource: { buffer: this.tilesMaxBuffer },
                },
                {
                    binding: 4,
                    resource: { buffer: this.tilesUniformBuffer },
                },
            ],
        });

        this.debugPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "debug pipeline layout",
                bindGroupLayouts: [
                    this.debugBindGroupLayout,
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
                    label: "debug vert shader",
                    code: shaders.forwardPlusVertSrc,
                }),
                buffers: [renderer.vertexBufferLayout],
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "debug frag shader",
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

        // light culling - bbox calculation
        const bboxPass = encoder.beginComputePass();
        bboxPass.setPipeline(this.pipelineBbox);
        bboxPass.setBindGroup(0, this.tileBindGroup);
        bboxPass.dispatchWorkgroups(this.numTilesX, this.numTilesY, 1);
        bboxPass.end();

        // debug
        const renderPassDebug = encoder.beginRenderPass({
            label: "debug render pass",
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
        renderPassDebug.setPipeline(this.debugPipeline);
        renderPassDebug.setBindGroup(shaders.constants.bindGroup_scene, this.debugBindGroup);
        this.scene.iterate(
            (node) => {
                renderPassDebug.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
            },
            (material) => {
                renderPassDebug.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
            },
            (primitive) => {
                renderPassDebug.setVertexBuffer(0, primitive.vertexBuffer);
                renderPassDebug.setIndexBuffer(primitive.indexBuffer, "uint32");
                renderPassDebug.drawIndexed(primitive.numIndices);
            }
        );
        renderPassDebug.end();

        // // load tilesMaxBuffer and print it
        // const tileMaxReadBuffer = renderer.device.createBuffer({
        //     size: this.tilesMaxBuffer.size,
        //     usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ,
        // });
        // encoder.copyBufferToBuffer(this.tilesMaxBuffer, 0, tileMaxReadBuffer, 0, this.tilesMaxBuffer.size);
        // tileMaxReadBuffer.mapAsync(GPUMapMode.READ);
        // const tileMaxReadArray = new Float32Array(tileMaxReadBuffer.getMappedRange());
        // for (let i = 0; i < tileMaxReadArray.length; i++) {
        //     console.log(`tileMax ${tileMaxReadArray[i]}`);
        // }

        // // render pass
        // const renderPass = encoder.beginRenderPass({
        //     label: "forward plus render pass",
        //     colorAttachments: [
        //         {
        //             view: canvasTextureView,
        //             clearValue: [0, 0, 0, 0],
        //             loadOp: "clear",
        //             storeOp: "store",
        //         },
        //     ],
        //     depthStencilAttachment: {
        //         view: this.depthTextureView,
        //         depthClearValue: 1.0,
        //         depthLoadOp: "load",
        //         depthStoreOp: "store",
        //     },
        // });

        // renderPass.setPipeline(this.pipeline);
        // renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);

        // this.scene.iterate(
        //     (node) => {
        //         renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        //     },
        //     (material) => {
        //         renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        //     },
        //     (primitive) => {
        //         renderPass.setVertexBuffer(0, primitive.vertexBuffer);
        //         renderPass.setIndexBuffer(primitive.indexBuffer, "uint32");
        //         renderPass.drawIndexed(primitive.numIndices);
        //     }
        // );

        // renderPass.end();

        renderer.device.queue.submit([encoder.finish()]);
    }
}
