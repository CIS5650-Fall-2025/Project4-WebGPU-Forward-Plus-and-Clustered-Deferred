import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ForwardPlusRenderer extends renderer.Renderer {
  sceneUniformsBindGroupLayout: GPUBindGroupLayout;
  sceneUniformsBindGroup: GPUBindGroup;

  sceneDepthTexture: GPUTexture;
  sceneDepthTextureView: GPUTextureView;

  sceneRenderPipelineLayout: GPUPipelineLayout;
  sceneRenderPipeline: GPURenderPipeline;
  sceneVertexShaderModule: GPUShaderModule;
  sceneFragmentShaderModule: GPUShaderModule;

  constructor(stage: Stage) {
    super(stage);
    this.initSceneBindGroup();
    this.initDepthTexture();
    this.initRenderPipeline();
  }

  private initSceneBindGroup() {
    this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
      label: 'SceneUniformsBindGroupLayout',
      entries: [
        {
          binding: 0,
          visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
          buffer: { type: 'uniform' },
        },
        {
          binding: 1,
          visibility: GPUShaderStage.FRAGMENT,
          buffer: { type: 'read-only-storage' },
        },
      ],
    });

    this.sceneUniformsBindGroup = renderer.device.createBindGroup({
      label: 'SceneUniformsBindGroup',
      layout: this.sceneUniformsBindGroupLayout,
      entries: [
        {
          binding: 0,
          resource: { buffer: this.camera.uniformsBuffer },
        },
        {
          binding: 1,
          resource: { buffer: this.lights.lightSetStorageBuffer },
        },
      ],
    });
  }

  private initDepthTexture() {
    this.sceneDepthTexture = renderer.device.createTexture({
      label: 'SceneDepthTexture',
      size: [renderer.canvas.width, renderer.canvas.height],
      format: 'depth24plus',
      usage: GPUTextureUsage.RENDER_ATTACHMENT,
    });

    this.sceneDepthTextureView = this.sceneDepthTexture.createView();
    this.sceneDepthTextureView.label = 'SceneDepthTextureView';
  }

  private initRenderPipeline() {
    this.sceneRenderPipelineLayout = renderer.device.createPipelineLayout({
      label: 'SceneRenderPipelineLayout',
      bindGroupLayouts: [
        this.sceneUniformsBindGroupLayout,
        renderer.modelBindGroupLayout,
        renderer.materialBindGroupLayout,
        this.lights.clusterBindGroupLayout,
      ],
    });

    this.sceneVertexShaderModule = renderer.device.createShaderModule({
      label: 'SceneVertexShaderModule',
      code: shaders.naiveVertSrc,
    });

    this.sceneFragmentShaderModule = renderer.device.createShaderModule({
      label: 'SceneFragmentShaderModule',
      code: shaders.forwardPlusFragSrc,
    });

    this.sceneRenderPipeline = renderer.device.createRenderPipeline({
      label: 'SceneRenderPipeline',
      layout: this.sceneRenderPipelineLayout,
      vertex: {
        module: this.sceneVertexShaderModule,
        buffers: [renderer.vertexBufferLayout],
      },
      fragment: {
        module: this.sceneFragmentShaderModule,
        targets: [{ format: renderer.canvasFormat }],
      },
      depthStencil: {
        format: 'depth24plus',
        depthWriteEnabled: true,
        depthCompare: 'less',
      },
    });
  }

  override draw() {
    const encoder = renderer.device.createCommandEncoder();

    this.lights.doLightClustering(encoder);

    const colorAttachmentView = renderer.context.getCurrentTexture().createView();
    colorAttachmentView.label = 'SceneColorAttachmentView';

    const renderPass = encoder.beginRenderPass({
      label: 'SceneRenderPass',
      colorAttachments: [{
        view: colorAttachmentView,
        clearValue: [0, 0, 0, 0],
        loadOp: 'clear',
        storeOp: 'store',
      }],
      depthStencilAttachment: {
        view: this.sceneDepthTextureView,
        depthClearValue: 1.0,
        depthLoadOp: 'clear',
        depthStoreOp: 'store',
      },
    });

    renderPass.setPipeline(this.sceneRenderPipeline);
    renderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);
    renderPass.setBindGroup(shaders.constants.bindGroup_lightClusters, this.lights.clusterBindGroup);

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
