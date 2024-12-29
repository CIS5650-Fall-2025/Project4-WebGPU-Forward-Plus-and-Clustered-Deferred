import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ForwardPlusRenderer extends renderer.Renderer {
    // DONE-2: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    // Setup the bind group and layout for the scene
    sceneBindGroupLayout: GPUBindGroupLayout;
    sceneBindGroup: GPUBindGroup;
    
    // Define depth texture components
    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;
    
    // Define render pipeline components
    forwardPlusRenderPipelineLayout: GPUPipelineLayout;
    
    // Define vertex and fragment shader modules
    forwardPlusVertexShaderModule: GPUShaderModule;
    forwardPlusFragmentShaderModule: GPUShaderModule;
    
    // Define the render pipeline
    forwardPlusRenderPipeline: GPURenderPipeline;
    
    constructor(stage: Stage) {
        super(stage);
        
        // Define scene components
        this.sceneBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "sceneBindGroupLayout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {type: "uniform"},
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: {type: "read-only-storage"},
                },
            ],
        });
        
        this.sceneBindGroup = renderer.device.createBindGroup({
            label: "sceneBindGroup",
            layout: this.sceneBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: {buffer: this.camera.uniformsBuffer},
                },
                {
                    binding: 1,
                    resource: {buffer: this.lights.lightSetStorageBuffer},
                },
            ],
        });
        
        //=============================================================================
        // Define depth texture components
        this.depthTexture = renderer.device.createTexture({
            label: "depthTexture",
            size: [
                renderer.canvas.width,
                renderer.canvas.height,
            ],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT,
        });
        
        this.depthTextureView = this.depthTexture.createView();
        
        //=============================================================================
        // Create the render pipeline layout
        this.forwardPlusRenderPipelineLayout = renderer.device.createPipelineLayout({
            label: "forwardPlusRenderPipelineLayout",
            bindGroupLayouts: [
                this.sceneBindGroupLayout,
                renderer.modelBindGroupLayout,
                renderer.materialBindGroupLayout,
                this.lights.clusterBindGroupLayout,
            ],
        });

        // Define the vertex and fragment shader modules
        this.forwardPlusVertexShaderModule = renderer.device.createShaderModule({
            label: "forwardPlusVertexShaderModule",
            code: shaders.naiveVertSrc,
        });
        this.forwardPlusFragmentShaderModule = renderer.device.createShaderModule({
            label: "forwardPlusFragmentShaderModule",
            code: shaders.forwardPlusFragSrc,
        });

        // Define the full forward plus render pipeline using the above components
        this.forwardPlusRenderPipeline = renderer.device.createRenderPipeline({
            label: "forwardPlusRenderPipeline",
            layout: this.forwardPlusRenderPipelineLayout,
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus",
            },
            vertex: {
                module: this.forwardPlusVertexShaderModule,
                buffers: [renderer.vertexBufferLayout],
            },
            fragment: {
                module: this.forwardPlusFragmentShaderModule,
                targets: [{format: renderer.canvasFormat},
                ],
            },
        });
    }

    override draw() {
        // DONE-2: run the Forward+ rendering pass:
        const encoder = renderer.device.createCommandEncoder();

        // Perform light clustering
        this.lights.doLightClustering(encoder);
        const attachment_view = renderer.context.getCurrentTexture().createView();

        // Set up the forward plus render pass, bind groups, and pipeline
        const forwardPlusRenderPass = encoder.beginRenderPass({
            label: "forwardPlusRenderPass",
            colorAttachments: [
                {
                    view: attachment_view,
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
        
        forwardPlusRenderPass.setPipeline(this.forwardPlusRenderPipeline);

        forwardPlusRenderPass.setBindGroup(
            shaders.constants.bindGroup_scene,
            this.sceneBindGroup
        );
        forwardPlusRenderPass.setBindGroup(
            shaders.constants.bindGroup_clustering,
            this.lights.clusterBindGroup
        );
        
        this.scene.iterate(
            node => {
                forwardPlusRenderPass.setBindGroup(
                    shaders.constants.bindGroup_model,
                    node.modelBindGroup
                );
            }, 
            material => {
                forwardPlusRenderPass.setBindGroup(
                    shaders.constants.bindGroup_material,
                    material.materialBindGroup
                );
            }, 
            primitive => {
                forwardPlusRenderPass.setVertexBuffer(0, primitive.vertexBuffer);
                forwardPlusRenderPass.setIndexBuffer(primitive.indexBuffer, "uint32");
                forwardPlusRenderPass.drawIndexed(primitive.numIndices);
            }
        );
        
        // Complete the render pass
        forwardPlusRenderPass.end();
        
        // Submit encoder finish command
        renderer.device.queue.submit([encoder.finish()]);
    }
}
