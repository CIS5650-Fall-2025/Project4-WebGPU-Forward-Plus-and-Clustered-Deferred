import Stats from 'stats.js';
import { GUI } from 'dat.gui';

import { initWebGPU, Renderer } from './renderer';
import { NaiveRenderer } from './renderers/naive';
import { ForwardPlusRenderer } from './renderers/forward_plus';
import { ClusteredDeferredRenderer } from './renderers/clustered_deferred';

import { setupLoaders, Scene } from './stage/scene';
import { Lights } from './stage/lights';
import { Camera } from './stage/camera';
import { Stage } from './stage/stage';

await initWebGPU();
setupLoaders();

let scene = new Scene();
await scene.loadGltf('./scenes/sponza/Sponza.gltf');

const camera = new Camera();
const lights = new Lights(camera);

const stats = new Stats();
stats.showPanel(0);
document.body.appendChild(stats.dom);

const gui = new GUI();

// Add GUI controls
gui.add(lights, 'numLights').min(1).max(Lights.maxNumLights).step(1).onChange(() => {
    lights.updateLightSetUniformNumLights();
});

// Add controls for cluster grid properties
gui.add(lights, 'clusterGridWidth').min(0).max(Lights.maxClusterGridWidth).step(1).onChange(() => {
    lights.updateClusterSetUniformGridWidth();
});

gui.add(lights, 'clusterGridHeight').min(0).max(Lights.maxClusterGridHeight).step(1).onChange(() => {
    lights.updateClusterSetUniformGridHeight();
});

gui.add(lights, 'clusterGridDepth').min(0).max(Lights.maxClusterGridDepth).step(1).onChange(() => {
    lights.updateClusterSetUniformGridDepth();
});

gui.add(lights, 'lightIntensity').min(0.1).max(Lights.maxLightIntensity).step(0.05).onChange(() => {
    lights.updateLightIntensity();
});

const stage = new Stage(scene, lights, camera, stats);

var renderer: Renderer | undefined;

function setRenderer(mode: string) {
    renderer?.stop();

    switch (mode) {
        case renderModes.naive:
            renderer = new NaiveRenderer(stage);
            break;
        case renderModes.forwardPlus:
            renderer = new ForwardPlusRenderer(stage);
            break;
        case renderModes.clusteredDeferred:
            renderer = new ClusteredDeferredRenderer(stage);
            break;
    }
}

const renderModes = { naive: 'naive', forwardPlus: 'forward+', clusteredDeferred: 'clustered deferred' };
let renderModeController = gui.add({ mode: renderModes.naive }, 'mode', renderModes);
renderModeController.onChange(setRenderer);

setRenderer(renderModeController.getValue());
