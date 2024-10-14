import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ForwardPlusRenderer extends renderer.Renderer {
    // TODO-2: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution
    
    // add layouts
    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;
    //sceneComputeBindGroupLayout: GPUBindGroupLayout;
    // sceneComputeBindGroup: GPUBindGroup;

    // add textures
    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    // add pipelines
    pipeline: GPURenderPipeline;
    computePipeline: GPUComputePipeline;  

    // add buffers
    clusterSetStorageBuffer: GPUBuffer;

    constructor(stage: Stage) {
        super(stage);

        // Set as 32x32x32 clusters
        const clusterSize = (16 + 16 + 4 + 100 * 4); 
        const numClusters =512;
        const alignedClusterSize = Math.ceil(clusterSize / 256) * 256;
        const bufferSize = alignedClusterSize * numClusters;
        this.clusterSetStorageBuffer = renderer.device.createBuffer({
            label: "cluster set buffer",
            size: bufferSize,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });
        const clusterSetData = new Float32Array(clusterSize * numClusters / 4);
        renderer.device.queue.writeBuffer(
            this.clusterSetStorageBuffer,
            0, 
            clusterSetData
        );

        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "forward: scene uniforms bind group layout",
            entries: [
                // TODO-1.2: add an entry for camera uniforms at binding 0, visible to only the vertex shader, and of type "uniform"
                {
                    // camera uniforms
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX| GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" }
                },
                { // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT| GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" }
                    // buffer: { type: "storage" }
                },
                {
                    // clusterSet
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT| GPUShaderStage.COMPUTE,
                    // buffer: { type: "read-only-storage" }
                    buffer: { type: "storage" }
                }
            ]
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "forward: scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                // TODO-1.2: add an entry for camera uniforms at binding 0
                // you can access the camera using this.camera
                // if you run into TypeScript errors, you're probably trying to upload the host buffer instead
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
                    resource: { buffer: this.clusterSetStorageBuffer }
                }
            ]
        });



        // this.sceneComputeBindGroupLayout = renderer.device.createBindGroupLayout({
        //     label: "forward: scene compute bind group layout",
        //     entries: [
        //         {
        //             binding: 0,
        //             visibility: GPUShaderStage.COMPUTE,
        //             buffer: { type: "uniform" }
        //         },
        //         { 
        //             binding: 1,
        //             visibility: GPUShaderStage.FRAGMENT,
        //             buffer: { type: "read-only-storage" }
        //         }
        //         // {
        //         //     binding: 0,
        //         //     visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
        //         //     buffer: { type: "storage" }  //store the lightSet
        //         // }
        //     ]  
        // });

        // this.sceneComputeBindGroup = renderer.device.createBindGroup({
        //     label: "forward: scene compute bind group",
        //     layout: this.sceneComputeBindGroupLayout,
        //     entries: [
        //         {
        //             binding: 0,
        //             resource: { buffer: this.camera.uniformsBuffer }
        //         },
        //         {
        //             binding: 1,
        //             resource: { buffer: this.lights.lightSetStorageBuffer }
        //         }
        //     ]
        // });

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthTextureView = this.depthTexture.createView();

        this.pipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "forward: naive pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
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
                    label: "forward: naive vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "forward: naive frag shader",
                    code: shaders.forwardPlusFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            }
        });
        
        this.computePipeline = renderer.device.createComputePipeline({
            layout: renderer.device.createPipelineLayout({
                label: "Forward+ compute pipeline layout",
                bindGroupLayouts: [
                    // for camera uniforms
                    this.sceneUniformsBindGroupLayout
                    // for lightSet and clusterSet
                    // ,this.sceneComputeBindGroupLayout
                ]
            }),
            compute: {
                module: renderer.device.createShaderModule({
                    label: "Forward+ compute shader",
                    code: shaders.clusteringComputeSrc
                }),
                entryPoint: "main"
            }
        });  
    }

    
    override draw() {
        // TODO-2: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // - run the main rendering pass, using the computed clusters for efficient lighting
        
        const encoder = renderer.device.createCommandEncoder();
        
        // run the compute pass
        const computePass = encoder.beginComputePass();
        computePass.setPipeline(this.computePipeline);
        computePass.setBindGroup(0, this.sceneUniformsBindGroup);
       // computePass.setBindGroup(1, this.sceneComputeBindGroup);
        computePass.dispatchWorkgroups(
            Math.ceil(renderer.canvas.width / 32),
            Math.ceil(renderer.canvas.height / 32),
            32 
        );
        computePass.end();

        const canvasTextureView = renderer.context.getCurrentTexture().createView();

        const renderPass = encoder.beginRenderPass({
            label: "naive render pass",
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

        // TODO-1.2: bind `this.sceneUniformsBindGroup` to index `shaders.constants.bindGroup_scene`
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
