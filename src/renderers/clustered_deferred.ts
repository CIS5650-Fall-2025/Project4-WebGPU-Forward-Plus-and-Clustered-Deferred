import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
  // Bind groups and layouts
  sceneUniformsBindGroupLayout: GPUBindGroupLayout;
  sceneUniformsBindGroup: GPUBindGroup;
  debugBindGroupLayout: GPUBindGroupLayout;
  debugBindGroup: GPUBindGroup;

  // Buffers
  debugModeBuffer: GPUBuffer;

  // Textures
  sceneColorTexture: GPUTexture;
  sceneColorTextureView: GPUTextureView;
  sceneDepthTexture: GPUTexture;
  sceneDepthTextureView: GPUTextureView;

  // Pipeline and shaders
  sceneRenderPipelineLayout: GPUPipelineLayout;
  sceneRenderPipeline: GPURenderPipeline;
  sceneVertexShaderModule: GPUShaderModule;
  sceneFragmentShaderModule: GPUShaderModule;

  fullscreenBindGroupLayout: GPUBindGroupLayout;
  fullscreenBindGroup: GPUBindGroup;
  fullscreenPipelineLayout: GPUPipelineLayout;
  fullscreenPipeline: GPURenderPipeline;
  fullscreenVertexShaderModule: GPUShaderModule;
  fullscreenFragmentShaderModule: GPUShaderModule;

  constructor(stage: Stage) {
    super(stage);
    this.initSceneBindGroup();
    this.initTextures();
    this.initDebug();
    this.initRenderPipeline();
    this.initPresentBindGroup();
    this.initPresentPipeline();
  }

  private initSceneBindGroup() {
    this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
      label: 'sceneUniformsBindGroupLayout',
      entries: [{
        binding: 0,
        visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
        buffer: { type: 'uniform' },
      }],
    });

    this.sceneUniformsBindGroup = renderer.device.createBindGroup({
      label: 'sceneUniformsBindGroup',
      layout: this.sceneUniformsBindGroupLayout,
      entries: [{
        binding: 0,
        resource: { buffer: this.camera.uniformsBuffer },
      }],
    });
  }

  private initTextures() {
    this.sceneColorTexture = renderer.device.createTexture({
      label: 'sceneColorTexture',
      size: [renderer.canvas.width, renderer.canvas.height],
      format: 'rgba32float',
      usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
    });
    this.sceneColorTextureView = this.sceneColorTexture.createView();

    this.sceneDepthTexture = renderer.device.createTexture({
      label: 'sceneDepthTexture',
      size: [renderer.canvas.width, renderer.canvas.height],
      format: 'depth24plus',
      usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
    });
    this.sceneDepthTextureView = this.sceneDepthTexture.createView();
  }

  private initDebug() {
    this.debugModeBuffer = renderer.device.createBuffer({
      label: 'debugModeBuffer',
      size: 4,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
      mappedAtCreation: true,
    });
    new Uint32Array(this.debugModeBuffer.getMappedRange()).set([0]);
    this.debugModeBuffer.unmap();

    this.debugBindGroupLayout = renderer.device.createBindGroupLayout({
      label: 'debugBindGroupLayout',
      entries: [{
        binding: 0,
        visibility: GPUShaderStage.FRAGMENT,
        buffer: { type: 'uniform' },
      }],
    });

    this.debugBindGroup = renderer.device.createBindGroup({
      label: 'debugBindGroup',
      layout: this.debugBindGroupLayout,
      entries: [{
        binding: 0,
        resource: { buffer: this.debugModeBuffer },
      }],
    });
  }

  private initRenderPipeline() {
    this.sceneRenderPipelineLayout = renderer.device.createPipelineLayout({
      label: 'sceneRenderPipelineLayout',
      bindGroupLayouts: [
        this.sceneUniformsBindGroupLayout,
        renderer.modelBindGroupLayout,
        renderer.materialBindGroupLayout,
      ],
    });

    this.sceneVertexShaderModule = renderer.device.createShaderModule({
      label: 'sceneVertexShaderModule',
      code: shaders.naiveVertSrc,
    });

    this.sceneFragmentShaderModule = renderer.device.createShaderModule({
      label: 'sceneFragmentShaderModule',
      code: shaders.clusteredDeferredFragSrc,
    });

    this.sceneRenderPipeline = renderer.device.createRenderPipeline({
      label: 'sceneRenderPipeline',
      layout: this.sceneRenderPipelineLayout,
      vertex: {
        module: this.sceneVertexShaderModule,
        buffers: [renderer.vertexBufferLayout],
      },
      fragment: {
        module: this.sceneFragmentShaderModule,
        targets: [{ format: 'rgba32float' }],
      },
      depthStencil: {
        format: 'depth24plus',
        depthWriteEnabled: true,
        depthCompare: 'less',
      },
    });
  }

  private initPresentBindGroup() {
    this.fullscreenBindGroupLayout = renderer.device.createBindGroupLayout({
      label: 'fullscreenBindGroupLayout',
      entries: [
        { binding: 0, visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT, buffer: { type: 'uniform' } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: 'unfilterable-float' } },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, sampler: { type: 'non-filtering' } },
        { binding: 3, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: 'unfilterable-float' } },
        { binding: 4, visibility: GPUShaderStage.FRAGMENT, buffer: { type: 'read-only-storage' } },
      ],
    });

    this.fullscreenBindGroup = renderer.device.createBindGroup({
      label: 'fullscreenBindGroup',
      layout: this.fullscreenBindGroupLayout,
      entries: [
        { binding: 0, resource: { buffer: this.camera.uniformsBuffer } },
        { binding: 1, resource: this.sceneColorTextureView },
        { binding: 2, resource: renderer.device.createSampler() },
        { binding: 3, resource: this.sceneDepthTextureView },
        { binding: 4, resource: { buffer: this.lights.lightSetStorageBuffer } },
      ],
    });
  }

  private initPresentPipeline() {
    this.fullscreenPipelineLayout = renderer.device.createPipelineLayout({
      label: 'fullscreenPipelineLayout',
      bindGroupLayouts: [
        this.fullscreenBindGroupLayout,
        this.lights.clusterBindGroupLayout,
        this.debugBindGroupLayout,
      ],
    });

    this.fullscreenVertexShaderModule = renderer.device.createShaderModule({
      label: 'fullscreenVertexShaderModule',
      code: shaders.clusteredDeferredFullscreenVertSrc,
    });

    this.fullscreenFragmentShaderModule = renderer.device.createShaderModule({
      label: 'fullscreenFragmentShaderModule',
      code: shaders.clusteredDeferredFullscreenFragSrc,
    });

    this.fullscreenPipeline = renderer.device.createRenderPipeline({
      label: 'fullscreenPipeline',
      layout: this.fullscreenPipelineLayout,
      vertex: { module: this.fullscreenVertexShaderModule },
      fragment: {
        module: this.fullscreenFragmentShaderModule,
        targets: [{ format: renderer.canvasFormat }],
      },
    });
  }

  override draw() {
    const encoder = renderer.device.createCommandEncoder();
    this.lights.doLightClustering(encoder);

    const attachment_view = renderer.context.getCurrentTexture().createView();

    const sceneRenderPass = encoder.beginRenderPass({
      label: 'sceneRenderPass',
      colorAttachments: [{
        view: this.sceneColorTextureView,
        loadOp: 'clear',
        storeOp: 'store',
        clearValue: [0, 0, 0, 0],
      }],
      depthStencilAttachment: {
        view: this.sceneDepthTextureView,
        depthLoadOp: 'clear',
        depthStoreOp: 'store',
        depthClearValue: 1.0,
      },
    });

    sceneRenderPass.setPipeline(this.sceneRenderPipeline);
    sceneRenderPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);

    this.scene.iterate(node => {
      sceneRenderPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
    }, material => {
      sceneRenderPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
    }, primitive => {
      sceneRenderPass.setVertexBuffer(0, primitive.vertexBuffer);
      sceneRenderPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
      sceneRenderPass.drawIndexed(primitive.numIndices);
    });

    sceneRenderPass.end();

    const fullscreenRenderPass = encoder.beginRenderPass({
      label: 'fullscreenRenderPass',
      colorAttachments: [{ view: attachment_view, loadOp: 'clear', storeOp: 'store' }],
    });

    fullscreenRenderPass.setPipeline(this.fullscreenPipeline);
    fullscreenRenderPass.setBindGroup(0, this.fullscreenBindGroup);
    fullscreenRenderPass.setBindGroup(1, this.lights.clusterBindGroup);
    fullscreenRenderPass.setBindGroup(2, this.debugBindGroup);
    fullscreenRenderPass.draw(6);
    fullscreenRenderPass.end();

    renderer.device.queue.submit([encoder.finish()]);
  }
}
