import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Primitive } from '../stage/scene';
import { Stage } from '../stage/stage';

export class ForwardPlusRenderer extends renderer.Renderer {
    // TODO-2: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    clusterBindGroupLayout: GPUBindGroupLayout;
    clusterBindGroup: GPUBindGroup;

    pipeline: GPURenderPipeline;
    clusterPipeline: GPUComputePipeline;
    clusterBuffer: GPUBuffer;
    

    constructor(stage: Stage) {
        super(stage);

        // TODO-2: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene uniforms bind group layout",
            entries: [
                {
                    // camera uniforms at binding 0
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: { type: "uniform"}
                },
                {  // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                }
            ]
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer}
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                }
            ]
        });

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthTextureView = this.depthTexture.createView();

        // Cluster bind group layout (for light clustering data)
        this.clusterBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "cluster bind group layout",
            entries: [
                {
                    binding: 0, // Cluster data buffer
                    visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
                    buffer: { type: "read-only-storage" }
                }
            ]
        });
        this.clusterBindGroup = renderer.device.createBindGroup({
            label: "cluster bind group",
            layout: this.clusterBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.clusterBuffer }
                }
            ]
        });

        // Create the buffer to store clusters
        this.clusterBuffer = renderer.device.createBuffer({
            size: this.calculateClusterBufferSize(),
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        });

        
        // Forward+ pipeline
        this.pipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "forward+ pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout,
                    this.clusterBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "forward+ vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [renderer.vertexBufferLayout]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "forward+ frag shader",
                    code: shaders.forwardPlusFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            }
        });
        // Cluster compute pipeline
        this.clusterPipeline = renderer.device.createComputePipeline({
            layout: renderer.device.createPipelineLayout({
                label: "cluster compute pipeline layout",
                bindGroupLayouts: [this.sceneUniformsBindGroupLayout, this.clusterBindGroupLayout]
            }),
            compute: {
                module: renderer.device.createShaderModule({
                    label: "cluster compute shader",
                    code: shaders.clusteringComputeSrc
                })
            }
        });
    }
        // Function to calculate the buffer size needed for clusters
        calculateClusterBufferSize(): number {
            const numClusters = this.calculateNumClusters();
            const clusterSize = 32;
            return numClusters * clusterSize;
        }
    
        calculateNumClusters(): number {
            const clusterX = 10;
            const clusterY = 10;
            const clusterZ = 10;
            return clusterX * clusterY * clusterZ;
        }

    override draw() {
        // TODO-2: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // - run the main rendering pass, using the computed clusters for efficient lighting
        const encoder = renderer.device.createCommandEncoder();
        
        // step 1 run the clustering compute shader
        const computePass = encoder.beginComputePass();
        computePass.setPipeline(this.clusterPipeline);
        computePass.setBindGroup(0, this.sceneUniformsBindGroup);
        computePass.setBindGroup(1, this.clusterBindGroup);
        computePass.dispatchWorkgroups(this.calculateNumClusters());
        computePass.end();

        // step 2 run the main rendering pass
        const canvasTextureView = renderer.context.getCurrentTexture().createView();
        const renderPass = encoder.beginRenderPass({
            label: "forward+ render pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
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
        renderPass.setPipeline(this.pipeline);
        renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);
        renderPass.setBindGroup(shaders.constants.bindGroup_cluster, this.clusterBindGroup);
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
