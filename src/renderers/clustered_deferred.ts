import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution
    sceneBindGroupLayout: GPUBindGroupLayout;
    sceneBindGroup: GPUBindGroup;
    gBufferGroupLayout: GPUBindGroupLayout;
    gBufferBindGroup: GPUBindGroup;

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;
    positionTexture: GPUTexture;
    positionTextureView: GPUTextureView;
    albedoTexture: GPUTexture;
    albedoTextureView: GPUTextureView;
    normalTexture: GPUTexture;
    normalTextureView: GPUTextureView;

    gBufferPipeline: GPURenderPipeline
    fullscreenPipeline: GPURenderPipeline


    constructor(stage: Stage) {
        super(stage);

        this.positionTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.STORAGE_BINDING
        });
        this.positionTextureView = this.positionTexture.createView();

        this.albedoTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "bgra8unorm",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING 
        }); // storage-binding not available by default for rgba8unorm
        this.albedoTextureView = this.albedoTexture.createView();

        this.normalTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.STORAGE_BINDING
        });
        this.normalTextureView = this.normalTexture.createView();

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthTextureView = this.depthTexture.createView();

        this.sceneBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene bind group layout",
            entries: [
                { // cameraUniforms
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.VERTEX,
                    buffer: { type: "uniform" }
                },
                { // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                { // clusterSet
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                }
            ]
        });

        this.sceneBindGroup = renderer.device.createBindGroup({
            label: "scene bind group",
            layout: this.sceneBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                },
                {
                    binding: 2,
                    resource: { buffer: this.lights.clusterSetStorageBuffer }
                }
            ]
        });

        this.gBufferGroupLayout = renderer.device.createBindGroupLayout({
            label: "g-buffer group layout",
            entries: [
                { // position texture
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    storageTexture: {
                        access: "read-only",
                        format: "rgba16float",
                    }
                },
                { // albedo texture
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: "unfilterable-float"
                    }
                },
                { // normal texture
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    storageTexture: {
                        access: "read-only",
                        format: "rgba16float",
                    }
                }
            ]
        });

        this.gBufferBindGroup = renderer.device.createBindGroup({
            label: "g-buffer bind group",
            layout: this.gBufferGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.positionTextureView
                },
                {
                    binding: 1,
                    resource: this.albedoTextureView
                },
                {
                    binding: 2,
                    resource: this.normalTextureView
                }
            ]
        });

        this.gBufferPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "g-buffer pipeline layout",
                bindGroupLayouts: [
                    this.sceneBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
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
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "g-buffer fragment shader",
                    code: shaders.clusteredDeferredFragSrc,
                }),
                targets: [
                    {
                        format: this.positionTexture.format,
                    },
                    {
                        format: this.albedoTexture.format,
                    },
                    {
                        format: this.normalTexture.format,
                    }
                ]
            }
        });

        this.fullscreenPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "fullscreen pass pipeline layout",
                bindGroupLayouts: [
                    this.sceneBindGroupLayout,
                    this.gBufferGroupLayout
                ]
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "fullscreen pass vertex shader",
                    code: shaders.clusteredDeferredFullscreenVertSrc
                })
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "fullscreen pass fragment shader",
                    code: shaders.clusteredDeferredFullscreenFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            },
            primitive: {
                topology: "triangle-strip"
            }
        });
    }

    override draw() {
        const encoder = renderer.device.createCommandEncoder();
        const canvasTextureView = renderer.context.getCurrentTexture().createView();

        this.lights.doLightClustering(encoder);

        const gBufferPass = encoder.beginRenderPass({
            label: "g-buffer render pass",
            colorAttachments: [
                {
                    view: this.positionTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.albedoTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.normalTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });
        gBufferPass.setPipeline(this.gBufferPipeline);
        gBufferPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneBindGroup);
        this.scene.iterate(
            node => {
                gBufferPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
            },
            material => {
                gBufferPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
            },
            primitive => {
                gBufferPass.setVertexBuffer(0, primitive.vertexBuffer);
                gBufferPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
                gBufferPass.drawIndexed(primitive.numIndices);
            }
        );
        gBufferPass.end();

        const fullscreenPass = encoder.beginRenderPass({
            label: "fullscreen render pass",
            colorAttachments: [{
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
            }]
        });
        fullscreenPass.setPipeline(this.fullscreenPipeline);
        fullscreenPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneBindGroup);
        fullscreenPass.setBindGroup(1, this.gBufferBindGroup);
        fullscreenPass.draw(4);
        fullscreenPass.end();

        renderer.device.queue.submit([encoder.finish()]);
        

    }
}
