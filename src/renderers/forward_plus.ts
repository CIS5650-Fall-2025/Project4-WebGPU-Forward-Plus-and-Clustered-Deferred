import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ForwardPlusRenderer extends renderer.Renderer {
    // TODO-2: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution
    sceneBindGroupLayout: GPUBindGroupLayout;
    sceneBindGroup: GPUBindGroup;
    depthBufferTexture: GPUTexture;
    depthBufferView: GPUTextureView;
    forwardPlusRenderPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);
        // TODO-2: initialize layouts, pipelines, textures, etc. needed for Forward+ here

        // === Create Depth Buffer Resources ===
        this.depthBufferTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthBufferView = this.depthBufferTexture.createView();

        // === Define Scene Bind Group Layout ===
        this.sceneBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "Scene Bind Group Layout",
            entries: [
                {
                    binding: 0, // Camera uniforms
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                {
                    binding: 1, // Light set (read-only)
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                {
                    binding: 2, // Light cluster buffer (read-only)
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                }
            ]
        });

        // === Create Scene Bind Group ===
        this.sceneBindGroup = renderer.device.createBindGroup({
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
                    resource: { buffer: this.lights.clusterDataBuffer }
                }
            ]
        });

        // === Setup Forward+ Render Pipeline ===
        this.forwardPlusRenderPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                bindGroupLayouts: [
                    this.sceneBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    code: shaders.naiveVertSrc
                }),
                entryPoint: "main",
                buffers: [renderer.vertexBufferLayout]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    code: shaders.forwardPlusFragSrc
                }),
                entryPoint: "main",
                targets: [{ format: renderer.canvasFormat }]
            },
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            }
        });


    }

    override draw() {
        // TODO-2: run the Forward+ rendering pass:
        // === begin encoding commands === 
        const encoder = renderer.device.createCommandEncoder();

        // === compute light clustering before rendering === 
        this.lights.doLightClustering(encoder);

        // === prepare render targets === 
        const colorAttachmentView = renderer.context.getCurrentTexture().createView();

        const renderPassDescriptor: GPURenderPassDescriptor = {
            label: "Forward+ Render Pass",
            colorAttachments: [
                {
                    view: colorAttachmentView,
                    loadOp: "clear",
                    storeOp: "store",
                    clearValue: { r: 0, g: 0, b: 0, a: 1 },
                },
            ],
            depthStencilAttachment: {
                view: this.depthBufferView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store",
            },
        };

        // === render pass === 
        const pass = encoder.beginRenderPass(renderPassDescriptor);
        pass.setPipeline(this.forwardPlusRenderPipeline);
        pass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneBindGroup);

        // === render each object in the scene === 
        this.scene.iterate(
            model => {
                pass.setBindGroup(shaders.constants.bindGroup_model, model.modelBindGroup);
            },
            material => {
                pass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
            },
            geometry => {
                pass.setVertexBuffer(0, geometry.vertexBuffer);
                pass.setIndexBuffer(geometry.indexBuffer, 'uint32');
                pass.drawIndexed(geometry.numIndices);
            }
        );

        // === finalize render pass and submit GPU work === 
        pass.end();
        renderer.device.queue.submit([encoder.finish()]);
    }
}
