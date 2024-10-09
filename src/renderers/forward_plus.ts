import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ForwardPlusRenderer extends renderer.Renderer {
    // TODO-2: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution
    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    clusterComputeBindGroupLayout: GPUBindGroupLayout;
    clusterComputeBindGroup: GPUBindGroup;
    clusterComputePipeline: GPUComputePipeline;
    clusterBuffer: GPUBuffer;

    forwardPlusPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);
        // TODO-2: initialize layouts, pipelines, textures, etc. needed for Forward+ here

        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene uniforms bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: { type: "uniform" }
                }
            ]
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                }
            ]
        });

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthTextureView = this.depthTexture.createView();

        this.clusterComputeBindGroupLayout = renderer.device.createBindGroupLayout({
            entries: [
                
            ]
        });

        this.clusterComputeBindGroup = renderer.device.createBindGroup({
            layout: this.clusterComputeBindGroupLayout,
            entries: [
                
            ]
        });

        this.clusterComputePipeline = renderer.device.createComputePipeline({
            layout: renderer.device.createPipelineLayout({
                bindGroupLayouts: [this.clusterComputeBindGroupLayout]
            }),
            compute: {
                module: renderer.device.createShaderModule({
                    code: shaders.clusteringComputeSrc // 你需要在shaders.ts中定义这个
                }),
                entryPoint: "main"
            }
        });

        const numClustersX = 16; 
        const numClustersY = 9;
        const numClustersZ = 24;
        const maxLightsPerCluster = 100;
        const clusterBufferSize = numClustersX * numClustersY * numClustersZ * (4 + maxLightsPerCluster * 4);

        this.clusterBuffer = renderer.device.createBuffer({
            size: clusterBufferSize,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });

        this.forwardPlusPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
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
        const encoder = renderer.device.createCommandEncoder();
    
        // - run the clustering compute shader
        const computePass = encoder.beginComputePass();
        computePass.setPipeline(this.clusterComputePipeline);
        computePass.setBindGroup(0, this.clusterComputeBindGroup);
        computePass.dispatchWorkgroups(
            Math.ceil(16 / 8), // numClustersX / workgroupSizeX
            Math.ceil(9 / 8),  // numClustersY / workgroupSizeY
            24                 // numClustersZ
        );
        computePass.end();
    
        // - run the main rendering pass, using the computed clusters for efficient lighting
        const renderPass = encoder.beginRenderPass({
            colorAttachments: [{
                view: renderer.context.getCurrentTexture().createView(),
                loadOp: "clear",
                storeOp: "store",
                clearValue: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 }//Alpha zero?
            }],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthLoadOp: "clear",
                depthStoreOp: "store",
                depthClearValue: 1.0
            }
        });
    
        renderPass.setPipeline(this.forwardPlusPipeline);
        renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);
    
        this.scene.iterate(node => {
            renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            renderPass.setVertexBuffer(0, primitive.vertexBuffer);
            renderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            renderPass.drawIndexed(primitive.numIndices);
        });
    
        renderPass.end();
    
        renderer.device.queue.submit([encoder.finish()]);
    }
}
