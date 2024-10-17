import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ForwardPlusRenderer extends renderer.Renderer {
    // TODO-2: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution
    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    // Vars needed for the compute pass
    // clustersArray = new Float32Array();
    // clusterSetStorageBuffer: GPUBuffer;

    // clusterComputeBindGroupLayout: GPUBindGroupLayout;
    // clusterComputeBindGroup: GPUBindGroup;
    // clusterComputePipeline: GPUComputePipeline;
    
    // Vars needed for the main rendering pass

    constructor(stage: Stage) {
        super(stage);
        // this.clusterSetStorageBuffer = renderer.device.createBuffer({
        //     label: "cluster set in forward+",
        //     size: 16 + this.clustersArray.byteLength,
        //     usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        // });

        // TODO-2: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene uniforms bind group layout for forward+",
            entries: [
                // Add an entry for camera uniforms at binding 0, visible to the vertex and compute shader, and of type "uniform"
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" }
                },
                { // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
                    buffer: { type: "read-only-storage" }
                }
            ]
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "scene uniforms bind group for forward+",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                // Add an entry for camera uniforms at binding 0
                // you can access the camera using `this.camera`
                // if you run into TypeScript errors, you're probably trying to upload the host buffer instead
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                }, 
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                }
            ]
        });

        /** Compute Shader **/
        // this.clusterComputePipeline = renderer.device.createComputePipeline({
        //     layout: renderer.device.createPipelineLayout({
        //         label: "compute pipeline layout for forward+",
        //         bindGroupLayouts: [
        //             this.sceneUniformsBindGroupLayout
        //         ]
        //     }),
        //     compute: {
        //         module: renderer.device.createShaderModule({
        //             label: "light clustering compute shader for forward+",
        //             code: shaders.clusteringComputeSrc // Your WGSL compute shader source code
        //         }),
        //         entryPoint: "main" // The compute shader entry point
        //     }
        // });
        /****************************************************************/

        /****************************************************************/
    }

    override draw() {
        // TODO-2: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // const commandEncoder = renderer.device.createCommandEncoder();
        // const computePass = commandEncoder.beginComputePass({
        //     label: "forward+ compute pass"
        // });

        // computePass.setPipeline(this.clusterComputePipeline);
        // computePass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);
        
        // computePass.end();
        // renderer.device.queue.submit([commandEncoder.finish()]);

        // - run the main rendering pass, using the computed clusters for efficient lighting
    }
}
