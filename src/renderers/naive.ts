import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class NaiveRenderer extends renderer.Renderer {
    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    sceneDepthTexture: GPUTexture;
    sceneDepthTextureView: GPUTextureView;

    sceneRenderPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: 'NaiveSceneUniformsBindGroupLayout',
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: { type: 'uniform' },
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: 'read-only-storage' },
                }
            ]
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: 'NaiveSceneUniformsBindGroup',
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer },
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer },
                }
            ]
        });

        this.sceneDepthTexture = renderer.device.createTexture({
            label: 'NaiveSceneDepthTexture',
            size: [renderer.canvas.width, renderer.canvas.height],
            format: 'depth24plus',
            usage: GPUTextureUsage.RENDER_ATTACHMENT,
        });

        this.sceneDepthTextureView = this.sceneDepthTexture.createView();
        this.sceneDepthTextureView.label = 'NaiveSceneDepthTextureView';

        this.sceneRenderPipeline = renderer.device.createRenderPipeline({
            label: 'NaiveRenderPipeline',
            layout: renderer.device.createPipelineLayout({
                label: 'NaiveRenderPipelineLayout',
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: 'less',
                format: 'depth24plus',
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: 'NaiveVertexShaderModule',
                    code: shaders.naiveVertSrc,
                }),
                buffers: [renderer.vertexBufferLayout]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: 'NaiveFragmentShaderModule',
                    code: shaders.naiveFragSrc,
                }),
                targets: [{ format: renderer.canvasFormat }]
            }
        });
    }

    override draw() {
        const encoder = renderer.device.createCommandEncoder();

        const canvasTextureView = renderer.context.getCurrentTexture().createView();
        canvasTextureView.label = 'NaiveCanvasTextureView';

        const renderPass = encoder.beginRenderPass({
            label: 'NaiveRenderPass',
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0, 0, 0, 0],
                    loadOp: 'clear',
                    storeOp: 'store',
                }
            ],
            depthStencilAttachment: {
                view: this.sceneDepthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: 'clear',
                depthStoreOp: 'store',
            }
        });

        renderPass.setPipeline(this.sceneRenderPipeline);

        renderPass.setBindGroup(
            shaders.constants.bindGroup_scene,
            this.sceneUniformsBindGroup
        );

        this.scene.iterate(
            node => {
                renderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
            },
            material => {
                renderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
            },
            primitive => {
                renderPass.setVertexBuffer(0, primitive.vertexBuffer);
                renderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
                renderPass.drawIndexed(primitive.numIndices);
            }
        );

        renderPass.end();
        renderer.device.queue.submit([encoder.finish()]);
    }
}
