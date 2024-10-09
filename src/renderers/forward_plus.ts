import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ForwardPlusRenderer extends renderer.Renderer {
    // TODO-2: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution
    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    depthVisualGroupLayout: GPUBindGroupLayout;
    depthVisualBindGroup: GPUBindGroup;
    depthSampler: GPUSampler;

    lightBuffer: GPUBuffer;
    clusterBuffer: GPUBuffer; 
    uniformBuffer: GPUBuffer;
    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    depthbufferPipeline: GPURenderPipeline;
    depthbufferVisualPipeline: GPURenderPipeline;
    clusterComputePipeline: GPUComputePipeline;
    renderPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        // TODO-2: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "forward plus scene uniforms bind group layout",
            entries: [
                { // Camera Uniforms
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: { type: "uniform" }
                },
                { // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                }
            ]
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "forward plus scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                { // Camera Uniforms
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
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
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.depthTextureView = this.depthTexture.createView();

        this.renderPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "forward plus render pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less-equal",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "forward plus vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "forward plus frag shader",
                    code: shaders.naiveFragSrc,
                }),
                targets: [
                    {
                        format: renderer.canvasFormat,
                    }
                ]
            }
        });

        this.depthbufferPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "depth pre-pass pipeline layout",
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
                    label: "depth pre-pass vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [renderer.vertexBufferLayout]
            },
            // No fragment shader or color targets
        });

        this.depthSampler = renderer.device.createSampler({
                magFilter: 'linear',
                minFilter: 'linear',
                addressModeU: 'clamp-to-edge',
                addressModeV: 'clamp-to-edge'
        });

        this.depthVisualGroupLayout = renderer.device.createBindGroupLayout({
            label: "depth visualization bind group layout",
            entries: [
                { 
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {
                        sampleType: 'depth',
                        viewDimension: '2d',
                    }
                },
                { 
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: {}
                }
            ]
        });

        this.depthVisualBindGroup = renderer.device.createBindGroup({
            label: "depth visualizatio bind group",
            layout: this.depthVisualGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: this.depthTextureView
                },
                {
                    binding: 1,
                    resource: this.depthSampler
                }
            ]
        });

        this.depthbufferVisualPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "forward plus depth visualization pipeline layout",
                bindGroupLayouts: [
                    this.depthVisualGroupLayout,
                ]
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "forward plus depth visualization vert shader",
                    code: shaders.depthVisualVertSrc,
                }),
                //buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "forward plus depth visualization  shader",
                    code: shaders.depthVisualFragSrc,
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
        // TODO-2: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // - run the main rendering pass, using the computed clusters for efficient lighting
        const encoder = renderer.device.createCommandEncoder();
        const canvasTextureView = renderer.context.getCurrentTexture().createView();

        //Pre-Depth Pass
        const depthPrePass = encoder.beginRenderPass({
            label: "forward plus depth-only render pass",
            colorAttachments: [],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });

        depthPrePass.setPipeline(this.depthbufferPipeline);
        depthPrePass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);

        this.scene.iterate(node => {
            depthPrePass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            depthPrePass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            depthPrePass.setVertexBuffer(0, primitive.vertexBuffer);
            depthPrePass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            depthPrePass.drawIndexed(primitive.numIndices);
        });
        depthPrePass.end();

        //tex visualization pass
        const depthVisualPass = encoder.beginRenderPass({
            label: "forward plus render pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ]
        });
        depthVisualPass.setPipeline(this.depthbufferVisualPipeline);
        depthVisualPass.setBindGroup(0, this.depthVisualBindGroup);
        depthVisualPass.draw(3);
        depthVisualPass.end();

        //Main Render Pass
        // const renderPass = encoder.beginRenderPass({
        //     label: "forward plus render pass",
        //     colorAttachments: [
        //         {
        //             view: canvasTextureView,
        //             clearValue: [0, 0, 0, 0],
        //             loadOp: "clear",
        //             storeOp: "store"
        //         }
        //     ],
        //     depthStencilAttachment: {
        //         view: this.depthTextureView,
        //         depthClearValue: 1.0,
        //         depthLoadOp: "load",
        //         depthStoreOp: "store"
        //     }
        // });

        // renderPass.setPipeline(this.renderPipeline);
        // renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);

        // this.scene.iterate(node => {
        //     renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        // }, material => {
        //     renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        // }, primitive => {
        //     renderPass.setVertexBuffer(0, primitive.vertexBuffer);
        //     renderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
        //     renderPass.drawIndexed(primitive.numIndices);
        // });
        // renderPass.end();

        renderer.device.queue.submit([encoder.finish()]);

        //console.log("Forward+ draw");
    }
}
