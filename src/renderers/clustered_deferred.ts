import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // DONE-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    // Bind group and pipeline layout for scene
    sceneBindGroupLayout: GPUBindGroupLayout;
    sceneBindGroup: GPUBindGroup;
    
    // Render target and depth textures
    renderTargetTexture: GPUTexture;
    renderTargetTextureView: GPUTextureView;
    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;
    
    // Render pipeline and shader modules for clustered deferred rendering
    clusteredDeferredPipelineLayout: GPUPipelineLayout;
    clusteredDeferredVertexShaderModule: GPUShaderModule;
    clusteredDeferredFragmentShaderModule: GPUShaderModule;
    clusteredDeferredPipeline: GPURenderPipeline;
    
    // Bind group and pipeline layout for the final pass
    finalPassBindGroupLayout: GPUBindGroupLayout;
    finalPassBindGroup: GPUBindGroup;
    finalPassPipelineLayout: GPUPipelineLayout;
    finalPassPipelineVertexShaderModule: GPUShaderModule;
    finalPassPipelineFragmentShaderModule: GPUShaderModule;
    finalPassPipeline: GPURenderPipeline;
    
    constructor(stage: Stage) {
        super(stage);
        // DONE-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass

        // Initialize bind group for scene
        this.sceneBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "sceneBindGroupLayout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" },
                },
            ],
        });

        this.sceneBindGroup = renderer.device.createBindGroup({
            label: "sceneBindGroup",
            layout: this.sceneBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer },
                },
            ],
        });

        // Create render target and depth textures
        this.renderTargetTexture = renderer.device.createTexture({
            label: "renderTargetTexture",
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba32float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
        });
        this.renderTargetTextureView = this.renderTargetTexture.createView();

        this.depthTexture = renderer.device.createTexture({
            label: "depthTexture",
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
        });
        this.depthTextureView = this.depthTexture.createView();

        // Set up clustered deferred render pipeline layout
        this.clusteredDeferredPipelineLayout = renderer.device.createPipelineLayout({
            label: "clusteredDeferredPipelineLayout",
            bindGroupLayouts: [
                this.sceneBindGroupLayout,
                renderer.modelBindGroupLayout,
                renderer.materialBindGroupLayout,
            ],
        });

        // Compile shaders for clustered deferred pipeline
        this.clusteredDeferredVertexShaderModule = renderer.device.createShaderModule({
            label: "clusteredDeferredVertexShaderModule",
            code: shaders.naiveVertSrc,
        });
        this.clusteredDeferredFragmentShaderModule = renderer.device.createShaderModule({
            label: "clusteredDeferredFragmentShaderModule",
            code: shaders.clusteredDeferredFragSrc,
        });

        // Create clustered deferred pipeline
        this.clusteredDeferredPipeline = renderer.device.createRenderPipeline({
            label: "clusteredDeferredPipeline",
            layout: this.clusteredDeferredPipelineLayout,
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus",
            },
            vertex: {
                module: this.clusteredDeferredVertexShaderModule,
                buffers: [renderer.vertexBufferLayout],
            },
            fragment: {
                module: this.clusteredDeferredFragmentShaderModule,
                targets: [{ format: "rgba32float" }],
            },
        });

        // Initialize final pass pipeline bind group and layout
        this.finalPassBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "finalPassBindGroupLayout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" },
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: 'unfilterable-float' },
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: { type: 'non-filtering' },
                },
                {
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: 'unfilterable-float' },
                },
                {
                    binding: 4,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" },
                },
            ],
        });

        this.finalPassBindGroup = renderer.device.createBindGroup({
            label: "finalPassBindGroup",
            layout: this.finalPassBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer },
                },
                {
                    binding: 1,
                    resource: this.renderTargetTextureView,
                },
                {
                    binding: 2,
                    resource: renderer.device.createSampler(),
                },
                {
                    binding: 3,
                    resource: this.depthTextureView,
                },
                {
                    binding: 4,
                    resource: { buffer: this.lights.lightSetStorageBuffer },
                },
            ],
        });

        // Set up final pass pipeline layout and shaders
        this.finalPassPipelineLayout = renderer.device.createPipelineLayout({
            label: "finalPassPipelineLayout",
            bindGroupLayouts: [this.finalPassBindGroupLayout, this.lights.clusterBindGroupLayout],
        });

        this.finalPassPipelineVertexShaderModule = renderer.device.createShaderModule({
            label: "finalPassPipelineVertexShaderModule",
            code: shaders.clusteredDeferredFullscreenVertSrc,
        });
        this.finalPassPipelineFragmentShaderModule = renderer.device.createShaderModule({
            label: "finalPassPipelineFragmentShaderModule",
            code: shaders.clusteredDeferredFullscreenFragSrc,
        });

        // Create the final pass pipeline
        this.finalPassPipeline = renderer.device.createRenderPipeline({
            label: "finalPassPipeline",
            layout: this.finalPassPipelineLayout,
            vertex: { module: this.finalPassPipelineVertexShaderModule },
            fragment: {
                module: this.finalPassPipelineFragmentShaderModule,
                targets: [{ format: renderer.canvasFormat }],
            },
        });
    }

    override draw() {
        const encoder = renderer.device.createCommandEncoder();

        // Run light clustering compute shader
        this.lights.doLightClustering(encoder);

        // Set up the render pass for the render target texture
        const attachmentView = renderer.context.getCurrentTexture().createView();
        const renderPass = encoder.beginRenderPass({
            label: "renderPass",
            colorAttachments: [
                {
                    view: this.renderTargetTextureView,
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

        renderPass.setPipeline(this.clusteredDeferredPipeline);
        renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneBindGroup);

        // Iterate over scene nodes, bind resources, and draw
        this.scene.iterate(
            node => renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup),
            material => renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup),
            primitive => {
                renderPass.setVertexBuffer(0, primitive.vertexBuffer);
                renderPass.setIndexBuffer(primitive.indexBuffer, "uint32");
                renderPass.drawIndexed(primitive.numIndices);
            }
        );

        renderPass.end();

        // Final pass to render the scene to the screen
        const finalPass = encoder.beginRenderPass({
            label: "finalPass",
            colorAttachments: [{ view: attachmentView, loadOp: "clear", storeOp: "store" }],
        });

        finalPass.setPipeline(this.finalPassPipeline);
        finalPass.setBindGroup(0, this.finalPassBindGroup);
        finalPass.setBindGroup(1, this.lights.clusterBindGroup);
        finalPass.draw(6);

        finalPass.end();

        // Submit the commands for execution
        renderer.device.queue.submit([encoder.finish()]);
    }
}
