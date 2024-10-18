import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    // add layouts
    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;
    gbufferBindGroupLayout: GPUBindGroupLayout;
    gbufferBindGroup: GPUBindGroup;

    // add textures
    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    // add pipelines
    fullscreenPipeline: GPURenderPipeline;
    gbufferPipeline: GPURenderPipeline;

    //Store vertex attributes in a G-buffer
    normalTexture: GPUTexture;
    normalTextureView: GPUTextureView;

    albedoTexture: GPUTexture;
    albedoTextureView: GPUTextureView;

    positionTexture: GPUTexture;
    positionTextureView: GPUTextureView;

    // gbufferSampler: GPUTextureSampler;

    constructor(stage: Stage) {
        super(stage);

        this.depthTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthTextureView = this.depthTexture.createView();
        console.log("Depth texture view: ", this.depthTextureView);

        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass
        
        // Create texture for each G-buffer attribute
        //normal
        this.normalTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT| GPUTextureUsage.TEXTURE_BINDING
        });
        this.normalTextureView = this.normalTexture.createView({label: "normal texture view"});
        console.log("Normal texture view: ", this.normalTextureView);
        console.log("Normal texture size:", renderer.canvas.width, renderer.canvas.height);

        //albedo
        this.albedoTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba8unorm",
            usage: GPUTextureUsage.RENDER_ATTACHMENT| GPUTextureUsage.TEXTURE_BINDING
        });
        this.albedoTextureView = this.albedoTexture.createView({label: "albedo texture view"});

        //position
        this.positionTexture = renderer.device.createTexture({
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT| GPUTextureUsage.TEXTURE_BINDING
        });
        this.positionTextureView = this.positionTexture.createView({label: "position texture view"});

        // Create bind group layout
        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "Deferred: scene uniforms bind group layout",
            entries: [
                {// camera uniforms
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX| GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                { // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                {//clusterSet
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }

                }
            ]
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "Deferred: scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                },
                {//clusterSet
                    binding: 2,
                    resource: { buffer: this.lights.clusterSetStorageBuffer }
                }
            ]
        });

        // G-buffer bind group layout
        this.gbufferBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "G-buffer bind group layout",
            entries: [
                {//normal
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "float", viewDimension: "2d" }
                },
                {//albedo
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "float", viewDimension: "2d" }
                },
                {//position
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "float", viewDimension: "2d" }
                },
                {//sampler
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: {}
                }
            ]
        });

        this.gbufferBindGroup = renderer.device.createBindGroup({
            label: "G-buffer bind group",
            layout: this.gbufferBindGroupLayout,
            entries: [
                {//normal
                    binding: 0,
                    resource: this.normalTextureView
                },
                {//albedo
                    binding: 1,
                    resource: this.albedoTextureView
                },
                {//position
                    binding: 2,
                    resource: this.positionTextureView
                },
                {
                    binding: 3,
                    resource: renderer.device.createSampler()
                }
            ]
        });

        this.gbufferPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "G-buffer pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout, // sampler bind group layout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "G-buffer: naive vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "G-buffer frag shader",
                    code: shaders.clusteredDeferredFragSrc,
                }),
                targets: [
                    {//normal
                        format: "rgba16float",
                    },
                    {//albedo
                        format: "rgba8unorm",
                    },
                    {//position
                        format: "rgba16float",
                    }
                ]
            }
        });
        

        this.fullscreenPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "Fullscreen pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    this.gbufferBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "Fullscreen vert shader",
                    code: shaders.clusteredDeferredFullscreenVertSrc
                }),
                // buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "Fullscreen frag shader",
                    code: shaders.clusteredDeferredFullscreenFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            }
        });
    }

    override draw() {
        // console.log("renderer.canvas.width: ",renderer.canvas.width);
        // console.log("Normal texture view: ", this.normalTextureView);
        // console.log("Albedo texture view: ", this.albedoTextureView);
        // console.log("Position texture view: ", this.positionTextureView);
        // console.log("Scene uniforms bind group: ", this.sceneUniformsBindGroup);

        // TODO-3: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // - run the G-buffer pass, outputting position, albedo, and normals
        // - run the fullscreen pass, which reads from the G-buffer and performs lighting calculations
        const computeEncoder = renderer.device.createCommandEncoder({label: "Forward+ compute pass encoder created"});  
        this.lights.doLightClustering(computeEncoder); 
        renderer.device.queue.submit([computeEncoder.finish()]);  

        // - run the main rendering pass, using the computed clusters for efficient lighting
        const renderEncoder = renderer.device.createCommandEncoder();
        const gbufferPass = renderEncoder.beginRenderPass({
            label: "G-buffer pass",
            colorAttachments: [
                {
                    view: this.normalTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.albedoTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.positionTextureView,
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

        gbufferPass.setPipeline(this.gbufferPipeline);
        // group 0
        gbufferPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);
        this.scene.iterate(node => {
            // group 1
            gbufferPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            // group 2
            gbufferPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            gbufferPass.setVertexBuffer(0, primitive.vertexBuffer);
            gbufferPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            gbufferPass.drawIndexed(primitive.numIndices);
        });

        gbufferPass.end();

        const canvasTextureView = renderer.context.getCurrentTexture().createView();
        const fullscreenPass = renderEncoder.beginRenderPass({
            label: "full screen render pass",
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
        fullscreenPass.setPipeline(this.fullscreenPipeline);

        // // group 0
        fullscreenPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);
        fullscreenPass.setBindGroup(1, this.gbufferBindGroup);
        fullscreenPass.draw(6);
        fullscreenPass.end();

        renderer.device.queue.submit([renderEncoder.finish()]);
    }
}
