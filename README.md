## WebGPU Clustered Forward and Clustered Deferred Shading

[![](img/webgpu_demo.gif)]

Author: Alan Lee ([LinkedIn](https://www.linkedin.com/in/soohyun-alan-lee/))

This project is a WebGPU based clustered forward and clustered deferred shader designed and implemented using typescript and WebGPU.

This rasterizer currently supports the following features with arbitrary number of light sources:
* Naive renderer
* Clustered forward renderer (light clustering)
* Clustered deferred renderer (light clustering + deferred shading)
* Clustered deferred toon-shaded renderer (light clustering + deferred shading + toon shading in fragment shader)
* Clustered deferred toon-computed renderer (light clustering + deferred shading + toon shading in compute shader)

You can directly experience the live demo at our website on [Github page](https://alan7996.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/). 

### Live Demo

[![](img/screenshot.jpg)](https://alan7996.github.io/Project4-WebGPU-Forward-Plus-and-Clustered-Deferred/)

## Contents

- `src/` contains all the TypeScript and WGSL code for this project. This contains several subdirectories:
  - `renderers/` defines the different renderers in which you will implement Forward+ and Clustered Deferred shading
  - `shaders/` contains the WGSL files that are interpreted as shader programs at runtime, as well as a `shaders.ts` file which preprocesses the shaders
  - `stage/` includes camera controls, scene loading, and lights, where you will implement the clustering compute shader
- `scenes/` contains the Sponza Atrium model used in the test scene

## Running the code

Follow these steps to install and view the project:
- Clone this repository
- Download and install [Node.js](https://nodejs.org/en/)
- Run `npm install` in the root directory of this project to download and install dependencies
- Run `npm run dev`, which will open the project in your browser
  - The project will automatically reload when you edit any of the files
  
## Analysis

* Tested on: **Google Chrome 129.0.6668.101 (64 bit)** on
  Windows 10, AMD Ryzen 5 5600X 6-Core Processor @ 3.70GHz, 32GB RAM, NVIDIA GeForce RTX 3070 Ti (Personal Computer)
* Number of clusters in (x, y, z) : (16, 16, 24)
* Workgroup size : (4, 4, 8)
* Number of lights : 5000
* maxNumLightsPerCluster: 1000

The raw data for both qualitative and quantitative observations were made using above testing setup. For the numerical measurements of the performance, please refer to `rawdata.xlsx` at the root of this repository. The render time for each frame was measured in the renderer's `draw` function by taking the difference between recorded timestamps before and after submitting the command encoder to our device queue.

The performance analysis was conducted using the Sponza Atrium model. We tested each configuration **three** times, each time recording render times for **hundred** frames, and averaged the results to reduce to performance effect of randomness in light source position and movement generations. We did not test with static light positions because the variance in averaged performance is too high compared to moving light sources that somewhat converges to a reasonable variance on expectation.

###

### Credits

- [Vite](https://vitejs.dev/)
- [loaders.gl](https://loaders.gl/)
- [dat.GUI](https://github.com/dataarts/dat.gui)
- [stats.js](https://github.com/mrdoob/stats.js)
- [wgpu-matrix](https://github.com/greggman/wgpu-matrix)
- [toon shader](https://roystan.net/articles/toon-shader/)
- [wgpu timer](https://webgpufundamentals.org/webgpu/lessons/webgpu-timing.html)