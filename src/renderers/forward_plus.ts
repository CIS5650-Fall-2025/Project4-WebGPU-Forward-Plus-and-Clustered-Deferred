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

    // add buffers for clusterSet
    static readonly numClusters = 512;
    static readonly numFloatsPerCluster = 112;
    clusterArray = new Float32Array(ForwardPlusRenderer.numClusters * ForwardPlusRenderer.numFloatsPerCluster);
    clusterSetStorageBuffer: GPUBuffer;

    private populateClusterBuffer() {
        renderer.device.queue.writeBuffer(this.clusterSetStorageBuffer, 0, this.clusterArray);
    }

    constructor(stage: Stage) {
        super(stage);

        // const clusterSize = (16 + 16 + 4 + 100 * 4); 
        // Set as tile size 32x32 and exponential depth range
        // const numClusters = renderer.canvas.width/64 * renderer.canvas.height/64 * 16;
        // console.log("The canvas width is: ", renderer.canvas.width);
        // console.log("The canvas height is: ", renderer.canvas.height);
        // console.log("The total number of cluster is: ", numClusters); 
        // const numClusters = 512;
        // const alignedClusterSize = Math.ceil(clusterSize / 256) * 256;
        // const bufferSize = alignedClusterSize * numClusters;
        // this.clusterSetStorageBuffer = renderer.device.createBuffer({
        //     label: "cluster set buffer",
        //     size: bufferSize,
        //     usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        // });
                // const clusterSetData = new Float32Array(clusterSize * numClusters / 4);        
        // renderer.device.queue.writeBuffer(this.clusterSetStorageBuffer,0, clusterSetData);
        
        this.clusterSetStorageBuffer = renderer.device.createBuffer({
            label: "cluster set buffer in light class",
            size: this.clusterArray.byteLength,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });
        this.populateClusterBuffer();

        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "forward: scene uniforms bind group layout",
            entries: [
                {// camera uniforms
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX| GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" }
                },
                { // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT| GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" }
                },
                {// clusterSet
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT| GPUShaderStage.COMPUTE,
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
            //createShaderModule create the compute shader.
            //Pass the compute shader string to the code property
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
        
        const computeEncoder = renderer.device.createCommandEncoder();
        const renderEncoder = renderer.device.createCommandEncoder();
        
        // run the compute pass
        const computePass = computeEncoder.beginComputePass({label: "Forward+ compute pass begin"}); 
        computePass.setPipeline(this.computePipeline);
        // group 0 only
        computePass.setBindGroup(0, this.sceneUniformsBindGroup);
       // computePass.setBindGroup(1, this.sceneComputeBindGroup);
        computePass.dispatchWorkgroups(
            Math.ceil(renderer.canvas.width / 32),
            Math.ceil(renderer.canvas.height / 32),
            32 
        );
        computePass.end();
        renderer.device.queue.submit([computeEncoder.finish()]);

        const canvasTextureView = renderer.context.getCurrentTexture().createView();

        const renderPass = renderEncoder.beginRenderPass({
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

        // group 0
        renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);

        this.scene.iterate(node => {
            // group 1
            renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            // group 2
            renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            renderPass.setVertexBuffer(0, primitive.vertexBuffer);
            renderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            renderPass.drawIndexed(primitive.numIndices);
        });

        renderPass.end();

        renderer.device.queue.submit([renderEncoder.finish()]);
    }
}
