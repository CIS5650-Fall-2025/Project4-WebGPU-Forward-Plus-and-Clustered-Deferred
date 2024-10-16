import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution
    
    // sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    // sceneUniformsBindGroup: GPUBindGroup;

    // gBufferTextures: {
    //     albeto: GPUTexture;
    //     normal: GPUTexture;
    //     depth: GPUTexture;
    // };

    // gBufferTextureViews: {
    //     albetoView: GPUTextureView;
    //     normalView: GPUTextureView;
    //     depthView: GPUTextureView;
    // };

    // gBufferBindGroupLayout: GPUBindGroupLayout;
    // gBufferBindGroup: GPUBindGroup;

    // forwardPassPipeline: GPURenderPipeline;
    // deferredPassPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass

        // this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
        //     label: "scene uniforms bind group layout",
        //     entries: [
        //         { // camera uniforms
        //             binding: 0,
        //             visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
        //             buffer: { type: "uniform" }
        //         },
        //         { // lightSet
        //             binding: 1,
        //             visibility: GPUShaderStage.FRAGMENT,
        //             buffer: { type: "read-only-storage" }
        //         },
        //         { // clusterSet
        //             binding: 2,
        //             visibility: GPUShaderStage.FRAGMENT,
        //             buffer: { type: "read-only-storage" }
        //         }
        //     ]
        // });

        // this.sceneUniformsBindGroup = renderer.device.createBindGroup({
        //     label: "scene uniforms bind group",
        //     layout: this.sceneUniformsBindGroupLayout,
        //     entries: [
        //         {
        //             binding: 0,
        //             resource: { buffer: this.camera.uniformsBuffer }
        //         },
        //         {
        //             binding: 1,
        //             resource: { buffer: this.lights.lightSetStorageBuffer }
        //         },
        //         {
        //             binding: 2,
        //             resource: { buffer: this.lights.clusterSetBuffer }
        //         }
        //     ]
        // });
        
        // this.gBufferTextures = {
        //     albeto: renderer.device.createTexture({
        //         size: [renderer.canvas.width, renderer.canvas.height],
        //         format: 'rgba8unorm',
        //         usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        //     }),
        //     normal: renderer.device.createTexture({
        //         size: [renderer.canvas.width, renderer.canvas.height],
        //         format: 'rgba16float',
        //         usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        //     }),
        //     depth: renderer.device.createTexture({
        //         size: [renderer.canvas.width, renderer.canvas.height],
        //         format: "depth24plus",
        //         usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        //     })
        // };

        // this.gBufferTextureViews = {
        //     albetoView: this.gBufferTextures.albeto.createView(),
        //     normalView: this.gBufferTextures.normal.createView(),
        //     depthView: this.gBufferTextures.depth.createView()
        // };

        // this.gBufferBindGroupLayout = renderer.device.createBindGroupLayout({
        //     label: "g buffer bind group layout",
        //     entries: [
        //         {
        //             binding: 0,
        //             visibility: GPUShaderStage.FRAGMENT,
        //             texture: {}
        //         },
        //         {
        //             binding: 1,
        //             visibility: GPUShaderStage.FRAGMENT,
        //             sampler: {}
        //         },
        //         {
        //             binding: 2,
        //             visibility: GPUShaderStage.FRAGMENT,
        //             texture: {}
        //         },
        //         {
        //             binding: 3,
        //             visibility: GPUShaderStage.FRAGMENT,
        //             sampler: {}
        //         },
        //         {
        //             binding: 4,
        //             visibility: GPUShaderStage.FRAGMENT,
        //             texture: { sampleType: 'depth' }
        //         },
        //         {
        //             binding: 5,
        //             visibility: GPUShaderStage.FRAGMENT,
        //             sampler: {}
        //         }
        //     ]
        // });

        // this.gBufferBindGroupLayout = device.createBindGroup({
        //     label: "material bind group",
        //     layout: materialBindGroupLayout,
        //     entries: [
        //         {
        //             binding: 0,
        //             resource: diffuseTexture.image.createView()
        //         },
        //         {
        //             binding: 1,
        //             resource: diffuseTexture.sampler
        //         }
        //     ]
        // });

        // this.forwardPassPipeline = renderer.device.createRenderPipeline({
        //     layout: renderer.device.createPipelineLayout({
        //         label: "forward plus pipeline layout",
        //         bindGroupLayouts: [
        //             this.sceneUniformsBindGroupLayout,
        //             renderer.modelBindGroupLayout,
        //             renderer.materialBindGroupLayout
        //         ]
        //     }),
        //     depthStencil: {
        //         depthWriteEnabled: true,
        //         depthCompare: "less",
        //         format: "depth24plus"
        //     },
        //     vertex: {
        //         module: renderer.device.createShaderModule({
        //             label: "naive vert shader",
        //             code: shaders.naiveVertSrc
        //         }),
        //         buffers: [ renderer.vertexBufferLayout ]
        //     },
        //     fragment: {
        //         module: renderer.device.createShaderModule({
        //             label: "forward plus frag shader",
        //             code: shaders.forwardPlusFragSrc,
        //         }),
        //         targets: [
        //             {
        //                 format: renderer.canvasFormat,
        //             }
        //         ]
        //     }
        // });

        // this.deferredPassPipeline = renderer.device.createRenderPipeline({
        //     layout: renderer.device.createPipelineLayout({
        //         label: "forward plus pipeline layout",
        //         bindGroupLayouts: [
        //             this.sceneUniformsBindGroupLayout,
        //             renderer.modelBindGroupLayout,
        //             renderer.materialBindGroupLayout
        //         ]
        //     }),
        //     depthStencil: {
        //         depthWriteEnabled: true,
        //         depthCompare: "less",
        //         format: "depth24plus"
        //     },
        //     vertex: {
        //         module: renderer.device.createShaderModule({
        //             label: "naive vert shader",
        //             code: shaders.naiveVertSrc
        //         }),
        //         buffers: [ renderer.vertexBufferLayout ]
        //     },
        //     fragment: {
        //         module: renderer.device.createShaderModule({
        //             label: "forward plus frag shader",
        //             code: shaders.forwardPlusFragSrc,
        //         }),
        //         targets: [
        //             {
        //                 format: renderer.canvasFormat,
        //             }
        //         ]
        //     }
        // });
    }

    override draw() {
        // TODO-3: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // - run the G-buffer pass, outputting position, albedo, and normals
        // - run the fullscreen pass, which reads from the G-buffer and performs lighting calculations
    }
}
