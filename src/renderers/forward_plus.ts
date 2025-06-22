import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ForwardPlusRenderer extends renderer.Renderer {
    // TODO-2: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution
    sceneBindGroupLayout: GPUBindGroupLayout;
    sceneBindGroup: GPUBindGroup;
    depthBuffer: GPUTexture;
    depthView: GPUTextureView;

    clusteredLightingPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        // TODO-2: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // ─────────────── Depth texture setup ───────────────
        this.depthBuffer = renderer.device.createTexture({
            label: "Depth Buffer",
            size: {
                width: renderer.canvas.width,
                height: renderer.canvas.height,
                depthOrArrayLayers: 1
            },
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthView = this.depthBuffer.createView();

        // ─────────────── Scene bind group layout ───────────────
        this.sceneBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "Scene Bind Group Layout",
            entries: [
                {
                    binding: 0, // Camera uniform
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                {
                    binding: 1, // Light data (read-only)
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                {
                    binding: 2, // Cluster data (read-only)
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                }]
        });

        // ─────────────── Scene bind group ───────────────
        this.sceneBindGroup = renderer.device.createBindGroup({
            label: "Scene Bind Group",
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
                    resource: { buffer: this.lights.clusterSetBuffer }
                }]
        });

        // ─────────────── Forward+ Render Pipeline ───────────────
        this.clusteredLightingPipeline = renderer.device.createRenderPipeline({
            label: "Clustered Lighting Pipeline",
            layout: renderer.device.createPipelineLayout({
                label: "Clustered Lighting Pipeline Layout",
                bindGroupLayouts: [
                    this.sceneBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout]
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

        const encoder = renderer.device.createCommandEncoder();
        this.lights.doLightClustering(encoder);

        // ───── get current canvas view ─────
        const colorAttachment: GPURenderPassColorAttachment = {
            view: renderer.context.getCurrentTexture().createView(),
            clearValue: [0.0, 0.0, 0.0, 1.0],
            loadOp: "clear",
            storeOp: "store"
        };

        // ───── configure depth attachment ─────
        const depthAttachment: GPURenderPassDepthStencilAttachment = {
            view: this.depthView,
            depthClearValue: 1.0,
            depthLoadOp: "clear",
            depthStoreOp: "store"
        };

        // ───── begin the render pass ─────
        const renderPass = encoder.beginRenderPass({
            label: "Forward+ Render Pass",
            colorAttachments: [colorAttachment],
            depthStencilAttachment: depthAttachment
        });

        // ───── set pipeline and scene bind group ─────
        renderPass.setPipeline(this.clusteredLightingPipeline);
        renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneBindGroup);

        // ───── draw each object in the scene ─────
        this.scene.iterate(
            node => {
                renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
            },
            material => {
                renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
            },
            primitive => {
                renderPass.setVertexBuffer(0, primitive.vertexBuffer);
                renderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
                renderPass.drawIndexed(primitive.numIndices);
            }
        );

        // ───── end the render pass ─────
        renderPass.end();

        // ───── submit all GPU commands ─────
        renderer.device.queue.submit([encoder.finish()]);
    }
}
