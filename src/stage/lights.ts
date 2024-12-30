import { vec3 } from "wgpu-matrix";
import { device } from "../renderer";

import * as shaders from '../shaders/shaders';
import { Camera } from "./camera";
import { hueToRgb } from "../math_util";

export class Lights {
    // Define default initial and max number of lights in the scene, and light properties
    numLights = 500;
    static readonly maxNumLights = 5000;
    static readonly numFloatsPerLight = 8; // vec3f is aligned at 16 byte boundaries
    
    lightIntensity = 0.1;
    static readonly maxLightIntensity = 1;

    // Define light storage
    lightsArray = new Float32Array(Lights.maxNumLights * Lights.numFloatsPerLight);
    lightSetStorageBuffer: GPUBuffer;

    // Define time buffer
    timeUniformBuffer: GPUBuffer;

    // Define binding and pipeline for light movement
    moveLightsComputeBindGroupLayout: GPUBindGroupLayout;
    moveLightsComputeBindGroup: GPUBindGroup;
    moveLightsComputePipeline: GPUComputePipeline;

    //==============================================================================================
    // DONE-2: add layouts, pipelines, textures, etc. needed for light clustering here

    // Define cluster grid dimensions
    clusterGridWidth = 20;
    clusterGridHeight = 30;
    clusterGridDepth = 50;

    // Define min and max values for the cluster dimensions, for GUI purposes
    static readonly minClusterGridWidth = 0;
    static readonly minClusterGridHeight = 0;
    static readonly minClusterGridDepth = 0;

    static readonly maxClusterGridWidth = 300;
    static readonly maxClusterGridHeight = 300;
    static readonly maxClusterGridDepth = 300;

    lightsPerCluster = 528;
    
    // Define buffers for clustering grid properties and indices
    clusterGridPropBuffer: GPUBuffer;
    clusterIndexBuffer: GPUBuffer;
    
    // Define cluster bind group, layout, and pipeline
    clusterBindGroupLayout: GPUBindGroupLayout;
    clusterBindGroup: GPUBindGroup;

    clusterPipelineLayout: GPUPipelineLayout;
    clusterPipelineShaderModule: GPUShaderModule;
    clusterComputePipeline: GPURenderPipeline;
    
    constructor(camera: Camera) {
        this.lightSetStorageBuffer = device.createBuffer({
            label: "lights",
            size: 16 + this.lightsArray.byteLength, // 16 for numLights + padding
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });
        this.populateLightsBuffer();
        this.updateLightSetUniformNumLights();

        this.timeUniformBuffer = device.createBuffer({
            label: "time uniform",
            size: 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });
        
        // Define the cluster grid property buffer
        this.clusterGridPropBuffer = device.createBuffer({
            label: "clusterGridPropBuffer",
            size: 4 * 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });
        
        // Define the cluster index buffer
        this.clusterIndexBuffer = device.createBuffer({
            label: "clusterIndexBuffer",
            size: 4 * (
                this.clusterGridWidth
                * this.clusterGridHeight
                * this.clusterGridDepth
                * this.lightsPerCluster
            ),
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });
        
        this.moveLightsComputeBindGroupLayout = device.createBindGroupLayout({
            label: "move lights compute bind group layout",
            entries: [
                { // lightSet
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" }
                },
                { // time
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" }
                }
            ]
        });

        this.moveLightsComputeBindGroup = device.createBindGroup({
            label: "move lights compute bind group",
            layout: this.moveLightsComputeBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.lightSetStorageBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: this.timeUniformBuffer }
                }
            ]
        });

        this.moveLightsComputePipeline = device.createComputePipeline({
            label: "move lights compute pipeline",
            layout: device.createPipelineLayout({
                label: "move lights compute pipeline layout",
                bindGroupLayouts: [ this.moveLightsComputeBindGroupLayout ]
            }),
            compute: {
                module: device.createShaderModule({
                    label: "move lights compute shader",
                    code: shaders.moveLightsComputeSrc
                }),
                entryPoint: "main"
            }
        });

        //===========================================================================================
        // DONE-2: initialize layouts, pipelines, textures, etc. needed for light clustering here
        this.clusterBindGroupLayout = device.createBindGroupLayout({
            label: "clusterBindGroupLayout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
                    buffer: {type: "uniform"},
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
                    buffer: {type: "uniform"},
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
                    buffer: {type: "read-only-storage"},
                },
                {
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
                    buffer: {type: "storage"},
                },
            ],
        });
        
        this.clusterBindGroup = device.createBindGroup({
            label: "clusterBindGroup",
            layout: this.clusterBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: {buffer: this.clusterGridPropBuffer},
                },
                {
                    binding: 1,
                    resource: {buffer: camera.uniformsBuffer},
                },
                {
                    binding: 2,
                    resource: {buffer: this.lightSetStorageBuffer},
                },
                {
                    binding: 3,
                    resource: {buffer: this.clusterIndexBuffer},
                },
            ],
        });
        
        this.clusterPipelineLayout = device.createPipelineLayout({
            label: "clusterPipelineLayout",
            bindGroupLayouts: [
                this.clusterBindGroupLayout,
            ],
        });
        
        this.clusterPipelineShaderModule = device.createShaderModule({
            label: "clusterPipelineShaderModule",
            code: shaders.clusteringComputeSrc,
        });
        
        // Define the clustering compute pipeline using the previously defined components
        this.clusterComputePipeline = device.createComputePipeline({
            label: "clusterComputePipeline",
            layout: this.clusterPipelineLayout,
            compute: {
                module: this.clusterPipelineShaderModule,
                entryPoint: "main",
            },
        });
        
        const gridProps = new Uint32Array([
            this.clusterGridWidth,
            this.clusterGridHeight,
            this.clusterGridDepth,
            this.lightsPerCluster,
        ]);
        // Write to the grid property buffer
        device.queue.writeBuffer(this.clusterGridPropBuffer, 0, gridProps);
    }
    //============================================================================================
    private populateLightsBuffer() {
        for (let lightIdx = 0; lightIdx < Lights.maxNumLights; ++lightIdx) {
            // light pos is set by compute shader so no need to set it here
            const lightColor = vec3.scale(hueToRgb(Math.random()), this.lightIntensity);
            this.lightsArray.set(lightColor, (lightIdx * Lights.numFloatsPerLight) + 4);
        }

        device.queue.writeBuffer(this.lightSetStorageBuffer, 16, this.lightsArray);
    }

    //=======================================================================================================
    // Callback functions for updating values based on GUI controls!
    updateLightSetUniformNumLights() {
        device.queue.writeBuffer(this.lightSetStorageBuffer, 0, new Uint32Array([this.numLights]));
    }

    updateClusterSetUniformGridWidth() {
        device.queue.writeBuffer(this.clusterGridPropBuffer, 0, new Uint32Array([this.clusterGridWidth]));
    }

    updateClusterSetUniformGridHeight() {
        device.queue.writeBuffer(this.clusterGridPropBuffer, 4, new Uint32Array([this.clusterGridHeight]));
    }

    updateClusterSetUniformGridDepth() {
        device.queue.writeBuffer(this.clusterGridPropBuffer, 8, new Uint32Array([this.clusterGridDepth]));
    }

    updateLightIntensity() {
        // Calling this to refresh the light intensity when the value is updated via GUI
        this.populateLightsBuffer();
    }
    //=======================================================================================================

    doLightClustering(encoder: GPUCommandEncoder) {
        // DONE-2: run the light clustering compute pass(es) here
        // implementing clustering here allows for reusing the code in both Forward+ and Clustered Deferred
        const clusterComputePass = encoder.beginComputePass();
        clusterComputePass.setPipeline(this.clusterComputePipeline);
        clusterComputePass.setBindGroup(0, this.clusterBindGroup);
        
        // Calculate workload
        const workload = Math.ceil(
            this.clusterGridWidth * this.clusterGridHeight * this.clusterGridDepth
            / shaders.constants.moveLightsWorkgroupSize
        );
        // Dispatch to workgroups
        clusterComputePass.dispatchWorkgroups(workload);
        // End the compute pass
        clusterComputePass.end();
    }

    // CHECKITOUT: this is where the light movement compute shader is dispatched from the host
    onFrame(time: number) {
        device.queue.writeBuffer(this.timeUniformBuffer, 0, new Float32Array([time]));

        // not using same encoder as render pass so this doesn't interfere with measuring actual rendering performance
        const encoder = device.createCommandEncoder();

        const computePass = encoder.beginComputePass();
        computePass.setPipeline(this.moveLightsComputePipeline);

        computePass.setBindGroup(0, this.moveLightsComputeBindGroup);

        const workgroupCount = Math.ceil(this.numLights / shaders.constants.moveLightsWorkgroupSize);
        computePass.dispatchWorkgroups(workgroupCount);

        computePass.end();

        device.queue.submit([encoder.finish()]);
    }
}
