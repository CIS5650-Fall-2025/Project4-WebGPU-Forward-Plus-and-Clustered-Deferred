import { vec3 } from "wgpu-matrix";
import { device, canvas } from "../renderer";

import * as shaders from '../shaders/shaders';
import { Camera } from "./camera";

// h in [0, 1]
function hueToRgb(h: number) {
    let f = (n: number, k = (n + h * 6) % 6) => 1 - Math.max(Math.min(k, 4 - k, 1), 0);
    return vec3.lerp(vec3.create(1, 1, 1), vec3.create(f(5), f(3), f(1)), 0.8);
}

export class Lights {
    private camera: Camera;

    numLights = 50;
    static readonly maxNumLights = 5000;
    static readonly numFloatsPerLight = 8; // vec3f is aligned at 16 byte boundaries

    static readonly lightIntensity = 0.1;

    lightsArray = new Float32Array(Lights.maxNumLights * Lights.numFloatsPerLight);
    lightSetStorageBuffer: GPUBuffer;

    timeUniformBuffer: GPUBuffer;

    moveLightsComputeBindGroupLayout: GPUBindGroupLayout;
    moveLightsComputeBindGroup: GPUBindGroup;
    moveLightsComputePipeline: GPUComputePipeline;

    // TODO-2: add layouts, pipelines, textures, etc. needed for light clustering here
    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    lightClustersBindGroupLayout: GPUBindGroupLayout;
    lightClustersBindGroup: GPUBindGroup;
    lightClustersPipeline: GPUComputePipeline;
    
    clusterWidth: number;
    clusterHeight: number;
    clusterNum: number;

    lightsClusterArray: Uint32Array;
    lightsClusterStorageBuffer: GPUBuffer;

    constructor(camera: Camera) {
        this.camera = camera;

        this.sceneUniformsBindGroupLayout = device.createBindGroupLayout({
            label: "scene uniforms bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "uniform" }
                }
            ]
        });
        this.sceneUniformsBindGroup = device.createBindGroup({
            label: "scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                }
            ]
        });
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

        // TODO-2: initialize layouts, pipelines, textures, etc. needed for light clustering here
        this.clusterWidth = Math.ceil(canvas.width / shaders.constants.tileSize);
        this.clusterHeight = Math.ceil(canvas.height / shaders.constants.tileSize);
        this.clusterNum = this.clusterWidth * this.clusterHeight;
        this.lightsClusterArray = new Uint32Array(this.clusterNum * shaders.constants.maxLightsPerTile);

        this.lightsClusterStorageBuffer = device.createBuffer({
            label: "light cluster",
            size: 16 + this.lightsClusterArray.byteLength,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST
        });

        for (let i = 0; i < this.lightsClusterArray.length; i++) {
            this.lightsClusterArray[i] = 0xFFFFFFFF;
        }
        // write cluster raw data and dimensions
        device.queue.writeBuffer(this.lightsClusterStorageBuffer, 16, this.lightsClusterArray.buffer);
        device.queue.writeBuffer(this.lightsClusterStorageBuffer, 0, new Uint32Array([this.clusterWidth, this.clusterHeight]));

        this.lightClustersBindGroupLayout = device.createBindGroupLayout({
            label: "Light clustering compute bind group layout",
            entries: [
                { // lightSet
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "read-only-storage" }
                },
                { // clusters
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: { type: "storage" }
                }
            ]
        });

        this.lightClustersBindGroup = device.createBindGroup({
            label: "Light clustering compute bind group",
            layout: this.lightClustersBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.lightSetStorageBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: this.lightsClusterStorageBuffer }
                }
            ]
        });

        this.lightClustersPipeline = device.createComputePipeline({
            label: "Light clustering compute pipeline",
            layout: device.createPipelineLayout({
                label: "Light clustering compute pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    this.lightClustersBindGroupLayout
                 ]
            }),
            compute: {
                module: device.createShaderModule({
                    label: "Light clustering compute shader",
                    code: shaders.clusteringComputeSrc
                }),
                entryPoint: "main"
            }
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
        // TODO-2: run the light clustering compute pass(es) here
        // implementing clustering here allows for reusing the code in both Forward+ and Clustered Deferred
        encoder.setPipeline(this.lightClustersPipeline);
        encoder.setBindGroup(0, this.sceneUniformsBindGroup);
        encoder.setBindGroup(1, this.lightClustersBindGroup);
        // Dispatch enough workgroups to cover all clusters
        const workgroupCountX = Math.ceil(this.clusterWidth / shaders.constants.clusterWorkgroupSizeX);
        const workgroupCountY = Math.ceil(this.clusterHeight / shaders.constants.clusterWorkgroupSizeY);
        encoder.dispatchWorkgroups(workgroupCountX, workgroupCountY, 1);
    }

    // CHECKITOUT: this is where the light movement compute shader is dispatched from the host
    onFrame(time: number, isForwardPlus:boolean) {
        device.queue.writeBuffer(this.timeUniformBuffer, 0, new Float32Array([time]));

        // not using same encoder as render pass so this doesn't interfere with measuring actual rendering performance
        const encoder = device.createCommandEncoder();

        const computePass = encoder.beginComputePass();
        computePass.setPipeline(this.moveLightsComputePipeline);

        computePass.setBindGroup(0, this.moveLightsComputeBindGroup);

        const workgroupCount = Math.ceil(this.numLights / shaders.constants.moveLightsWorkgroupSize);
        computePass.dispatchWorkgroups(workgroupCount);

        // forward_plus light clustering
        if (isForwardPlus) {
            this.doLightClustering(computePass);
        }
        computePass.end();

        device.queue.submit([encoder.finish()]);
    }
}
