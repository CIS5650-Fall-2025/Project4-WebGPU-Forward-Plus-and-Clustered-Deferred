import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    // gBufferPipeline: GPURenderPipeline
    // fullscreenPipeline: GPURenderPipeline


    constructor(stage: Stage) {
        super(stage);

        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass


        // this.gBufferPipeline = renderer.device.createRenderPipeline({
        //     layout: renderer.device.createPipelineLayout({
        //         label: "forward plus pipeline layout",
        //         bindGroupLayouts: [
        //             this.sceneBindGroupLayout,
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
        //             label: "forward plus vertex shader",
        //             code: shaders.naiveVertSrc
        //         }),
        //         buffers: [ renderer.vertexBufferLayout ]
        //     },
        //     fragment: {
        //         module: renderer.device.createShaderModule({
        //             label: "forward plus fragment shader",
        //             code: shaders.forwardPlusFragSrc,
        //         }),
        //         targets: [
        //             {
        //                 format: renderer.canvasFormat,
        //             }
        //         ]
        //     }
        // });

        // this.fullscreenPipeline = renderer.device.createRenderPipeline({
        //     layout: renderer.device.createPipelineLayout({
        //         label: "forward plus pipeline layout",
        //         bindGroupLayouts: [
        //             this.sceneBindGroupLayout,
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
        //             label: "forward plus vertex shader",
        //             code: shaders.naiveVertSrc
        //         }),
        //         buffers: [ renderer.vertexBufferLayout ]
        //     },
        //     fragment: {
        //         module: renderer.device.createShaderModule({
        //             label: "forward plus fragment shader",
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
        const encoder = renderer.device.createCommandEncoder();
        const canvasTextureView = renderer.context.getCurrentTexture().createView();

        

    }
}
