import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    gbufferAlbedoTexture: GPUTexture;
    gbufferAlbedoTextureView: GPUTextureView;
    gbufferNormalTexture: GPUTexture;
    gbufferNormalTextureView: GPUTextureView;
    gbufferPositionTexture: GPUTexture;
    gbufferPositionTextureView: GPUTextureView;

    gbufferPipeline: GPURenderPipeline;
    gbufferPipelineLayout: GPUPipelineLayout;
    gbufferBindGroupLayout: GPUBindGroupLayout;
    gbufferBindGroup: GPUBindGroup;

    constructor(stage: Stage) {
        super(stage);

        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass

        this.depthTexture = renderer.device.createTexture({
            label: "depth texture",
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthTextureView = this.depthTexture.createView();

        this.gbufferAlbedoTexture = renderer.device.createTexture({
            label: "g-buffer albedo texture",
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba8unorm",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gbufferAlbedoTextureView = this.gbufferAlbedoTexture.createView();

        this.gbufferNormalTexture = renderer.device.createTexture({
            label: "g-buffer normal texture",
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gbufferNormalTextureView = this.gbufferNormalTexture.createView();

        this.gbufferPositionTexture = renderer.device.createTexture({
            label: "g-buffer position texture",
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gbufferPositionTextureView = this.gbufferPositionTexture.createView();

        this.gbufferBindGroupLayout = renderer.device.createBindGroupLayout({
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

        this.gbufferBindGroup = renderer.device.createBindGroup({
            label: "g-buffer bind group",
            layout: this.gbufferBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                }
            ]
        });

        this.gbufferPipelineLayout = renderer.device.createPipelineLayout({
            label: "g-buffer pipeline layout",
            bindGroupLayouts: [
                this.gbufferBindGroupLayout,
                renderer.modelBindGroupLayout,
                renderer.materialBindGroupLayout
            ]
        });

        this.gbufferPipeline = renderer.device.createRenderPipeline({
            label: "g-buffer render pipeline",
            layout: this.gbufferPipelineLayout,
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "g-buffer vertex shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [renderer.vertexBufferLayout]
            },
            fragment: {
                module: renderer.device.createShaderModule({
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

    override draw() {
        // TODO-3: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // - run the G-buffer pass, outputting position, albedo, and normals
        // - run the fullscreen pass, which reads from the G-buffer and performs lighting calculations

        const encoder = renderer.device.createCommandEncoder();

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
        
        this.scene.iterate(node => {
            gbufferPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            gbufferPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            gbufferPass.setVertexBuffer(0, primitive.vertexBuffer);
            gbufferPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            gbufferPass.drawIndexed(primitive.numIndices);
        });

        gbufferPass.end();
        renderer.device.queue.submit([encoder.finish()]);
    }
}
