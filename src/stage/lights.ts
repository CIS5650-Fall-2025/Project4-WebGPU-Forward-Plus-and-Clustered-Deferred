import { vec3 } from "wgpu-matrix";
import { device } from "../renderer";

import * as shaders from '../shaders/shaders';
import { Camera } from "./camera";

// h in [0, 1]
function hueToRgb(h: number) {
    let f = (n: number, k = (n + h * 6) % 6) => 1 - Math.max(Math.min(k, 4 - k, 1), 0);
    return vec3.lerp(vec3.create(1, 1, 1), vec3.create(f(5), f(3), f(1)), 0.8);
}

export class Lights {
    private camera: Camera;

    numLights = 500;
    static readonly maxNumLights = 5000;
    static readonly numFloatsPerLight = 8; // vec3f is aligned at 16 byte boundaries
    static readonly lightIntensity = 0.1;

    lightsArray = new Float32Array(Lights.maxNumLights * Lights.numFloatsPerLight);
    lightSetStorageBuffer: GPUBuffer;
    timeUniformBuffer: GPUBuffer;

    // === MOVE LIGHTS COMPUTE ===
    moveLightsComputeBindGroupLayout: GPUBindGroupLayout;
    moveLightsComputeBindGroup: GPUBindGroup;
    moveLightsComputePipeline: GPUComputePipeline;

    
    // === CLUSTER SETUP ===
    static readonly cluster_grid_width = 10;
    static readonly cluster_grid_height = 20;
    static readonly cluster_grid_depth = 30;
    static readonly light_per_cluster_count = 512;

    clusterGridBuffer: GPUBuffer;
    clusterIndexBuffer: GPUBuffer;
    clusterBindGroupLayout: GPUBindGroupLayout;
    clusterBindGroup: GPUBindGroup;

    // === CLUSTERING COMPUTE PIPELINE ===
    clusterComputePipelineLayout: GPUPipelineLayout;
    clusterComputeShaderModule: GPUShaderModule;
    clusterComputePipeline: GPUComputePipeline;
    
    
    constructor(camera: Camera) {
        this.camera = camera;

        this.initLightBuffers();
        this.initClusterBuffers();
        this.initMoveLightsPipeline();
        this.initClusterPipeline();
    }


    private initLightBuffers() {
        this.lightSetStorageBuffer = device.createBuffer({
            label: "Lights",
            size: 16 + this.lightsArray.byteLength,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });
        this.populateLightsBuffer();
        this.updateLightSetUniformNumLights();

        this.timeUniformBuffer = device.createBuffer({
            label: "Time Uniform",
            size: 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });
    }


     private initClusterBuffers() {
        this.clusterGridBuffer = device.createBuffer({
            label: "clusterGridBuffer",
            size: 4 * 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });

        this.clusterIndexBuffer = device.createBuffer({
            label: "clusterIndexBuffer",
            size: 4 * Lights.cluster_grid_width * Lights.cluster_grid_height * Lights.cluster_grid_depth * Lights.light_per_cluster_count,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });

        device.queue.writeBuffer(
            this.clusterGridBuffer, 0,
            new Uint32Array([
                Lights.cluster_grid_width,
                Lights.cluster_grid_height,
                Lights.cluster_grid_depth,
                Lights.light_per_cluster_count,
            ])
        );
    }



     private initMoveLightsPipeline() {
        this.moveLightsComputeBindGroupLayout = device.createBindGroupLayout({
            label: "move lights bind group layout",
            entries: [
                { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" } },
                { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "uniform" } }
            ]
        });

        this.moveLightsComputeBindGroup = device.createBindGroup({
            label: "move lights bind group",
            layout: this.moveLightsComputeBindGroupLayout,
            entries: [
                { binding: 0, resource: { buffer: this.lightSetStorageBuffer } },
                { binding: 1, resource: { buffer: this.timeUniformBuffer } }
            ]
        });

        this.moveLightsComputePipeline = device.createComputePipeline({
            label: "move lights pipeline",
            layout: device.createPipelineLayout({
                label: "move lights pipeline layout",
                bindGroupLayouts: [this.moveLightsComputeBindGroupLayout]
            }),
            compute: {
                module: device.createShaderModule({ label: "move lights shader", code: shaders.moveLightsComputeSrc }),
                entryPoint: "main"
            }
        });
    }



    private initClusterPipeline() {
        this.clusterBindGroupLayout = device.createBindGroupLayout({
            label: "Cluster Bind Group Layout",
            entries: [
                { binding: 0, visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE, buffer: { type: "uniform" } },
                { binding: 1, visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE, buffer: { type: "uniform" } },
                { binding: 2, visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE, buffer: { type: "read-only-storage" } },
                { binding: 3, visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE, buffer: { type: "storage" } },
            ]
        });

        this.clusterBindGroup = device.createBindGroup({
            label: "Cluster Bind Group",
            layout: this.clusterBindGroupLayout,
            entries: [
                { binding: 0, resource: { buffer: this.clusterGridBuffer } },
                { binding: 1, resource: { buffer: this.camera.uniformsBuffer } },
                { binding: 2, resource: { buffer: this.lightSetStorageBuffer } },
                { binding: 3, resource: { buffer: this.clusterIndexBuffer } },
            ]
        });

        this.clusterComputePipelineLayout = device.createPipelineLayout({
            label: "Cluster Pipeline Layout",
            bindGroupLayouts: [this.clusterBindGroupLayout],
        });

        this.clusterComputeShaderModule = device.createShaderModule({
            label: "Cluster Compute Shader",
            code: shaders.clusteringComputeSrc,
        });

        this.clusterComputePipeline = device.createComputePipeline({
            label: "Cluster Compute Pipeline",
            layout: this.clusterComputePipelineLayout,
            compute: {
                module: this.clusterComputeShaderModule,
                entryPoint: "main",
            },
        });
    }


    private populateLightsBuffer() {
        for (let lightIdx = 0; lightIdx < Lights.maxNumLights; ++lightIdx) {
            // light pos is set by compute shader so no need to set it here
            const lightColor = vec3.scale(hueToRgb(Math.random()), Lights.lightIntensity);
            this.lightsArray.set(lightColor, (lightIdx * Lights.numFloatsPerLight) + 4);
        }

        device.queue.writeBuffer(this.lightSetStorageBuffer, 16, this.lightsArray);
    }


    updateLightSetUniformNumLights() {
        device.queue.writeBuffer(this.lightSetStorageBuffer, 0, new Uint32Array([this.numLights]));
    }


    doLightClustering(encoder: GPUCommandEncoder) {
        const pass = encoder.beginComputePass();
        pass.setPipeline(this.clusterComputePipeline);
        pass.setBindGroup(0, this.clusterBindGroup);

        const totalClusters = Lights.cluster_grid_width * Lights.cluster_grid_height * Lights.cluster_grid_depth;
        const workgroupCount = Math.ceil(totalClusters / shaders.constants.moveLightsWorkgroupSize);

        pass.dispatchWorkgroups(workgroupCount);
        pass.end();
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
