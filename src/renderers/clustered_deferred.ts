import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';
import { device } from "../renderer";

class GBuffer {
    stage: Stage;

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    gbufferAlbedoTexture: GPUTexture;
    gbufferAlbedoTextureView: GPUTextureView;
    gbufferAlbedoSampler: GPUSampler;

    gbufferNormalTexture: GPUTexture;
    gbufferNormalTextureView: GPUTextureView;
    gbufferNormalSampler: GPUSampler;

    gbufferPositionTexture: GPUTexture;
    gbufferPositionTextureView: GPUTextureView;
    gbufferPositionSampler: GPUSampler;

    gbufferPipeline: GPURenderPipeline;
    gbufferPipelineLayout: GPUPipelineLayout;
    gbufferBindGroupLayout: GPUBindGroupLayout;
    gbufferBindGroup: GPUBindGroup;

    constructor(stage: Stage) {
        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass

        this.stage = stage;

        this.depthTexture = device.createTexture({
            label: "depth texture",
            size: {width: renderer.canvas.width, height: renderer.canvas.height},
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthTextureView = this.depthTexture.createView();

        this.gbufferAlbedoTexture = device.createTexture({
            label: "g-buffer albedo texture",
            size: {width: renderer.canvas.width, height: renderer.canvas.height},
            format: "rgba8unorm",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gbufferAlbedoTextureView = this.gbufferAlbedoTexture.createView();

        this.gbufferAlbedoSampler = device.createSampler({
            magFilter: 'linear',
            minFilter: 'linear',
            addressModeU: 'clamp-to-edge',
            addressModeV: 'clamp-to-edge',
        });        

        this.gbufferNormalTexture = device.createTexture({
            label: "g-buffer normal texture",
            size: {width: renderer.canvas.width, height: renderer.canvas.height},
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gbufferNormalTextureView = this.gbufferNormalTexture.createView();

        this.gbufferNormalSampler = device.createSampler({
            magFilter: 'nearest',
            minFilter: 'nearest',
            addressModeU: 'clamp-to-edge',
            addressModeV: 'clamp-to-edge',
        });

        this.gbufferPositionTexture = device.createTexture({
            label: "g-buffer position texture",
            size: {width: renderer.canvas.width, height: renderer.canvas.height},
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gbufferPositionTextureView = this.gbufferPositionTexture.createView();

        this.gbufferPositionSampler = device.createSampler({
            magFilter: 'nearest',
            minFilter: 'nearest',
            addressModeU: 'clamp-to-edge',
            addressModeV: 'clamp-to-edge',
        });

        this.gbufferBindGroupLayout = device.createBindGroupLayout({
            label: "g-buffer bind group layout",
            entries: [
                {
                    // Camera.
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                }
            ]
        });

        this.gbufferBindGroup = device.createBindGroup({
            label: "g-buffer bind group",
            layout: this.gbufferBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.stage.camera.uniformsBuffer }
                }
            ]
        });

        this.gbufferPipelineLayout = device.createPipelineLayout({
            label: "g-buffer pipeline layout",
            bindGroupLayouts: [
                this.gbufferBindGroupLayout,
                renderer.modelBindGroupLayout,
                renderer.materialBindGroupLayout
            ]
        });

        this.gbufferPipeline = device.createRenderPipeline({
            label: "g-buffer render pipeline",
            layout: this.gbufferPipelineLayout,
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: device.createShaderModule({
                    label: "g-buffer vertex shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [renderer.vertexBufferLayout]
            },
            fragment: {
                module: device.createShaderModule({
                    label: "g-buffer fragment shader",
                    code: shaders.clusteredDeferredFragSrc,
                }),
                targets: [
                    {
                        format: "rgba8unorm",
                    },
                    {
                        format: "rgba16float",
                    },
                    {
                        format: "rgba16float",
                    }
                ]
            }
        });
    }

    draw(encoder: GPUCommandEncoder) {
        // TODO-3: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // - run the G-buffer pass, outputting position, albedo, and normals
        // - run the fullscreen pass, which reads from the G-buffer and performs lighting calculations

        const gbufferPass = encoder.beginRenderPass({
            label: "g-buffer pass",
            colorAttachments: [
                {
                    view: this.gbufferAlbedoTextureView,
                    loadOp: "clear",
                    storeOp: "store",
                    clearValue: [0, 0, 0, 1]
                },
                {
                    view: this.gbufferNormalTextureView,
                    loadOp: "clear",
                    storeOp: "store",
                    clearValue: [0, 0, 0, 1]
                },
                {
                    view: this.gbufferPositionTextureView,
                    loadOp: "clear",
                    storeOp: "store",
                    clearValue: [0, 0, 0, 1]
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });

        gbufferPass.setPipeline(this.gbufferPipeline);
        gbufferPass.setBindGroup(0, this.gbufferBindGroup);
        
        this.stage.scene.iterate(node => {
            gbufferPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            gbufferPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            gbufferPass.setVertexBuffer(0, primitive.vertexBuffer);
            gbufferPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            gbufferPass.drawIndexed(primitive.numIndices);
        });

        gbufferPass.end();
    }
}

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    gbuffer: GBuffer;

    fullscreenQuadVertexBuffer: GPUBuffer;
    fullscreenQuadVertexBufferLayout: GPUVertexBufferLayout;

    deferredBindGroupLayout: GPUBindGroupLayout;
    deferredBindGroup: GPUBindGroup;
    
    deferredPipelineLayout: GPUPipelineLayout;
    deferredPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass

        this.gbuffer = new GBuffer(stage);

        const fullscreenQuadVertices = new Float32Array([
            -1.0, -1.0,
             1.0, -1.0,
            -1.0,  1.0,
             1.0,  1.0 
        ]);

        this.fullscreenQuadVertexBuffer = device.createBuffer({
            label: "fullscreen quad vertex buffer",
            size: fullscreenQuadVertices.byteLength,
            usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST
        });
        device.queue.writeBuffer(this.fullscreenQuadVertexBuffer, 0, fullscreenQuadVertices);

        this.fullscreenQuadVertexBufferLayout = {
            arrayStride: 2 * 4,
            attributes: [
                {
                    shaderLocation: 0,
                    format: "float32x2",
                    offset: 0
                }
            ]
        };

        this.deferredBindGroupLayout = device.createBindGroupLayout({
            label: "deferred bind group layout",
            entries: [
                {
                    // Camera.
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                {
                    // G-buffer albedo texture.
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: "float",
                        viewDimension: "2d",
                        multisampled: false
                    }
                },
                {
                    // G-buffer normal texture.
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: "unfilterable-float",
                        viewDimension: "2d",
                        multisampled: false
                    }
                },
                {
                    // G-buffer position texture.
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: "unfilterable-float",
                        viewDimension: "2d",
                        multisampled: false
                    }
                },
                {
                    // G-buffer albedo sampler.
                    binding: 4,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: {}
                },
                {
                    // G-buffer normal sampler.
                    binding: 5,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: { type: "non-filtering" }
                },
                {
                    // G-buffer position sampler.
                    binding: 6,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: { type: "non-filtering" }
                },
                {
                    // Lights.
                    binding: 7,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                { 
                    // Clusters.
                    binding: 8,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                { 
                    // Cluster grid.  
                    binding: 9,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                }
            ]
        });

        this.deferredBindGroup = device.createBindGroup({
            label: "deferred bind group",
            layout: this.deferredBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: stage.camera.uniformsBuffer }
                },
                {
                    binding: 1,
                    resource: this.gbuffer.gbufferAlbedoTextureView
                },
                {
                    binding: 2,
                    resource: this.gbuffer.gbufferNormalTextureView
                },
                {
                    binding: 3,
                    resource: this.gbuffer.gbufferPositionTextureView
                },
                {
                    binding: 4,
                    resource: this.gbuffer.gbufferAlbedoSampler
                },
                {
                    binding: 5,
                    resource: this.gbuffer.gbufferNormalSampler
                },
                {
                    binding: 6,
                    resource: this.gbuffer.gbufferPositionSampler
                },
                {
                    binding: 7,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                },
                {
                    binding: 8,
                    resource: { buffer: this.lights.getClusterBuffer() }
                },
                {
                    binding: 9,
                    resource: { buffer: this.lights.getClusterGridBuffer() }
                }
            ]
        });

        this.deferredPipelineLayout = device.createPipelineLayout({
            label: "deferred pipeline layout",
            bindGroupLayouts: [
                this.deferredBindGroupLayout
            ]
        });

        this.deferredPipeline = device.createRenderPipeline({
            label: "deferred render pipeline",
            layout: this.deferredPipelineLayout,
            vertex: {
                module: device.createShaderModule({
                    label: "deferred vertex shader",
                    code: shaders.clusteredDeferredFullscreenVertSrc
                }),
                buffers: [this.fullscreenQuadVertexBufferLayout]
            },
            fragment: {
                module: device.createShaderModule({
                    label: "deferred fragment shader",
                    code: shaders.clusteredDeferredFullscreenFragSrc
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            },
            primitive: {
                topology: "triangle-strip",
                stripIndexFormat: "uint32"
            }
        });
    }

    override draw() {
        // TODO-3: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // - run the G-buffer pass, outputting position, albedo, and normals
        // - run the fullscreen pass, which reads from the G-buffer and performs lighting calculations

        const encoder = device.createCommandEncoder({label: "deferred draw command encoder"});

        this.gbuffer.draw(encoder);

        this.lights.doLightClustering(encoder);

        const deferredPass = encoder.beginRenderPass({
            label: "deferred pass",
            colorAttachments: [
                {
                    view: renderer.context.getCurrentTexture().createView(),
                    loadOp: "clear",
                    storeOp: "store",
                    clearValue: [0, 0, 0, 1]
                }
            ]
        });

        deferredPass.setVertexBuffer(0, this.fullscreenQuadVertexBuffer);
        deferredPass.setPipeline(this.deferredPipeline);
        deferredPass.setBindGroup(0, this.deferredBindGroup);

        deferredPass.draw(4, 1, 0, 0);

        deferredPass.end();

        device.queue.submit([encoder.finish()]);
    }
}
