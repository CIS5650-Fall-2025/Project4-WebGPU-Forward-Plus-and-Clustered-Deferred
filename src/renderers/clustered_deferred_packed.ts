import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredPackedRenderer extends renderer.Renderer {
    sceneBindGroupLayout: GPUBindGroupLayout;
    sceneBindGroup: GPUBindGroup;
    gBufferGroupLayout: GPUBindGroupLayout;
    gBufferBindGroup: GPUBindGroup;

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;
    packedTexture: GPUTexture;
    packedTextureView: GPUTextureView;

    gBufferPipeline: GPURenderPipeline
    fullscreenPipeline: GPURenderPipeline

    constructor(stage: Stage) {
        super(stage);

        this.packedTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba32uint",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.STORAGE_BINDING
        });
        this.packedTextureView = this.packedTexture.createView();

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
                { // g-buffer texture
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    storageTexture: {
                        access: "read-only",
                        format: this.packedTexture.format,
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
                    resource: this.packedTextureView
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
                    code: shaders.clusteredDeferredPackedFragSrc,
                }),
                targets: [
                    {
                        format: this.packedTexture.format
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
                    code: shaders.clusteredDeferredFullscreenPackedFragSrc,
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
                    view: this.packedTextureView,
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